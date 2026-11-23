#include "MarkyCore.h"

#include <array>
#include <cstdlib>
#include <iostream>
#include <memory>
#include <random>
#include <string>
#include <string_view>
#include <vector>

namespace {

using Document = std::unique_ptr<MarkyDocument, decltype(&marky_document_release)>;
using Tree = std::unique_ptr<MarkyProjectTree, decltype(&marky_project_tree_release)>;
using QueryResult = std::unique_ptr<MarkyProjectQueryResult, decltype(&marky_project_query_result_release)>;
using Favorites = std::unique_ptr<MarkyProjectFavoriteResult, decltype(&marky_project_favorite_result_release)>;

constexpr auto complete = MARKY_PROJECT_SCAN_COMPLETE;
constexpr auto invalid = MARKY_STATUS_INVALID_ARGUMENT;

void require(bool condition, std::string_view message) {
    if (!condition) {
        std::cerr << "FAIL: " << message << '\n';
        std::exit(EXIT_FAILURE);
    }
}

MarkyUtf8View view(std::string_view text) {
    return {text.data(), text.size()};
}

std::string_view text(MarkyUtf8View value) {
    return value.data ? std::string_view(value.data, value.byte_count) : std::string_view{};
}

constexpr MarkyProjectTreeEntry root{{"root", 4}, {}, 0, {}};
constexpr MarkyProjectEntryMetadata markdown{{"md", 2}, MARKY_PROJECT_ENTRY_REGULAR_FILE, 0, 0};

Document parse(std::string_view input, MarkyStatus expected = MARKY_STATUS_OK, MarkyUtf8View prefix = {}) {
    MarkyDocument* raw = nullptr;
    const auto status = marky_document_create_with_quote_prefix(input.data(), input.size(), nullptr, prefix, &raw);
    Document document(raw, marky_document_release);
    require(status == expected && (raw != nullptr) == (expected == MARKY_STATUS_OK),
            "document status and result ownership");
    return document;
}

Tree build_tree(const MarkyProjectTreeEntry* entries, size_t count, MarkyStatus expected = MARKY_STATUS_OK) {
    MarkyProjectTree* raw = nullptr;
    const auto status = marky_project_tree_create(entries, count, complete, nullptr, &raw);
    Tree tree(raw, marky_project_tree_release);
    require(status == expected && (raw != nullptr) == (expected == MARKY_STATUS_OK),
            "project tree status and result ownership");
    return tree;
}

void check_runs(const MarkyDocument* document, MarkyInlineLocation location, size_t source_size) {
    size_t previous_end = 0;
    const size_t count = marky_document_inline_run_count(document, location);
    for (size_t index = 0; index < count; ++index) {
        MarkyInlineRunView run{};
        require(marky_document_inline_run_at(document, location, index, &run) == MARKY_STATUS_OK,
                "advertised run is readable");
        require(previous_end <= run.source_begin && run.source_begin < run.source_end &&
                    run.source_end <= source_size,
                "inline ranges are ordered and lie inside the prepared region");
        previous_end = run.source_end;
    }
    MarkyInlineRunView past_end{};
    require(marky_document_inline_run_at(document, location, count, &past_end) == invalid,
            "one-past-end inline run is rejected");
}

void check_document_views(const MarkyDocument* document) {
    const auto count = marky_document_block_count(document);
    for (size_t block = 0; block < count; ++block) {
        MarkyBlockKind kind{};
        MarkyUtf8View source{};
        require(marky_document_block_at(document, block, &kind, &source) == MARKY_STATUS_OK,
                "advertised block is readable");
        switch (kind) {
        case MARKY_BLOCK_PARAGRAPH:
        case MARKY_BLOCK_HEADING:
            check_runs(document, {block, 0, 0}, source.byte_count);
            break;
        case MARKY_BLOCK_QUOTE: {
            const auto lines = marky_document_quote_line_count(document, block);
            require(lines > 0, "quote has a line");
            size_t bytes = lines - 1;
            for (size_t line = 0; line < lines; ++line) {
                MarkyQuoteLineView quote{};
                require(marky_document_quote_line_at(document, block, line, &quote) == MARKY_STATUS_OK,
                        "advertised quote line is readable");
                bytes += quote.source.byte_count;
            }
            check_runs(document, {block, 0, 0}, bytes);
            break;
        }
        case MARKY_BLOCK_LIST:
            for (size_t row = 0; row < marky_document_list_item_count(document, block); ++row) {
                MarkyListItemView item{};
                require(marky_document_list_item_at(document, block, row, &item) == MARKY_STATUS_OK,
                        "advertised list item is readable");
                check_runs(document, {block, row, 0}, item.source.byte_count);
            }
            break;
        case MARKY_BLOCK_TABLE: {
            const auto columns = marky_document_table_column_count(document, block);
            const auto rows = marky_document_table_row_count(document, block);
            for (size_t column = 0; column < columns; ++column) {
                MarkyTableColumnView header{};
                require(marky_document_table_column_at(document, block, column, &header) == MARKY_STATUS_OK,
                        "advertised table header is readable");
                check_runs(document, {block, 0, column}, header.header.byte_count);
                for (size_t row = 0; row < rows; ++row) {
                    MarkyUtf8View cell{};
                    require(marky_document_table_cell_at(document, block, row, column, &cell) == MARKY_STATUS_OK,
                            "advertised table cell is readable");
                    check_runs(document, {block, row + 1, column}, cell.byte_count);
                }
            }
            break;
        }
        case MARKY_BLOCK_IMAGE: {
            MarkyImageView image{};
            require(marky_document_image_at(document, block, &image) == MARKY_STATUS_OK &&
                        image.destination.data != nullptr, "image exposes its destination");
            break;
        }
        case MARKY_BLOCK_CODE:
        case MARKY_BLOCK_THEMATIC_BREAK:
            break;
        default:
            require(false, "block has a known kind");
        }
    }
}

void check_malformed_and_misuse() {
    const auto valid_document = parse("readable");
    const std::array valid_entries{root, MarkyProjectTreeEntry{view("id"), view("note.md"), 0, markdown}};
    const auto valid_tree = build_tree(valid_entries.data(), valid_entries.size());
    for (std::string_view malformed : {"\x80", "\xC0\xAF", "\xC2", "\xE0\x80\x80", "\xED\xA0\x80",
                                       "\xE2\x82", "\xE2" "x" "\xAC", "\xF0\x80\x80\x80",
                                       "\xF4\x90\x80\x80", "\xF4\x8F\xBF", "\xF5\x80\x80\x80", "\xFF"}) {
        MarkyDocument* output = valid_document.get();
        require(marky_document_create(malformed.data(), malformed.size(), &output) == invalid && !output,
                "malformed document clears output");
        parse("> quote", invalid, view(malformed));

        auto entries = valid_entries;
        entries[1].metadata.name_extension = view(malformed);
        require(marky_project_classify_entry(entries[1].metadata) == MARKY_PROJECT_ENTRY_SKIP,
                "classifier skips a malformed extension");
        build_tree(entries.data(), entries.size(), invalid);
        entries = valid_entries;
        entries[1].name = view(malformed);
        build_tree(entries.data(), entries.size(), invalid);
        entries = valid_entries;
        entries[1].identity = view(malformed);
        build_tree(entries.data(), entries.size(), invalid);

        size_t index = 99;
        const std::array path{view("absent"), view(malformed)};
        require(marky_project_tree_find_path(valid_tree.get(), path.data(), path.size(), &index) == invalid &&
                    marky_project_tree_find_identity(valid_tree.get(), view(malformed), &index) == invalid &&
                    index == 99, "invalid project lookup preserves the caller's index");

        const auto key = view(malformed);
        MarkyProjectFavoriteResult* raw = nullptr;
        require(marky_project_reconcile_favorites({{&key, 1}, {}, {}, complete, 0}, nullptr, &raw) == invalid &&
                    raw == nullptr, "malformed favorite key is rejected");
    }

    static constexpr char edge_bytes[] = "\0\x7F\xC2\x80\xDF\xBF\xE0\xA0\x80\xED\x9F\xBF"
                                         "\xEE\x80\x80\xEF\xBF\xBF\xF0\x90\x80\x80\xF4\x8F\xBF\xBF";
    constexpr std::string_view unicode_edges(edge_bytes, sizeof(edge_bytes) - 1);
    const auto unicode_document = parse(unicode_edges);
    MarkyUtf8View source{};
    require(marky_document_paragraph_at(unicode_document.get(), 0, &source) == MARKY_STATUS_OK &&
                text(source) == unicode_edges, "valid UTF-8 scalar boundaries and NUL survive intact");

    MarkyDocument* document_output = valid_document.get();
    require(marky_document_create(nullptr, 1, &document_output) == invalid && !document_output,
            "null document bytes with nonzero length clear output");
    MarkyProjectTree* tree_output = valid_tree.get();
    require(marky_project_tree_create(nullptr, 1, complete, nullptr, &tree_output) == invalid && !tree_output,
            "null project entries with nonzero count clear output");

    MarkyProjectQueryResult* query_output = nullptr;
    require(marky_project_tree_filter(valid_tree.get(), {nullptr, 1, nullptr, 0}, nullptr, &query_output) ==
                invalid && !query_output, "null match flags with nonzero count are rejected");
    const MarkyProjectFavoriteMatch bad_index{valid_entries.size(), 1};
    require(marky_project_tree_filter(valid_tree.get(), {nullptr, 0, &bad_index, 1}, nullptr, &query_output) ==
                invalid && !query_output, "one-past-end favorite node is rejected");
}

void check_document_stress() {
    constexpr size_t paragraphs = 8192;
    constexpr std::string_view paragraph = "Text **strong** and ~~strike~~ with [link](note.md).\n\n";
    std::string input;
    input.reserve(paragraphs * paragraph.size());
    for (size_t index = 0; index < paragraphs; ++index) {
        input += paragraph;
    }
    const auto large = parse(input);
    require(marky_document_block_count(large.get()) == paragraphs, "large document keeps every paragraph");
    check_document_views(large.get());

    std::string delimiters = "Start ";
    for (size_t index = 0; index < 8192; ++index) {
        delimiters += "*_~[x ` &amp; ";
    }
    delimiters += "end";
    const auto mixed = parse(delimiters);
    require(marky_document_block_count(mixed.get()) == 1, "delimiter stress stays in one paragraph");
    check_document_views(mixed.get());

    constexpr size_t depth = 4096;
    std::string quote;
    std::string images;
    for (size_t index = 0; index < depth; ++index) {
        quote += "> ";
        images += "![";
    }
    quote += "leaf";
    images += "leaf";
    for (size_t index = 0; index < depth; ++index) {
        images += "](x)";
    }
    const auto nested_quote = parse(quote);
    const auto nested_images = parse("Start " + images + " end");
    MarkyQuoteLineView line{};
    require(marky_document_quote_line_at(nested_quote.get(), 0, 0, &line) == MARKY_STATUS_OK &&
                line.depth == depth && text(line.source) == "leaf", "deep quote exposes the leaf and depth");
    MarkyInlineRunView image{};
    require(marky_document_inline_run_at(nested_images.get(), {0, 0, 0}, 1, &image) == MARKY_STATUS_OK &&
                (image.flags & MARKY_INLINE_IMAGE_ALT) != 0 && text(image.text) == "leaf" &&
                text(image.image_destination) == "x", "deep inline images expose the flattened description");
    check_document_views(nested_quote.get());
    check_document_views(nested_images.get());
}

void check_project_stress() {
    constexpr size_t depth = 4096;
    constexpr size_t siblings = 8192;
    constexpr MarkyProjectEntryMetadata directory{{}, MARKY_PROJECT_ENTRY_DIRECTORY, 0, 0};
    std::vector<std::string> names;
    std::vector<MarkyProjectTreeEntry> entries{root};
    names.reserve(depth + siblings);
    for (size_t index = 1; index <= depth + siblings; ++index) {
        const bool folder = index < depth;
        names.push_back(std::to_string(index) + (folder ? "" : ".md"));
        const auto name = view(names.back());
        entries.push_back({name, name, index <= depth ? index - 1 : 0, folder ? directory : markdown});
    }
    const auto tree = build_tree(entries.data(), entries.size());
    const auto count = marky_project_tree_node_count(tree.get());
    require(count == entries.size(), "large project retains the deep path and all siblings");

    std::vector<MarkyUtf8View> path;
    for (size_t index = 0; index < depth; ++index) {
        path.push_back(view(names[index]));
    }
    size_t found{};
    require(marky_project_tree_find_path(tree.get(), path.data(), path.size(), &found) == MARKY_STATUS_OK &&
                found == depth, "deep relative path resolves to its leaf");

    std::vector<uint8_t> matches(count);
    matches[depth] = 1;
    const MarkyProjectFavoriteMatch favorite{depth, 0};
    MarkyProjectQueryResult* raw = nullptr;
    const auto status = marky_project_tree_filter(tree.get(), {matches.data(), count, &favorite, 1}, nullptr, &raw);
    const QueryResult result(raw, marky_project_query_result_release);
    require(status == MARKY_STATUS_OK && raw, "large project query succeeds");
    const auto filtered = marky_project_query_result_view(result.get());
    require(filtered.file_count == depth && filtered.favorite_count == 1 && filtered.favorite_indices[0] == depth,
            "leaf query returns its ancestors and favorite");
    for (size_t index = 0; index < depth; ++index) {
        require(filtered.file_indices[index] == index + 1, "deep query keeps tree order");
    }
}

void fuzz_documents() {
    constexpr std::array seeds{
        std::string_view{"# Heading\n\n*emphasis* with ~~strike~~ and `code`."},
        std::string_view{"| A | B |\n|---|---|\n| **x** | &amp; |\n\nFinal"},
        std::string_view{"> a\n> > nested\n\n- [x] first\n  - second"},
        std::string_view{"[see][ref] and ![alt](photo.png)\n\n[ref]: https://example.test"},
        std::string_view{"```md\n# literal\n```\n\n&#x1F600; \xE9\x9B\xAA"}
    };
    constexpr std::array fragments{
        std::string_view{"*"}, std::string_view{"_"}, std::string_view{"~"}, std::string_view{"`"},
        std::string_view{"("}, std::string_view{"]"}, std::string_view{"!["}, std::string_view{"|"},
        std::string_view{"\r\n"}, std::string_view{"\0", 1}, std::string_view{"\xC2\xA0"},
        std::string_view{"\xF0\x9F\x98\x80"}, std::string_view{"\\*"}, std::string_view{"&#x80;"}
    };

    std::mt19937 generator(0x17D0C);
    for (size_t iteration = 0; iteration < 4096; ++iteration) {
        std::string input(seeds[generator() % seeds.size()]);
        const auto edits = 1 + generator() % 32;
        for (size_t edit = 0; edit < edits; ++edit) {
            auto offset = generator() % (input.size() + 1);
            while (offset < input.size() && (static_cast<unsigned char>(input[offset]) & 0xC0) == 0x80) {
                ++offset;
            }
            if (offset < input.size() && generator() % 3 == 0) {
                auto end = offset + 1;
                while (end < input.size() && (static_cast<unsigned char>(input[end]) & 0xC0) == 0x80) {
                    ++end;
                }
                input.erase(offset, end - offset);
            } else {
                input.insert(offset, fragments[generator() % fragments.size()]);
            }
        }
        const auto valid = parse(input);
        check_document_views(valid.get());
        input.insert(generator() % (input.size() + 1), 1, '\xFF');
        parse(input, invalid);
    }
}

void fuzz_projects() {
    std::mt19937 generator(0x17CAA);
    for (size_t iteration = 0; iteration < 4096; ++iteration) {
        constexpr MarkyProjectEntryMetadata directory{{}, MARKY_PROJECT_ENTRY_DIRECTORY, 0, 0};
        const std::string name = std::to_string(generator()) + "-\xE9\x9B\xAA.md";
        std::array entries{root, MarkyProjectTreeEntry{view("folder"), view("Folder"), 0, directory},
                           MarkyProjectTreeEntry{view("doc"), view(name), 1, markdown}};
        const auto mutation = generator() % 8;
        const auto original = entries;
        MarkyStatus expected = invalid;
        switch (mutation) {
        case 0:
            entries[2].parent_index = 2 + generator() % 256;
            break;
        case 1:
            entries[2].identity = entries[1].identity;
            break;
        case 2:
            entries[2].metadata.kind = MARKY_PROJECT_ENTRY_UNKNOWN;
            expected = MARKY_STATUS_PROJECT_SCAN_UNKNOWN;
            break;
        case 3:
            entries[2].name = {nullptr, 1};
            break;
        case 4:
            entries[2].metadata.kind = MARKY_PROJECT_ENTRY_PICKED_FILE;
            break;
        case 5:
            entries[2].metadata.name_extension = view("\xF0");
            break;
        default:
            entries[2].metadata.is_hidden = mutation == 6;
            expected = MARKY_STATUS_OK;
            break;
        }
        const auto tree = build_tree(entries.data(), entries.size(), expected);
        if (tree) {
            const bool retained = mutation == 7;
            require(marky_project_tree_node_count(tree.get()) == (retained ? original.size() : 1),
                    "hidden leaves and their empty folders are pruned");
            const std::array path{original[1].name, original[2].name};
            size_t index = 99;
            const auto status = marky_project_tree_find_path(tree.get(), path.data(), path.size(), &index);
            require(retained ? (status == MARKY_STATUS_OK && index == 2)
                             : (status == MARKY_STATUS_PROJECT_NODE_NOT_FOUND && index == 99),
                    "project path lookup agrees with retained entries");
            if (retained) {
                const auto name_matches = static_cast<uint8_t>(generator() % 2);
                const auto path_matches = static_cast<uint8_t>(generator() % 2);
                const std::array<uint8_t, 3> matches{0, 0, name_matches};
                const MarkyProjectFavoriteMatch favorite{index, path_matches};
                MarkyProjectQueryResult* raw = nullptr;
                const auto filtered = marky_project_tree_filter(
                    tree.get(), {matches.data(), matches.size(), &favorite, 1}, nullptr, &raw);
                const QueryResult query(raw, marky_project_query_result_release);
                require(filtered == MARKY_STATUS_OK && raw, "generated project query succeeds");
                const auto result = marky_project_query_result_view(raw);
                require(result.file_count == (name_matches ? 2 : 0) &&
                            result.favorite_count == (name_matches || path_matches ? 1 : 0),
                        "relative-path favorite matches are independent of the file tree's name matches");
            }
        }

        const auto path = view(name);
        const auto alias = view("other.md");
        const bool authorized = generator() % 2 != 0;
        const bool remove = generator() % 2 != 0;
        MarkyProjectFavoriteResult* raw = nullptr;
        const auto status = marky_project_reconcile_favorites(
            {{&path, 1}, {&alias, 1}, {&path, 1},
             remove ? complete : MARKY_PROJECT_SCAN_PARTIAL, static_cast<uint8_t>(authorized)}, nullptr, &raw);
        const Favorites result(raw, marky_project_favorite_result_release);
        require(status == MARKY_STATUS_OK && raw, "generated favorite reconciliation succeeds");
        require(marky_project_favorite_result_count(raw) == size_t(!remove) + size_t(authorized) &&
                    marky_project_favorite_result_migrates_alias(raw) == authorized,
                "reconciliation honors removal and alias authorization");
        if (!remove) {
            require(text(marky_project_favorite_result_path(raw, 0)) == name,
                    "kept favorite retains its UTF-8 spelling");
        }
        if (authorized) {
            require(text(marky_project_favorite_result_path(raw, !remove)) == "other.md",
                    "authorized alias favorite is kept");
        }
    }
}

} // namespace

int main() {
    check_malformed_and_misuse();
    check_document_stress();
    check_project_stress();
    std::cerr << "Document mutation seed 0x17D0C\n";
    fuzz_documents();
    std::cerr << "Project mutation seed 0x17CAA\n";
    fuzz_projects();
    return EXIT_SUCCESS;
}
