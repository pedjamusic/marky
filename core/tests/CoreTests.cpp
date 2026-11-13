#include "MarkyCore.h"
#include "../src/LiteralSyntax.h"

#include <array>
#include <barrier>
#include <cstddef>
#include <cstdlib>
#include <cstring>
#include <initializer_list>
#include <iostream>
#include <memory>
#include <optional>
#include <string>
#include <string_view>
#include <thread>

namespace {

void check_owned_paragraph(const auto& check) {
    // Decomposed é, emoji, embedded NUL and a final ASCII byte.
    constexpr char expected[] = "e\xCC\x81\xF0\x9F\x8E\xB5\0" "!";
    constexpr size_t byte_count = sizeof(expected) - 1;
    MarkyDocument* document = nullptr;
    {
        char input[byte_count];
        std::memcpy(input, expected, byte_count);
        check(marky_document_create(input, byte_count, &document) == MARKY_STATUS_OK &&
                  document != nullptr,
              "valid length-delimited input must produce an owned document");
        std::memset(input, '?', byte_count);
        MarkyUtf8View text{};
        check(marky_document_paragraph_at(document, 0, &text) == MARKY_STATUS_OK &&
                  text.data != input,
              "the paragraph must not alias the caller's buffer");
    }

    check(marky_document_block_count(document) == 1,
          "nonempty input must produce one paragraph");
    MarkyUtf8View text{};
    check(marky_document_paragraph_at(document, 0, &text) == MARKY_STATUS_OK,
          "the paragraph must remain readable after the input goes out of scope");

    MarkyDocument* other = nullptr;
    check(marky_document_create("other", 5, &other) == MARKY_STATUS_OK &&
              other != nullptr && other != document,
          "a second call must produce an independent result");
    if (other != document) {
        marky_document_release(other);
    }
    check(text.data != nullptr && text.byte_count == byte_count &&
              std::memcmp(text.data, expected, byte_count) == 0,
          "a view must keep the exact UTF-8 bytes until its own result is released");

    MarkyUtf8View invalid = text;
    check(marky_document_paragraph_at(document, 1, &invalid) == MARKY_STATUS_INVALID_ARGUMENT &&
              invalid.data == nullptr && invalid.byte_count == 0,
          "an out-of-range index must clear the output view");
    check(marky_document_paragraph_at(document, 0, nullptr) == MARKY_STATUS_INVALID_ARGUMENT,
          "a missing output view must be rejected");

    MarkyDocument* rejected = document;
    check(marky_document_create(nullptr, 1, &rejected) == MARKY_STATUS_INVALID_ARGUMENT &&
              rejected == nullptr,
          "nonzero length with NULL input must clear the output handle");
    marky_document_release(document);
}

void check_empty_document(const auto& check, const char* input) {
    MarkyDocument* document = nullptr;
    check(marky_document_create(input, 0, &document) == MARKY_STATUS_OK && document != nullptr,
          "empty input must produce an owned document");
    check(marky_document_block_count(document) == 0,
          "empty input must have no blocks");

    MarkyUtf8View text{"stale", 5};
    check(marky_document_paragraph_at(document, 0, &text) == MARKY_STATUS_INVALID_ARGUMENT &&
              text.data == nullptr && text.byte_count == 0,
          "an empty document must have no paragraph view");
    marky_document_release(document);
}

struct ExpectedListItem {
    size_t depth;
    MarkyListMarkerKind marker_kind;
    std::string_view source;
    std::string_view ordered_marker{};
};

void check_list(const auto& check, std::string_view source, size_t block_count, size_t block_index,
                std::initializer_list<ExpectedListItem> expected, std::string_view fixture) {
    MarkyDocument* raw_document = nullptr;
    MarkyStatus status;
    {
        std::string input(source);
        status = marky_document_create(input.data(), input.size(), &raw_document);
        std::memset(input.data(), '?', input.size());
    }
    const std::unique_ptr<MarkyDocument, decltype(&marky_document_release)>
        document(raw_document, marky_document_release);

    MarkyBlockKind kind = MARKY_BLOCK_INVALID;
    MarkyUtf8View text{};
    bool matches = status == MARKY_STATUS_OK && marky_document_block_count(document.get()) == block_count &&
                   marky_document_block_at(document.get(), block_index, &kind, &text) == MARKY_STATUS_OK &&
                   kind == MARKY_BLOCK_LIST && text.data != nullptr && text.byte_count == 0 &&
                   marky_document_list_item_count(document.get(), block_index) == expected.size() &&
                   marky_document_paragraph_at(document.get(), block_index, &text) == MARKY_STATUS_INVALID_ARGUMENT;
    size_t index = 0;
    for (const auto& item : expected) {
        MarkyListItemView view{};
        matches &= marky_document_list_item_at(document.get(), block_index, index++, &view) == MARKY_STATUS_OK &&
                   view.depth == item.depth && view.marker_kind == item.marker_kind &&
                   view.ordered_marker.data != nullptr && view.source.data != nullptr &&
                   std::string_view(view.ordered_marker.data, view.ordered_marker.byte_count) == item.ordered_marker &&
                   std::string_view(view.source.data, view.source.byte_count) == item.source;
    }
    check(matches, fixture);
}

void check_list_blocks(const auto& check) {
    constexpr auto bullet = MARKY_LIST_MARKER_BULLET;
    constexpr auto ordered = MARKY_LIST_MARKER_ORDERED;
    constexpr auto unchecked = MARKY_LIST_MARKER_TASK_UNCHECKED;
    constexpr auto checked = MARKY_LIST_MARKER_TASK_CHECKED;

    check_list(check, "- parent\n  - child\n    - grandchild", 1, 0,
               {{0, bullet, "parent"}, {1, bullet, "child"}, {2, bullet, "grandchild"}},
               "MD-015 nested list");
    check_list(check, "- First line\n  Continuation line\n- Second item", 1, 0,
               {{0, bullet, "First line\nContinuation line"}, {0, bullet, "Second item"}},
               "MD-016 list continuation");
    check_list(check, "- [ ] Todo task\n- [x] Done task\n- [X] Upper done task", 1, 0,
               {{0, unchecked, "Todo task"}, {0, checked, "Done task"}, {0, checked, "Upper done task"}},
               "MD-017 task states");
    check_list(check, "1. one\n2) two\n+ plus\n* star\n\xE2\x80\xA2 bullet", 1, 0,
               {{0, ordered, "one", "1."}, {0, ordered, "two", "2)"}, {0, bullet, "plus"},
                {0, bullet, "star"}, {0, bullet, "bullet"}},
               "MD-018 ordered spelling and bullet forms");
    check_list(check, "- first\n  > literal quote continuation\nplain\n> quote", 3, 0,
               {{0, bullet, "first\n> literal quote continuation"}},
               "MD-058 indented quote syntax remains in the list item");
    check_list(check, "- [x]yes\n- [ ] \n01) item\n  - child\n\t- tab", 1, 0,
               {{0, bullet, "[x]yes"}, {0, unchecked, ""}, {0, ordered, "item", "01)"},
                {1, bullet, "child"}, {0, bullet, "tab"}},
               "MD-059 empty task, tab depth and zero padding");
    constexpr std::string_view split = "- one\n\n- two\n> quote\n# heading";
    check_list(check, split, 4, 0, {{0, bullet, "one"}}, "MD-061 list before blank");
    check_list(check, split, 4, 1, {{0, bullet, "two"}}, "MD-061 list after blank");
    check_list(check, "A | B\n--- | ---\n- item", 2, 1, {{0, bullet, "item"}}, "MD-067 list after table syntax");
    check_list(check, "# [**head**](https://h.test)\n- ~~item~~\n> *quote*", 3, 1,
               {{0, bullet, "~~item~~"}}, "MD-071 list retains source for inline parsing");

    using namespace std::string_view_literals;
    check_list(check, "Before\r\n* [x] caf\xC3\xA9\0!\r\n\t  continuation\r\n"
                      "  \xD9\xA2) Unicode\r\n3\xEF\xB8\x8F\xE2\x83\xA3. Keycap"sv, 2, 1,
               {{0, checked, "caf\xC3\xA9\0!\ncontinuation"sv}, {1, ordered, "Unicode", "\xD9\xA2)"},
                {0, ordered, "Keycap", "3\xEF\xB8\x8F\xE2\x83\xA3."}},
               "owned UTF-8 item source and ordered markers survive input release");
    check_list(check, "- one\n  01) \n  - \n+ [X] done\n\xE2\x80\xA2 [x] literal\n1. [x] literal",
               1, 0, {{0, bullet, "one"}, {1, ordered, "", "01)"}, {1, bullet, ""},
                      {0, checked, "done"}, {0, bullet, "[x] literal"}, {0, ordered, "[x] literal", "1."}},
               "bare indented markers and task syntax follow Swift preparation");
}

void check_list_accessor_arguments(const auto& check) {
    constexpr std::string_view input = "Intro\n  1. item";
    MarkyDocument* raw_document = nullptr;
    const auto status = marky_document_create(input.data(), input.size(), &raw_document);
    const std::unique_ptr<MarkyDocument, decltype(&marky_document_release)>
        document(raw_document, marky_document_release);
    MarkyListItemView item{};
    check(status == MARKY_STATUS_OK &&
              marky_document_list_item_at(document.get(), 1, 0, &item) == MARKY_STATUS_OK,
          "argument checks require a valid item");
    const auto rejects = [&](const MarkyDocument* candidate, size_t block, size_t index) {
        auto output = item;
        return marky_document_list_item_at(candidate, block, index, &output) == MARKY_STATUS_INVALID_ARGUMENT &&
               output.depth == 0 && output.marker_kind == MARKY_LIST_MARKER_INVALID &&
               output.ordered_marker.data == nullptr && output.ordered_marker.byte_count == 0 &&
               output.source.data == nullptr && output.source.byte_count == 0;
    };
    check(rejects(document.get(), 1, 1) && rejects(document.get(), 0, 0) &&
              rejects(document.get(), 2, 0) && rejects(nullptr, 1, 0) &&
              marky_document_list_item_at(document.get(), 1, 0, nullptr) == MARKY_STATUS_INVALID_ARGUMENT,
          "invalid item lookups must reject missing outputs and clear stale views");
    check(marky_document_list_item_count(document.get(), 0) == 0 &&
              marky_document_list_item_count(document.get(), 2) == 0 &&
              marky_document_list_item_count(nullptr, 1) == 0,
          "non-list, out-of-range and NULL documents must report zero items");
}

struct ExpectedBlock {
    MarkyBlockKind kind;
    std::string_view text;
    uint32_t heading_level = 0;
};

void check_blocks(const auto& check, std::string_view input,
                  std::initializer_list<ExpectedBlock> expected, std::string_view fixture) {
    MarkyDocument* raw_document = nullptr;
    const auto status = marky_document_create(input.data(), input.size(), &raw_document);
    const std::unique_ptr<MarkyDocument, decltype(&marky_document_release)>
        document(raw_document, marky_document_release);
    bool matches = status == MARKY_STATUS_OK && document != nullptr &&
                   marky_document_block_count(document.get()) == expected.size();
    size_t index = 0;
    for (const auto& block : expected) {
        MarkyBlockKind kind = MARKY_BLOCK_INVALID;
        MarkyUtf8View text{};
        matches &= marky_document_block_at(document.get(), index, &kind, &text) == MARKY_STATUS_OK &&
                   kind == block.kind && text.data != nullptr &&
                   std::string_view(text.data, text.byte_count) == block.text;
        uint32_t level = 99;
        const auto level_status = marky_document_heading_level_at(document.get(), index++, &level);
        matches &= level == block.heading_level &&
                   level_status == (kind == MARKY_BLOCK_HEADING ? MARKY_STATUS_OK :
                                                                 MARKY_STATUS_INVALID_ARGUMENT);
    }
    check(matches, fixture);
}

void check_list_boundaries(const auto& check) {
    check_blocks(check, "Title\n---\n- item\n---\n- next\n  ===\n  # Heading\n    - literal\n"
                        "- after code\n~~~\n* fenced\n~~~\n- last",
                 {{MARKY_BLOCK_HEADING, "Title", 2}, {MARKY_BLOCK_LIST, ""}, {MARKY_BLOCK_THEMATIC_BREAK, ""},
                  {MARKY_BLOCK_LIST, ""}, {MARKY_BLOCK_HEADING, "Heading", 1}, {MARKY_BLOCK_CODE, "- literal"},
                  {MARKY_BLOCK_LIST, ""}, {MARKY_BLOCK_CODE, "* fenced"}, {MARKY_BLOCK_LIST, ""}},
                 "list boundaries preserve Setext, rules, ATX and literal code precedence");
    check_list(check, "- item\n  ===", 1, 0, {{0, MARKY_LIST_MARKER_BULLET, "item\n==="}},
               "Setext underlines can continue a list item without making a heading");
    check_blocks(check, "- \n\n1) \n\n- \xCC\x81" "accent\n\n-\tno separator",
                 {{MARKY_BLOCK_PARAGRAPH, "-"}, {MARKY_BLOCK_PARAGRAPH, "1)"},
                  {MARKY_BLOCK_PARAGRAPH, "- \xCC\x81" "accent"}, {MARKY_BLOCK_PARAGRAPH, "-\tno separator"}},
                 "bare markers and malformed separators remain readable");
}

struct ExpectedQuoteLine {
    size_t depth;
    std::string_view source;
};

void check_quote(const auto& check, std::string_view source, size_t block_index,
                 std::initializer_list<ExpectedQuoteLine> expected, std::string_view fixture) {
    MarkyDocument* raw_document = nullptr;
    MarkyStatus status;
    {
        std::string input(source);
        status = marky_document_create(input.data(), input.size(), &raw_document);
        std::memset(input.data(), '?', input.size());
    }
    const std::unique_ptr<MarkyDocument, decltype(&marky_document_release)>
        document(raw_document, marky_document_release);

    MarkyBlockKind kind = MARKY_BLOCK_INVALID;
    MarkyUtf8View text{};
    bool matches = status == MARKY_STATUS_OK &&
                   marky_document_block_at(document.get(), block_index, &kind, &text) == MARKY_STATUS_OK &&
                   kind == MARKY_BLOCK_QUOTE && text.data != nullptr && text.byte_count == 0 &&
                   marky_document_quote_line_count(document.get(), block_index) == expected.size() &&
                   marky_document_paragraph_at(document.get(), block_index, &text) == MARKY_STATUS_INVALID_ARGUMENT;
    size_t index = 0;
    for (const auto& line : expected) {
        MarkyQuoteLineView view{};
        matches &= marky_document_quote_line_at(document.get(), block_index, index++, &view) == MARKY_STATUS_OK &&
                   view.depth == line.depth && view.source.data != nullptr &&
                   std::string_view(view.source.data, view.source.byte_count) == line.source;
    }
    check(matches, fixture);
}

void check_quote_blocks(const auto& check) {
    constexpr auto quote = MARKY_BLOCK_QUOTE;
    constexpr auto prose = MARKY_BLOCK_PARAGRAPH;
    constexpr auto code = MARKY_BLOCK_CODE;
    constexpr auto list = MARKY_BLOCK_LIST;
    check_quote(check, "> Outer\n> > Inner", 0, {{1, "Outer"}, {2, "Inner"}}, "MD-019 quote depth");
    check_quote(check, "> **first\n> second**\n>\n>> nested", 0,
                {{1, "**first"}, {1, "second**"}, {1, ""}, {2, "nested"}},
                "MD-060 retains lines and source for cross-line emphasis");
    constexpr std::string_view table_boundary = "| A | B |\n| --- | --- |\nSolo\n> Quote with | pipes";
    check_blocks(check, table_boundary, {{MARKY_BLOCK_TABLE, ""}, {quote, ""}},
                 "MD-024 quote terminates a table");
    check_quote(check, table_boundary, 1, {{1, "Quote with | pipes"}}, "MD-024 retains quoted pipes");
    check_blocks(check, "- first\n  > literal quote continuation\nplain\n> quote",
                 {{list, ""}, {prose, "plain"}, {quote, ""}}, "MD-058 list continuation and quote boundary");
    check_blocks(check, "- one\n\n- two\n> quote\n# heading",
                 {{list, ""}, {list, ""}, {quote, ""}, {MARKY_BLOCK_HEADING, "heading", 1}},
                 "MD-061 quote separates list and ATX heading");
    check_blocks(check, "    > indented\n~~~\n> fenced\n~~~\n> quote\n---\n"
                        "> again\n\n> after blank\nunmarked\n- item",
                 {{code, "> indented"}, {code, "> fenced"}, {quote, ""}, {MARKY_BLOCK_THEMATIC_BREAK, ""},
                  {quote, ""}, {quote, ""}, {prose, "unmarked"}, {list, ""}},
                 "quote boundaries preserve code, rule, blank line, prose and list precedence");

    using namespace std::string_view_literals;
    check_quote(check, " >\t>\xC2\xA0> caf\xC3\xA9\0!  \r\n    >>\r\n"
                       "> \\> literal\r\n> `first\r\n>> second`"sv,
                0, {{3, "caf\xC3\xA9\0!"sv}, {2, ""}, {1, "\\> literal"},
                    {1, "`first"}, {2, "second`"}},
                "owned CRLF quote lines preserve Unicode, empty depth and cross-line code source");
    check_blocks(check, ">\xCC\x81 accent", {{prose, ">\xCC\x81 accent"}},
                 "a greater-than sign with an attached accent remains prose");
    check_quote(check, "> >\xEF\xB8\x8F variation\n\xE2\x80\xA8> literal",
                0, {{1, ">\xEF\xB8\x8F variation"}, {0, "\xE2\x80\xA8> literal"}},
                "preserve quote content when a marker is part of a grapheme or behind a Unicode newline");
}

void check_quote_accessor_arguments(const auto& check) {
    constexpr std::string_view input = "Intro\n> quote";
    MarkyDocument* raw_document = nullptr;
    const auto status = marky_document_create(input.data(), input.size(), &raw_document);
    const std::unique_ptr<MarkyDocument, decltype(&marky_document_release)>
        document(raw_document, marky_document_release);
    MarkyQuoteLineView line{};
    check(status == MARKY_STATUS_OK &&
              marky_document_quote_line_at(document.get(), 1, 0, &line) == MARKY_STATUS_OK,
          "argument checks require a valid quote line");
    const auto rejects = [&](const MarkyDocument* candidate, size_t block, size_t index) {
        auto output = line;
        return marky_document_quote_line_at(candidate, block, index, &output) == MARKY_STATUS_INVALID_ARGUMENT &&
               output.depth == 0 && output.source.data == nullptr && output.source.byte_count == 0;
    };
    check(rejects(document.get(), 1, 1) && rejects(document.get(), 0, 0) &&
              rejects(document.get(), 2, 0) && rejects(nullptr, 1, 0) &&
              marky_document_quote_line_at(document.get(), 1, 0, nullptr) == MARKY_STATUS_INVALID_ARGUMENT,
          "invalid quote lookups must reject missing outputs and clear stale views");
    check(marky_document_quote_line_count(document.get(), 0) == 0 &&
              marky_document_quote_line_count(document.get(), 2) == 0 &&
              marky_document_quote_line_count(nullptr, 1) == 0,
          "non-quote, out-of-range and NULL documents must report zero lines");
}

struct ExpectedColumn {
    MarkyTableAlignment alignment;
    std::string_view header;
};

void check_table(const auto& check, std::string_view source, std::initializer_list<ExpectedColumn> columns,
                 std::initializer_list<std::initializer_list<std::string_view>> rows, std::string_view fixture) {
    MarkyDocument* raw_document = nullptr;
    MarkyStatus status;
    {
        std::string input(source);
        status = marky_document_create(input.data(), input.size(), &raw_document);
        std::memset(input.data(), '?', input.size());
    }
    const std::unique_ptr<MarkyDocument, decltype(&marky_document_release)>
        document(raw_document, marky_document_release);
    MarkyBlockKind kind = MARKY_BLOCK_INVALID;
    MarkyUtf8View text{};
    bool matches = status == MARKY_STATUS_OK &&
                   marky_document_block_at(document.get(), 0, &kind, &text) == MARKY_STATUS_OK &&
                   kind == MARKY_BLOCK_TABLE && text.data != nullptr && text.byte_count == 0 &&
                   marky_document_table_column_count(document.get(), 0) == columns.size() &&
                   marky_document_table_row_count(document.get(), 0) == rows.size();
    size_t column_index = 0;
    for (const auto& column : columns) {
        MarkyTableColumnView view{};
        matches &= marky_document_table_column_at(document.get(), 0, column_index++, &view) == MARKY_STATUS_OK &&
                   view.alignment == column.alignment && view.header.data != nullptr &&
                   std::string_view(view.header.data, view.header.byte_count) == column.header;
    }
    size_t row_index = 0;
    for (const auto& row : rows) {
        column_index = 0;
        for (const auto cell : row) {
            MarkyUtf8View view{};
            matches &= marky_document_table_cell_at(document.get(), 0, row_index, column_index++, &view) ==
                           MARKY_STATUS_OK &&
                       view.data != nullptr && std::string_view(view.data, view.byte_count) == cell;
        }
        ++row_index;
    }
    check(matches, fixture);
}

void check_table_blocks(const auto& check) {
    constexpr auto left = MARKY_TABLE_ALIGNMENT_LEFT;
    constexpr auto center = MARKY_TABLE_ALIGNMENT_CENTER;
    constexpr auto right = MARKY_TABLE_ALIGNMENT_RIGHT;
    constexpr auto table = MARKY_BLOCK_TABLE;
    constexpr auto image = MARKY_BLOCK_IMAGE;
    constexpr auto prose = MARKY_BLOCK_PARAGRAPH;
    constexpr auto heading = MARKY_BLOCK_HEADING;
    using namespace std::string_view_literals;
    check_table(check, " Name | **Age** | City \r\n :--- | :-: | -:\r\n"
                       "caf\xC3\xA9\0! | 30 | London | excess\r\nOnly A"sv,
                {{left, "Name"}, {center, "**Age**"}, {right, "City"}},
                {{"caf\xC3\xA9\0!"sv, "30", "London"}, {"Only A", "", ""}},
                "MD-020/021/023 alignment and normalized rows preserve owned UTF-8, NUL, and CRLF input");
    check_table(check, "| A | B |\n| --- | --- |\n| Escaped \\| pipe | `a|b` |\n"
                       "end\\|\nx\\\\|y\nx\\\\\\|z | q\n`open | tail\n``a`b|c`` | d",
                {{left, "A"}, {left, "B"}},
                {{"Escaped \\| pipe", "`a|b`"}, {"end\\|", ""}, {"x\\\\", "y"}, {"x\\\\\\|z", "q"},
                 {"`open", "tail"}, {"``a`b|c``", "d"}},
                "MD-022/062–064 preserve escapes, parity, and code source with matching and unmatched runs");
    check_table(check, "| A |\n| - |", {{left, "A"}}, {}, "a one-column table can have no body");
    check_table(check, "A | B | C\n- | - | -\nfirst```` | \\```a|b`` | last",
                {{left, "A"}, {left, "B"}, {left, "C"}},
                {{"first````", "\\```a|b``", "last"}},
                "after an unmatched run, an escaped backtick can leave a shorter matched opener");
    check_table(check, "A | B\n- | -\nx|\xCC\x81 y | z\n| | |",
                {{left, "A"}, {left, "B"}}, {{"x|\xCC\x81 y", "z"}, {"", ""}},
                "a pipe with a combining suffix stays literal and empty rows retain their columns");
    check_table(check, "A | B\n- | -\n![alt](bad destination) | body\n"
                       "![alt](<file name.png> 'caption')",
                {{left, "A"}, {left, "B"}}, {{"![alt](bad destination)", "body"}},
                "only recognized standalone images end table rows");

    check_blocks(check, "A | B\n--x | ---\nrow | next", {{prose, "A | B --x | --- row | next"}},
                 "MD-065 malformed delimiters preserve paragraph text");
    check_blocks(check, "| A | B | C |\n| --- | --- |\n| 1 | 2 |",
                 {{prose, "| A | B | C | | --- | --- | | 1 | 2 |"}}, "MD-025 mismatched header width stays prose");
    check_blocks(check, "`A|B`\n| - |\n\nA\\|B\n| - |",
                 {{prose, "`A|B` | - |"}, {prose, "A\\|B | - |"}},
                 "pipes only inside code or escapes do not start tables");
    check_blocks(check, "A | B\n---\n\nA | B\n- | -\n===\n\nA | B\n- | -\n***",
                 {{heading, "A | B", 2}, {table, ""}, {prose, "==="},
                  {table, ""}, {MARKY_BLOCK_THEMATIC_BREAK, ""}},
                 "MD-088/089 distinguish Setext headings, equals underlines, and rules from table rows");
    check_blocks(check, "A | B\n- | -\n# heading\n\nA | B\n- | -\n- list | item\n\nA | B\n- | -\n"
                        "    literal | code\n\nA | B\n- | -\n~~~\nliteral | code\n~~~\n\n"
                        "A | B\n- | -\n![alt](image.png)\n\nA | B\n- | -\n\nplain",
                 {{table, ""}, {heading, "heading", 1}, {table, ""}, {MARKY_BLOCK_LIST, ""},
                  {table, ""}, {MARKY_BLOCK_CODE, "literal | code"}, {table, ""},
                  {MARKY_BLOCK_CODE, "literal | code"}, {table, ""}, {image, ""},
                  {table, ""}, {prose, "plain"}},
                 "MD-066–068/090–092 terminate tables before headings, lists, code, images, and blanks");
    check_blocks(check, "> A | B\n- | -\n\n- A | B\n- | -\n\n# A | B\n- | -\n\n![A|B](x)\n- | -",
                 {{MARKY_BLOCK_QUOTE, ""}, {MARKY_BLOCK_LIST, ""}, {MARKY_BLOCK_LIST, ""},
                  {heading, "A | B", 1}, {MARKY_BLOCK_LIST, ""}, {image, ""}, {MARKY_BLOCK_LIST, ""}},
                 "container and standalone image syntax take precedence over a potential table header");
}

void check_image(const auto& check, std::string_view source, size_t block_index, std::string_view alt,
                 std::string_view destination, std::optional<std::string_view> title, std::string_view fixture) {
    MarkyDocument* raw_document = nullptr;
    MarkyStatus status;
    {
        std::string input(source);
        status = marky_document_create(input.data(), input.size(), &raw_document);
        std::memset(input.data(), '?', input.size());
    }
    const std::unique_ptr<MarkyDocument, decltype(&marky_document_release)>
        document(raw_document, marky_document_release);
    const auto matches = [](MarkyUtf8View view, std::string_view expected) {
        return view.data != nullptr && std::string_view(view.data, view.byte_count) == expected;
    };
    MarkyBlockKind kind = MARKY_BLOCK_INVALID;
    MarkyUtf8View text{};
    MarkyImageView image{};
    check(status == MARKY_STATUS_OK &&
              marky_document_block_at(document.get(), block_index, &kind, &text) == MARKY_STATUS_OK &&
              kind == MARKY_BLOCK_IMAGE && matches(text, "") &&
              marky_document_image_at(document.get(), block_index, &image) == MARKY_STATUS_OK &&
              matches(image.alt, alt) && matches(image.destination, destination) &&
              (title ? matches(image.title, *title) : image.title.data == nullptr && image.title.byte_count == 0),
          fixture);
}

void check_image_blocks(const auto& check) {
    using namespace std::string_view_literals;
    constexpr auto image = MARKY_BLOCK_IMAGE;
    constexpr auto prose = MARKY_BLOCK_PARAGRAPH;
    constexpr auto code = MARKY_BLOCK_CODE;

    check_image(check, "![Marky Mascot](assets/mascot.png \"Mascot\")", 0, "Marky Mascot",
                "assets/mascot.png", "Mascot", "MD-037 preserves a relative destination and title");
    check_image(check, "![A photo](<my photo.png>)", 0, "A photo", "my photo.png", std::nullopt,
                "MD-038 preserves spaces inside an angle-bracket destination and reports a missing title");
    check_image(check, "![**raw alt**](image.png 'title')", 0, "**raw alt**", "image.png", "title",
                "MD-083 preserves raw alt markup");
    check_image(check, "A | B\n--- | ---\n![alt](image.png)", 1, "alt", "image.png", std::nullopt,
                "MD-090 exposes metadata after a table");
    check_image(check, "Intro\r\n ![e\xCC\x81\0](\t<https://example.test/a%20b \xE2\x98\x83> '' )\r\nAfter"sv,
                1, "e\xCC\x81\0"sv, "https://example.test/a%20b \xE2\x98\x83", "",
                "owned image data preserves decomposed Unicode, NUL, URL spelling, and an empty title");
    check_image(check, "![](../file.png)", 0, "", "../file.png", std::nullopt, "alt text can be empty");
    check_image(check, "![alt](image.png 'title\")", 0, "alt", "image.png", "title",
                "standalone title quotes follow the Swift matcher");

    check_blocks(check, "See ![icon](icon.png) inline\n\n![alt](my photo.png)\n\n"
                        "![outer [inner]](image.png)\n\n![a\\]b](image.png)\n\n"
                        "![pic][asset]\n\n[asset]: image.png",
                 {{prose, "See ![icon](icon.png) inline"}, {prose, "![alt](my photo.png)"},
                  {prose, "![outer [inner]](image.png)"}, {prose, "![a\\]b](image.png)"},
                  {prose, "![pic][asset]"}, {prose, "[asset]: image.png"}},
                 "MD-039/079–082 leave inline, malformed, nested, escaped and reference images in prepared prose");
    check_blocks(check, "![alt](image.png 'title\vtext')\n\n![alt](image.png 'title\ftext')",
                 {{prose, "![alt](image.png 'title\vtext')"}, {prose, "![alt](image.png 'title\ftext')"}},
                 "vertical tab and form feed inside a title keep the source in prose");
    check_blocks(check, "Before\n![alt](image.png)\nAfter\n\n```\n![fenced](x)\n```\n\n"
                        "    ![indented](x)\n\n\\![escaped](x)\n\n> ![quote](x)\n- ![list](x)",
                 {{prose, "Before"}, {image, ""}, {prose, "After"}, {code, "![fenced](x)"},
                  {code, "![indented](x)"}, {prose, "\\![escaped](x)"}, {MARKY_BLOCK_QUOTE, ""},
                  {MARKY_BLOCK_LIST, ""}},
                 "standalone images split prose and leave fenced, indented, escaped and container syntax protected");
}

void check_image_accessor_arguments(const auto& check) {
    constexpr std::string_view source = "Intro\n![alt](x 'title')";
    MarkyDocument* raw_document = nullptr;
    const auto status = marky_document_create(source.data(), source.size(), &raw_document);
    const std::unique_ptr<MarkyDocument, decltype(&marky_document_release)>
        document(raw_document, marky_document_release);
    MarkyImageView valid{};
    check(status == MARKY_STATUS_OK &&
              marky_document_image_at(document.get(), 1, &valid) == MARKY_STATUS_OK && valid.title.data != nullptr,
          "argument checks require a valid image with a title");
    const auto rejects_and_clears = [&](const MarkyDocument* candidate, size_t index) {
        auto output = valid;
        return marky_document_image_at(candidate, index, &output) == MARKY_STATUS_INVALID_ARGUMENT &&
               output.alt.data == nullptr && output.alt.byte_count == 0 &&
               output.destination.data == nullptr && output.destination.byte_count == 0 &&
               output.title.data == nullptr && output.title.byte_count == 0;
    };
    check(rejects_and_clears(document.get(), 0) && rejects_and_clears(document.get(), 2) &&
              rejects_and_clears(nullptr, 0) &&
              marky_document_image_at(document.get(), 1, nullptr) == MARKY_STATUS_INVALID_ARGUMENT,
          "image access rejects missing outputs, non-image blocks, out-of-range indices, and missing documents");
}

void check_table_accessor_arguments(const auto& check) {
    constexpr std::string_view source = "Intro\n\nA | B\n--- | ---\nOnly A";
    MarkyDocument* raw_document = nullptr;
    const auto status = marky_document_create(source.data(), source.size(), &raw_document);
    const std::unique_ptr<MarkyDocument, decltype(&marky_document_release)>
        document(raw_document, marky_document_release);
    MarkyTableColumnView column{};
    MarkyUtf8View cell{};
    check(status == MARKY_STATUS_OK &&
              marky_document_table_column_at(document.get(), 1, 0, &column) == MARKY_STATUS_OK &&
              marky_document_table_cell_at(document.get(), 1, 0, 0, &cell) == MARKY_STATUS_OK,
          "argument checks require a valid table header and body cell");
    const auto rejects_column = [&](const MarkyDocument* candidate, size_t block, size_t index) {
        auto output = column;
        return marky_document_table_column_at(candidate, block, index, &output) == MARKY_STATUS_INVALID_ARGUMENT &&
               output.alignment == MARKY_TABLE_ALIGNMENT_INVALID &&
               output.header.data == nullptr && output.header.byte_count == 0;
    };
    const auto rejects_cell = [&](const MarkyDocument* candidate, size_t block, size_t row, size_t index) {
        auto output = cell;
        return marky_document_table_cell_at(candidate, block, row, index, &output) == MARKY_STATUS_INVALID_ARGUMENT &&
               output.data == nullptr && output.byte_count == 0;
    };
    check(rejects_column(document.get(), 1, 2) && rejects_column(document.get(), 0, 0) &&
              rejects_column(document.get(), 2, 0) && rejects_column(nullptr, 1, 0) &&
              marky_document_table_column_at(document.get(), 1, 0, nullptr) == MARKY_STATUS_INVALID_ARGUMENT,
          "invalid column lookups reject missing outputs and clear stale views");
    check(rejects_cell(document.get(), 1, 1, 0) && rejects_cell(document.get(), 1, 0, 2) &&
              rejects_cell(document.get(), 0, 0, 0) && rejects_cell(document.get(), 2, 0, 0) &&
              rejects_cell(nullptr, 1, 0, 0) &&
              marky_document_table_cell_at(document.get(), 1, 0, 0, nullptr) == MARKY_STATUS_INVALID_ARGUMENT,
          "invalid cell lookups reject missing outputs and clear stale views");
    for (const size_t index : {0, 2}) {
        check(marky_document_table_column_count(document.get(), index) == 0 &&
                  marky_document_table_row_count(document.get(), index) == 0,
              "non-table and out-of-range blocks report zero columns and rows");
    }
    check(marky_document_table_column_count(nullptr, 0) == 0 && marky_document_table_row_count(nullptr, 0) == 0,
          "NULL documents report zero columns and rows");
    check(marky_document_table_row_content_count(document.get(), 1, 0) == 1 &&
              marky_document_table_row_content_count(document.get(), 1, 1) == 0 &&
              marky_document_table_row_content_count(document.get(), 0, 0) == 0 &&
              marky_document_table_row_content_count(nullptr, 0, 0) == 0,
          "the body content count excludes padding and is zero for invalid rows or blocks");
}

void check_fences(const auto& check) {
    constexpr auto code = MARKY_BLOCK_CODE;
    constexpr auto prose = MARKY_BLOCK_PARAGRAPH;
    check_blocks(check, " \r\n\t\r\n", {}, "MD-002: blank CRLF input");
    check_blocks(check, "````example\n```\n**literal**\n```` trailing text\n````\nAfter",
                 {{code, "```\n**literal**\n```` trailing text"}, {prose, "After"}},
                 "MD-008: backtick closer length and trailing text");
    check_blocks(check, "~~~~example\n~~~\n**literal**\n~~~~ trailing text\n~~~~\nAfter",
                 {{code, "~~~\n**literal**\n~~~~ trailing text"}, {prose, "After"}},
                 "MD-009: tilde closer length and trailing text");
    check_blocks(check, "```\nunclosed **literal**", {{code, "unclosed **literal**"}},
                 "MD-010: unclosed code reaches EOF");
    check_blocks(check, "~~~\n    ~~~\n**literal**\n~~~\nAfter",
                 {{code, "    ~~~\n**literal**"}, {prose, "After"}},
                 "MD-011: four-space closer stays literal");
    check_blocks(check, "```bad`info\nbody", {{prose, "```bad`info body"}},
                 "MD-053: invalid backtick opener stays prose");
    check_blocks(check, "   ~~~ info`ok\nbody\n   ~~~~\nafter", {{code, "body"}, {prose, "after"}},
                 "MD-054: three-space indentation, longer closer, and backticks in tilde info");
    check_blocks(check, "```\n~~~\n``\n```suffix\n```", {{code, "~~~\n``\n```suffix"}},
                 "MD-055: mismatched, short, and suffixed closers stay literal");
    check_blocks(check, "```\n```", {{code, ""}}, "MD-056: empty code block");

    using namespace std::string_view_literals;
    check_blocks(check, "Intro\r\n```\r\n  e\xCC\x81 \xF0\x9F\x8E\xB5\0\r\n[ref]: /literal\r\n"
                        "```\t\xE2\x80\xAF\r\nAfter\r"sv,
                 {{prose, "Intro"}, {code, "  e\xCC\x81 \xF0\x9F\x8E\xB5\0\n[ref]: /literal"sv},
                  {prose, "After\r"}}, "CRLF, Unicode closer whitespace, and exact literal bytes");
    check_blocks(check, "\t```\n    ~~~", {{code, "```\n~~~"}}, "indented openers remain literal code");
    check_blocks(check, "~~~\n~~~\n\n```\n\nlast\n", {{code, ""}, {code, "\nlast\n"}},
                 "adjacent fences retain empty code and unclosed literal line endings");

    MarkyDocument* document = nullptr;
    check(marky_document_create("```", 3, &document) == MARKY_STATUS_OK,
          "a fence opener alone produces an owned document");
    MarkyBlockKind kind = MARKY_BLOCK_CODE;
    MarkyUtf8View text{"stale", 5};
    check(marky_document_block_at(document, 1, &kind, &text) == MARKY_STATUS_INVALID_ARGUMENT &&
              kind == MARKY_BLOCK_INVALID && text.data == nullptr && text.byte_count == 0,
          "the block accessor clears outputs on a bad index");
    text = {"stale", 5};
    check(marky_document_block_at(document, 0, nullptr, &text) == MARKY_STATUS_INVALID_ARGUMENT &&
              text.data == nullptr && text.byte_count == 0,
          "the block accessor rejects a missing kind output and clears the view");
    kind = MARKY_BLOCK_CODE;
    check(marky_document_block_at(document, 0, &kind, nullptr) == MARKY_STATUS_INVALID_ARGUMENT &&
              kind == MARKY_BLOCK_INVALID,
          "the block accessor rejects a missing view output and clears the kind");
    text = {"stale", 5};
    check(marky_document_paragraph_at(document, 0, &text) == MARKY_STATUS_INVALID_ARGUMENT &&
              text.data == nullptr && text.byte_count == 0,
          "the paragraph accessor rejects a code block and clears the view");
    marky_document_release(document);
}

void check_base_blocks(const auto& check) {
    constexpr auto prose = MARKY_BLOCK_PARAGRAPH;
    constexpr auto code = MARKY_BLOCK_CODE;
    constexpr auto heading = MARKY_BLOCK_HEADING;
    constexpr auto rule = MARKY_BLOCK_THEMATIC_BREAK;

    check_blocks(check, "First line\r\nsecond line\r\n\r\nNext",
                 {{prose, "First line second line"}, {prose, "Next"}},
                 "MD-003: soft lines join and blank lines split paragraphs");
    check_blocks(check, "first  \nsecond\r\nthird",
                 {{prose, "first\nsecond third"}}, "MD-045: retain a hard break before trimming");
    check_blocks(check, "first\\\nsecond\\\\\nthird",
                 {{prose, "first\\\nsecond\\\\\nthird"}}, "MD-046/047: preserve backslashes for inline parsing");
    check_blocks(check, "first  \nsecond\\\n=\n\nnext\n-",
                 {{heading, "first second\\", 1}, {heading, "next", 2}},
                 "MD-051: single-character Setext underlines and space joining for heading source");
    check_blocks(check, "title\n---\n---\n- - -\n***\n___\n--\n*_*",
                 {{heading, "title", 2}, {rule, ""}, {rule, ""}, {rule, ""}, {rule, ""},
                  {prose, "-- *_*"}}, "Setext precedes thematic breaks and malformed rules remain prose");
    check_blocks(check, "#no\n####### seven\n#\n#\tinvalid\n   # valid ###\n## attached###\n"
                        "### tab-separated\t###\n###### six",
                 {{prose, "#no ####### seven # #\tinvalid"}, {heading, "valid", 1},
                  {heading, "attached###", 2}, {heading, "tab-separated\t###", 3},
                  {heading, "six", 6}}, "MD-049/050: ATX opening and closing hash boundaries");
    check_blocks(check, "   # heading\n\n    # code\n\tmore\n\nplain\n    continuation",
                 {{heading, "heading", 1}, {code, "# code\nmore"}, {prose, "plain continuation"}},
                 "MD-052/057: indentation starts code only outside a paragraph");
    check_blocks(check, "     one  \n \t\n      \n\t\t[ref]: /literal\n     \n\n~~~\n"
                        "---\n# heading\n~~~\n    after",
                 {{code, " one  \n\n  \n\t[ref]: /literal"}, {code, "---\n# heading"}, {code, "after"}},
                 "literal blocks keep internal whitespace and protect syntax across block boundaries");
    check_blocks(check, "\xC2\xA0" "e\xCC\x81\xE3\x80\x80\n\xE2\x80\xA8\n"
                        "*\xE2\x80\x83*\t*\n-\xE2\x80\x8B-\xE2\x80\x8B-",
                 {{prose, "e\xCC\x81"}, {rule, ""}, {prose, "-\xE2\x80\x8B-\xE2\x80\x8B-"}},
                 "trim Unicode whitespace and distinguish whitespace inside thematic rules");

    check_blocks(check, "    one\n    \xE2\x80\xA8\n\xE2\x80\xA9\n~~~\ncode\n~~~\n"
                        "    two\n    \xE2\x80\xA8\n\xE2\x80\xA9\nplain",
                 {{code, "one"}, {code, "code"}, {code, "two\n\xE2\x80\xA8"}, {prose, "plain"}},
                 "trim vertical blank lines at prose segment boundaries and retain internal code bytes");

    MarkyDocument* document = nullptr;
    check(marky_document_create("# Title", 7, &document) == MARKY_STATUS_OK,
          "a heading produces an owned document");
    uint32_t level = 99;
    check(marky_document_heading_level_at(document, 1, &level) == MARKY_STATUS_INVALID_ARGUMENT &&
              level == 0, "a bad heading index clears the level");
    level = 99;
    check(marky_document_heading_level_at(nullptr, 0, &level) == MARKY_STATUS_INVALID_ARGUMENT &&
              level == 0, "a NULL document clears the level");
    check(marky_document_heading_level_at(document, 0, nullptr) == MARKY_STATUS_INVALID_ARGUMENT,
          "a NULL heading output is rejected");
    MarkyUtf8View text{"stale", 5};
    check(marky_document_paragraph_at(document, 0, &text) == MARKY_STATUS_INVALID_ARGUMENT &&
              text.data == nullptr && text.byte_count == 0,
          "the paragraph accessor rejects headings and clears the view");
    marky_document_release(document);
}

void check_combining_delimiters(const auto& check) {
    constexpr auto prose = MARKY_BLOCK_PARAGRAPH;
    constexpr auto heading = MARKY_BLOCK_HEADING;
    constexpr auto rule = MARKY_BLOCK_THEMATIC_BREAK;

    check_blocks(check, "# \xCC\x81" "body",
                 {{prose, "# \xCC\x81" "body"}},
                 "a space with a combining accent does not open an ATX heading");
    check_blocks(check, "- \xCC\x81- -", {{rule, ""}},
                 "a space with a combining accent is whitespace inside a thematic break");
    check_blocks(check, "*\xC2\xA0\xCC\x80\xCD\xAF* *\n\n*\t\xCC\x81* *",
                 {{rule, ""}, {prose, "*\t\xCC\x81* *"}},
                 "multiple accents attach to a nonbreaking space but do not attach to a tab");
    check_blocks(check, "## Cafe\xCC\x81\n\n-\xCC\x81 - -",
                 {{heading, "Cafe\xCC\x81", 2}, {prose, "-\xCC\x81 - -"}},
                 "accents stay in heading text and do not extend a thematic marker");
}

void check_malformed_blocks(const auto& check) {
    constexpr auto prose = MARKY_BLOCK_PARAGRAPH;
    constexpr auto code = MARKY_BLOCK_CODE;
    check_blocks(check, "Title\r\n===oops\r\n\\# escaped\r\n\r\n"
                        "```bad`info\r\n    still prose\r\n\r\n"
                        "~~~\r\n    # literal\r\n~~~suffix\r\n",
                 {{prose, "Title ===oops \\# escaped"}, {prose, "```bad`info still prose"},
                  {code, "    # literal\n~~~suffix\n"}},
                 "malformed block syntax remains readable and an invalid closer stays literal at EOF");
}

void check_code_spans(const auto& check) {
    constexpr std::string_view row = "``a`b|c`` | d";
    const auto end = marky::code_span_end(row, 0, marky::delimiter_run_length(row, '`'));
    check(end == row.find(" | d"), "MD-064: skip inner backticks and pipe up to the full closer");
    check(marky::code_span_end("`open | tail", 0, 1) == std::string_view::npos,
          "MD-064: unmatched run leaves the pipe visible to the caller");

    constexpr std::string_view inner = "``unclosed `tick` after";
    check(marky::code_span_end(inner, 0, 2) == std::string_view::npos &&
              marky::code_span_end(inner, inner.find('`', 2), 1) == inner.find(" after"),
          "MD-042: a failed outer run does not consume a later matched inner span");
    constexpr std::string_view unicode = "\xF0\x9F\x8E\xB5`e\xCC\x81\\`|tail";
    check(marky::code_span_end(unicode, unicode.find('`'), 1) == unicode.find('|'),
          "span offsets count UTF-8 bytes and backslashes within a span stay literal");
    check(marky::code_span_end("`x``", 0, 1) == std::string_view::npos,
          "a longer closing run cannot supply a partial closer");
}

struct ExpectedCodeSpan {
    marky::CodeSpan bytes;
    std::string_view literal;
};

void check_inline_code(const auto& check, std::string_view prepared,
                       std::initializer_list<ExpectedCodeSpan> expected, std::string_view fixture) {
    marky::CodeSpanScanner scanner(prepared);
    for (const auto& [bytes, literal] : expected) {
        const auto span = scanner.next();
        const bool ranges_match = span && span->begin == bytes.begin && span->end == bytes.end &&
                                  span->content_begin == bytes.content_begin && span->content_end == bytes.content_end;
        check(ranges_match && marky::normalize_code_span(
                                  prepared.substr(span->content_begin, span->content_end - span->content_begin)) == literal,
              fixture);
    }
    check(!scanner.next(), fixture);
}

struct ExpectedInlineParagraph {
    std::string_view source;
    std::initializer_list<ExpectedCodeSpan> spans;
};

void check_inline_paragraphs(const auto& check, std::string_view input,
                             std::initializer_list<ExpectedInlineParagraph> expected, std::string_view fixture) {
    MarkyDocument* raw_document = nullptr;
    const auto status = marky_document_create(input.data(), input.size(), &raw_document);
    const std::unique_ptr<MarkyDocument, decltype(&marky_document_release)>
        document(raw_document, marky_document_release);
    check(status == MARKY_STATUS_OK && marky_document_block_count(document.get()) == expected.size(), fixture);

    size_t index = 0;
    for (const auto& paragraph : expected) {
        MarkyUtf8View view{};
        if (marky_document_paragraph_at(document.get(), index++, &view) != MARKY_STATUS_OK) {
            check(false, fixture);
            continue;
        }
        const std::string_view prepared(view.data, view.byte_count);
        check(prepared == paragraph.source, fixture);
        check_inline_code(check, prepared, paragraph.spans, fixture);
    }
}

void check_literal_code_spans(const auto& check) {
    // MD-041–044 use the accepted production paragraph route from the shared corpus.
    check_inline_paragraphs(check, "Before ``first\nsecond`` after",
                           {{"Before ``first second`` after", {{{7, 9, 21, 23}, "first second"}}}},
                           "MD-041: soft lines stay in the same span");
    check_inline_paragraphs(check, "Before ``unclosed `tick` after",
                           {{"Before ``unclosed `tick` after", {{{18, 19, 23, 24}, "tick"}}}},
                           "MD-042: the unmatched outer run stays visible before the inner span");
    check_inline_paragraphs(check, "Before `` padded `` after",
                           {{"Before `` padded `` after", {{{7, 9, 17, 19}, "padded"}}}},
                           "MD-043: literal text removes one space on each side");
    check_inline_paragraphs(check, "`first\n\nsecond`", {{"`first", {}}, {"second`", {}}},
                           "MD-044: blank lines split paragraphs before scanning");

    check_inline_paragraphs(check, "a ` first  \r\nsecond ` z",
                           {{"a ` first\nsecond ` z", {{{2, 3, 17, 18}, "first second"}}}},
                           "a retained LF becomes a space inside code");
    check_inline_paragraphs(check, "a `  \n` z",
                           {{"a `\n` z", {{{2, 3, 4, 5}, " "}}}},
                           "an all-space span preserves its spaces after LF normalization");
    check_inline_paragraphs(check, "a `x\ry` z", {{"a `x\ry` z", {{{2, 3, 6, 7}, "x y"}}}},
                           "a bare CR stays in the prepared source and becomes a space inside code");
    check_inline_code(check, "a `x\r\ny` z", {{{2, 3, 7, 8}, "x y"}},
                      "a CRLF in inline source becomes one space inside code");
    constexpr std::string_view padding = "x `   ` ` left` `right ` `  two  ` `\t padded \t` `\xC2\xA0word\xC2\xA0`";
    check_inline_paragraphs(check, padding,
                           {{padding, {{{2, 3, 6, 7}, "   "}, {{8, 9, 14, 15}, " left"},
                                       {{16, 17, 23, 24}, "right "}, {{25, 26, 33, 34}, " two "},
                                       {{35, 36, 46, 47}, "\t padded \t"},
                                       {{48, 49, 57, 58}, "\xC2\xA0word\xC2\xA0"}}}},
                           "all-space and one-sided padding, tabs, and nonbreaking spaces stay literal");

    constexpr std::string_view unicode =
        "\xE2\x99\xAB" "e\xCC\x81`` **a** [ref]|&amp; \\` x``` end ``\xE9\x9B\xAA";
    check_inline_paragraphs(check, unicode,
                           {{unicode, {{{6, 8, 39, 41}, "**a** [ref]|&amp; \\` x``` end"}}}},
                           "ranges count UTF-8 bytes and skip longer runs over protected punctuation");
    constexpr std::string_view escaped = "a \\``x` \\\\`y` z";
    check_inline_paragraphs(check, escaped,
                           {{escaped, {{{4, 5, 6, 7}, "x"}, {{10, 11, 12, 13}, "y"}}}},
                           "escape parity and a backtick remaining after an escaped opener");
    check_inline_paragraphs(check, "a \\`escaped` z\n\na `x``\n\nx `a\\` z",
                           {{"a \\`escaped` z", {}}, {"a `x``", {}}, {"x `a\\` z", {{{2, 3, 5, 6}, "a\\"}}}},
                           "escaped openers and longer closers stay visible, while an interior backslash is literal");
}

void check_literal_code_in_table(const auto& check) {
    constexpr std::string_view input = "Code | Tail\n--- | ---\n`` [x](y)|\\|&amp;``` `` | final";
    MarkyDocument* raw_document = nullptr;
    const auto status = marky_document_create(input.data(), input.size(), &raw_document);
    const std::unique_ptr<MarkyDocument, decltype(&marky_document_release)>
        document(raw_document, marky_document_release);
    MarkyUtf8View code{};
    MarkyUtf8View tail{};
    const bool is_table = status == MARKY_STATUS_OK && marky_document_block_count(document.get()) == 1 &&
                          marky_document_table_column_count(document.get(), 0) == 2 &&
                          marky_document_table_row_content_count(document.get(), 0, 0) == 2 &&
                          marky_document_table_cell_at(document.get(), 0, 0, 0, &code) == MARKY_STATUS_OK &&
                          marky_document_table_cell_at(document.get(), 0, 0, 1, &tail) == MARKY_STATUS_OK;
    check(is_table, "table splitting skips the full code span to the next real pipe");
    if (is_table) {
        const std::string_view prepared(code.data, code.byte_count);
        check(prepared == "`` [x](y)|\\|&amp;``` ``" && std::string_view(tail.data, tail.byte_count) == "final",
              "table splitting preserves code source and the following cell");
        check_inline_code(check, prepared, {{{0, 2, 21, 23}, "[x](y)|\\|&amp;```"}},
                          "inline code normalizes cell padding and preserves literal pipes, escapes, and punctuation");
    }
}

void check_cancellation(const auto& check) {
    MarkyCancellationToken* raw_token = nullptr;
    check(marky_cancellation_token_create(&raw_token) == MARKY_STATUS_OK && raw_token != nullptr,
          "token creation must return an owned, initially active token");
    std::unique_ptr<MarkyCancellationToken, decltype(&marky_cancellation_token_release)>
        token(raw_token, marky_cancellation_token_release);

    MarkyDocument* document = nullptr;
    check(marky_document_create_cancellable("keep", 4, token.get(), &document) ==
              MARKY_STATUS_OK && document != nullptr,
          "an active token must allow creation");
    marky_cancellation_token_request(token.get());
    marky_cancellation_token_request(token.get());
    for (int attempt = 0; attempt < 2; ++attempt) {
        MarkyDocument* output = document;
        check(marky_document_create_cancellable(nullptr, 0, token.get(), &output) ==
                  MARKY_STATUS_CANCELLED && output == nullptr,
              "a cancelled token must keep cancelling, even for empty input");
        output = document;
        check(marky_document_create_cancellable(nullptr, 1, token.get(), &output) ==
                  MARKY_STATUS_INVALID_ARGUMENT && output == nullptr,
              "invalid input must take precedence over cancellation");
    }

    marky_cancellation_token_request(nullptr);
    marky_cancellation_token_release(nullptr);
    check(marky_cancellation_token_create(nullptr) == MARKY_STATUS_INVALID_ARGUMENT,
          "token creation must reject a missing output slot");
    check(marky_document_create_cancellable("x", 1, token.get(), nullptr) ==
              MARKY_STATUS_INVALID_ARGUMENT,
          "a cancelled call must reject a missing document slot");

    token.reset();
    MarkyUtf8View text{};
    check(marky_document_paragraph_at(document, 0, &text) == MARKY_STATUS_OK &&
              text.data != nullptr && std::string_view(text.data, text.byte_count) == "keep",
          "a published result must survive cancellation and token release");
    marky_document_release(document);
}

void check_concurrent_calls(const auto& check) {
    MarkyCancellationToken* raw_token = nullptr;
    const auto status = marky_cancellation_token_create(&raw_token);
    std::unique_ptr<MarkyCancellationToken, decltype(&marky_cancellation_token_release)>
        token(raw_token, marky_cancellation_token_release);
    const bool active_token_created = status == MARKY_STATUS_OK && token != nullptr;
    check(active_token_created, "concurrent calls need a live token");
    if (!active_token_created) {
        return;
    }

    constexpr std::array<std::string_view, 4> inputs{"first", "second", "third", "fourth"};
    std::array<bool, inputs.size()> succeeded{};
    std::array<std::thread, inputs.size()> workers;
    std::barrier start(static_cast<std::ptrdiff_t>(workers.size()));
    for (size_t index = 0; index < workers.size(); ++index) {
        workers[index] = std::thread([&, index] {
            start.arrive_and_wait();
            const auto input = inputs[index];
            bool matches = true;
            for (int attempt = 0; attempt < 64; ++attempt) {
                MarkyDocument* document = nullptr;
                MarkyUtf8View text{};
                const auto result = marky_document_create_cancellable(
                    input.data(), input.size(), token.get(), &document);
                matches &= result == MARKY_STATUS_OK &&
                           marky_document_paragraph_at(document, 0, &text) == MARKY_STATUS_OK &&
                           text.data != nullptr &&
                           std::string_view(text.data, text.byte_count) == input;
                marky_document_release(document);
            }
            start.arrive_and_wait();
            for (int attempt = 0; attempt < 64; ++attempt) {
                marky_cancellation_token_request(token.get());
                MarkyDocument* document = nullptr;
                const auto result = marky_document_create_cancellable(
                    input.data(), input.size(), token.get(), &document);
                matches &= result == MARKY_STATUS_CANCELLED && document == nullptr;
                marky_document_release(document);
            }
            succeeded[index] = matches;
        });
    }
    for (size_t index = 0; index < workers.size(); ++index) {
        workers[index].join();
        check(succeeded[index], "parallel calls must preserve bytes and honor shared cancellation");
    }

    MarkyDocument* document = nullptr;
    const auto result = marky_document_create("fresh", 5, &document);
    token.reset();
    check(result == MARKY_STATUS_OK && marky_document_block_count(document) == 1,
          "a tokenless call must remain independent of a cancelled token");
    marky_document_release(document);
}

}

int main() {
    int failures = 0;
    const auto check = [&failures](bool condition, std::string_view message) {
        if (!condition) {
            std::cerr << "FAIL: " << message << '\n';
            ++failures;
        }
    };

    check_owned_paragraph(check);
    check_empty_document(check, nullptr);
    check_empty_document(check, "");
    check_fences(check);
    check_base_blocks(check);
    check_list_blocks(check);
    check_list_accessor_arguments(check);
    check_list_boundaries(check);
    check_quote_blocks(check);
    check_quote_accessor_arguments(check);
    check_table_blocks(check);
    check_table_accessor_arguments(check);
    check_image_blocks(check);
    check_image_accessor_arguments(check);
    check_combining_delimiters(check);
    check_malformed_blocks(check);
    check_code_spans(check);
    check_literal_code_spans(check);
    check_literal_code_in_table(check);
    check_cancellation(check);
    check_concurrent_calls(check);

    check(marky_document_create("x", 1, nullptr) == MARKY_STATUS_INVALID_ARGUMENT,
          "a missing output handle must be rejected");
    check(marky_document_block_count(nullptr) == 0,
          "a NULL document must report no blocks");
    MarkyUtf8View text{"stale", 5};
    check(marky_document_paragraph_at(nullptr, 0, &text) == MARKY_STATUS_INVALID_ARGUMENT &&
              text.data == nullptr && text.byte_count == 0,
          "a NULL document must clear the output view");
    marky_document_release(nullptr);

    // Exercise the same failure path under CTest, including Release/NDEBUG builds.
    const char* force_failure = std::getenv("MARKY_CORE_TEST_FORCE_FAILURE");
    if (force_failure != nullptr && std::string_view(force_failure) == "1") {
        check(false, "intentional harness failure");
    }

    if (failures != 0) {
        return EXIT_FAILURE;
    }
    std::cout << "PASS: document ownership, base blocks, lists, quotes, tables, images, code spans, cancellation and concurrency checks\n";
    return EXIT_SUCCESS;
}
