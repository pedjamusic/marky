#include "MarkyCore.h"
#include "ListCharacterProperties.h"
#include "LiteralSyntax.h"

#ifdef MARKY_CORE_TEST_CHECKPOINTS
#include "DocumentTestCheckpoints.h"
#endif

#include <algorithm>
#include <atomic>
#include <memory>
#include <new>
#include <optional>
#include <string>
#include <string_view>
#include <utility>
#include <variant>
#include <vector>

struct MarkyDocument {
    struct ListItem {
        size_t depth;
        MarkyListMarkerKind marker_kind;
        std::string ordered_marker;
        std::string source;
    };

    using List = std::vector<ListItem>;

    struct Block {
        MarkyBlockKind kind;
        uint32_t heading_level;
        std::variant<std::string, List> content;
    };

    const std::vector<Block> blocks;
#ifdef MARKY_CORE_TEST_CHECKPOINTS
    ~MarkyDocument() { marky::test::document_destroyed(); }
#endif
};

struct MarkyCancellationToken {
    std::atomic<bool> requested{false};
};

namespace {

bool cancellation_requested(const MarkyCancellationToken* token) noexcept {
    // The flag carries no other state. The caller manages token lifetime.
    return token != nullptr && token->requested.load(std::memory_order_relaxed);
}

struct Fence {
    char marker;
    size_t length;
};

// Match Foundation's .whitespaces, including U+200B, without locale dependence.
size_t horizontal_whitespace_width(std::string_view text) {
    if (text.starts_with(' ') || text.starts_with('\t')) {
        return 1;
    }
    if (text.starts_with("\xC2\xA0")) { // U+00A0
        return 2;
    }
    if (text.starts_with("\xE1\x9A\x80") || // U+1680
        text.starts_with("\xE2\x80\xAF") || // U+202F
        text.starts_with("\xE2\x81\x9F") || // U+205F
        text.starts_with("\xE3\x80\x80") || // U+3000
        (text.size() >= 3 && text.starts_with("\xE2\x80") &&
         static_cast<unsigned char>(text[2]) >= 0x80 &&
         static_cast<unsigned char>(text[2]) <= 0x8B)) { // U+2000–U+200B
        return 3;
    }
    return 0;
}

size_t newline_width(std::string_view text) {
    if (!text.empty() && text.front() >= '\n' && text.front() <= '\r') {
        return 1;
    }
    if (text.starts_with("\xC2\x85")) { // U+0085
        return 2;
    }
    if (text.starts_with("\xE2\x80\xA8") || text.starts_with("\xE2\x80\xA9")) { // U+2028–U+2029
        return 3;
    }
    return 0;
}

size_t whitespace_width(std::string_view text, bool include_newlines) {
    const auto horizontal = horizontal_whitespace_width(text);
    return horizontal == 0 && include_newlines ? newline_width(text) : horizontal;
}

bool horizontal_whitespace_only(std::string_view text) {
    while (const auto width = horizontal_whitespace_width(text)) {
        text.remove_prefix(width);
    }
    return text.empty();
}

size_t combining_accent_width(std::string_view text) {
    // Basic Combining Diacritical Marks (U+0300–U+036F) in validated UTF-8.
    const bool has_accent = text.size() >= 2 &&
                            (text.starts_with('\xCC') ||
                             (text.starts_with('\xCD') && static_cast<unsigned char>(text[1]) <= 0xAF));
    return has_accent ? 2 : 0;
}

std::string_view trim_whitespace(std::string_view text, bool include_newlines = false) {
    while (const auto width = whitespace_width(text, include_newlines)) {
        text.remove_prefix(width);
    }
    while (!text.empty()) {
        auto start = text.size() - 1;
        // Caller-validated UTF-8 lets us locate the last scalar by its lead byte.
        while (start > 0 && (static_cast<unsigned char>(text[start]) & 0xC0) == 0x80) {
            --start;
        }
        if (whitespace_width(text.substr(start), include_newlines) == 0) {
            break;
        }
        text.remove_suffix(text.size() - start);
    }
    return text;
}

std::optional<Fence> fence_transition(std::string_view line, std::optional<Fence> open) {
    const auto indent = marky::delimiter_run_length(line, ' ');
    if (indent > 3 || indent == line.size()) {
        return std::nullopt;
    }
    line.remove_prefix(indent);
    const char marker = line.front();
    if (marker != '`' && marker != '~') {
        return std::nullopt;
    }
    const auto length = marky::delimiter_run_length(line, marker);
    const auto suffix = line.substr(length);
    const bool valid = open ? marker == open->marker && length >= open->length &&
                                  horizontal_whitespace_only(suffix)
                            : length >= 3 && (marker != '`' || suffix.find('`') == std::string_view::npos);
    return valid ? std::optional{Fence{marker, length}} : std::nullopt;
}

size_t code_indent(std::string_view line) {
    if (line.starts_with("    ")) {
        return 4;
    }
    return line.starts_with('\t') ? 1 : 0;
}

uint32_t setext_level(std::string_view line) {
    if (line.find_first_not_of('=') == std::string_view::npos) {
        return 1;
    }
    return line.find_first_not_of('-') == std::string_view::npos ? 2 : 0;
}

bool thematic_break(std::string_view line) {
    const char marker = line.front();
    if (marker != '-' && marker != '*' && marker != '_') {
        return false;
    }
    size_t count = 0;
    while (!line.empty()) {
        if (line.front() == marker) {
            ++count;
            line.remove_prefix(1);
        } else {
            // Swift Character.isWhitespace excludes U+200B in the middle of a rule.
            const auto horizontal = horizontal_whitespace_width(line);
            const auto width = horizontal != 0 ? horizontal : newline_width(line);
            if (width == 0 || line.starts_with("\xE2\x80\x8B")) {
                return false;
            }
            const bool accents_attach = horizontal != 0 && !line.starts_with('\t');
            line.remove_prefix(width);
            if (accents_attach) {
                // Swift removes a space and its attached accents as one whitespace character.
                while (const auto accent = combining_accent_width(line)) {
                    line.remove_prefix(accent);
                }
            }
        }
    }
    return count >= 3;
}

size_t list_indent(std::string_view line) {
    const auto first_content = line.find_first_not_of(" \t");
    if (first_content == std::string_view::npos) {
        return line.size();
    }
    // A space with an attached combining mark is not indentation in Swift.
    if (first_content != 0 && line[first_content - 1] == ' ' &&
        marky::list_character_extension_width(line.substr(first_content)) != 0) {
        return first_content - 1;
    }
    return first_content;
}

bool list_separator(std::string_view suffix) {
    return suffix.starts_with(' ') && marky::list_character_extension_width(suffix.substr(1)) == 0;
}

struct ListMarker {
    size_t width;
    MarkyListMarkerKind kind;
    std::string_view source;
};

std::optional<ListMarker> list_marker(std::string_view line) {
    size_t width = 0;
    bool allows_task = false;
    if (line.starts_with('-') || line.starts_with('*') || line.starts_with('+')) {
        width = 1;
        allows_task = true;
    } else if (line.starts_with("\xE2\x80\xA2")) { // U+2022 bullet
        width = 3;
    }
    if (width != 0) {
        if (!list_separator(line.substr(width))) {
            return std::nullopt;
        }
        const auto source = line.substr(width + 1);
        if (allows_task && source.size() >= 4 && list_separator(source.substr(3))) {
            if (source.starts_with("[ ]")) {
                return ListMarker{width, MARKY_LIST_MARKER_TASK_UNCHECKED, source.substr(4)};
            }
            if (source.starts_with("[x]") || source.starts_with("[X]")) {
                return ListMarker{width, MARKY_LIST_MARKER_TASK_CHECKED, source.substr(4)};
            }
        }
        return ListMarker{width, MARKY_LIST_MARKER_BULLET, source};
    }

    auto suffix = line;
    while (const auto number = marky::list_number_width(suffix)) {
        suffix.remove_prefix(number);
        while (const auto extension = marky::list_character_extension_width(suffix)) {
            suffix.remove_prefix(extension);
        }
    }
    if (suffix.size() == line.size() || (!suffix.starts_with('.') && !suffix.starts_with(')')) ||
        !list_separator(suffix.substr(1))) {
        return std::nullopt;
    }
    return ListMarker{line.size() - suffix.size() + 1, MARKY_LIST_MARKER_ORDERED, suffix.substr(2)};
}

std::optional<std::vector<MarkyDocument::Block>> parse_blocks(
    std::string_view source, const MarkyCancellationToken* token) {
    std::vector<MarkyDocument::Block> blocks;
    std::optional<Fence> open;
    std::string text;
    MarkyDocument::List items;
    bool has_literal_line = false;
    bool hard_break = false;
    struct IndentedCode {
        size_t content_end = 0;
        // Swift trims whitespace and newlines at the end of a prose segment,
        // but only horizontal whitespace when trimming indented code itself.
        size_t prose_segment_end = 0;
        bool terminated = false;
    };
    std::optional<IndentedCode> indented;

    const auto flush = [&](MarkyBlockKind kind, uint32_t level = 0) {
        blocks.push_back({kind, level, std::move(text)});
        text.clear();
        has_literal_line = false;
    };

    const auto flush_pending = [&](bool at_prose_segment_end = false) {
        if (indented) {
            text.resize(at_prose_segment_end ? indented->prose_segment_end : indented->content_end);
            flush(MARKY_BLOCK_CODE);
            indented.reset();
        } else if (!items.empty()) {
            blocks.push_back({MARKY_BLOCK_LIST, 0, std::move(items)});
            items.clear();
        } else if (!text.empty()) {
            flush(MARKY_BLOCK_PARAGRAPH);
        }
    };

    const auto append_literal = [&](std::string_view line) {
        if (has_literal_line) {
            text.push_back('\n');
        }
        text.append(line);
        has_literal_line = true;
    };

    const auto append_indented = [&](std::string_view content, bool blank) {
        append_literal(content);
        if (!blank) {
            indented->content_end = text.size();
            indented->prose_segment_end = text.size();
        } else if (!horizontal_whitespace_only(content)) {
            indented->content_end = text.size();
        }
    };

    const auto consume_line = [&](std::string_view line) {
        if (const auto fence = fence_transition(line, open)) {
            if (open) {
                flush(MARKY_BLOCK_CODE);
                open.reset();
            } else {
                flush_pending(true);
                open = fence;
            }
            return;
        }
        if (open) {
            append_literal(line);
            return;
        }

        const auto indent = code_indent(line);
        const auto trimmed = trim_whitespace(line, true);
        if (indented) {
            if (!indented->terminated && indent != 0) {
                append_indented(line.substr(indent), trimmed.empty());
                return;
            }
            if (!indented->terminated && horizontal_whitespace_only(line)) {
                append_literal("");
                return;
            }
            if (trimmed.empty()) {
                // A blank line containing a Unicode newline ends indented code. Wait to
                // see if it also ends the prose segment, which trims more trailing lines.
                indented->terminated = true;
                return;
            }
            flush_pending();
        }

        if (trimmed.empty()) {
            flush_pending();
            return;
        }
        if (text.empty() && items.empty() && indent != 0) {
            indented.emplace();
            append_indented(line.substr(indent), false);
            return;
        }

        if (!text.empty()) {
            if (const auto level = setext_level(trimmed)) {
                // Setext headings join all prepared source lines with spaces.
                std::replace(text.begin(), text.end(), '\n', ' ');
                flush(MARKY_BLOCK_HEADING, level);
                return;
            }
        }
        if (thematic_break(trimmed)) {
            flush_pending();
            flush(MARKY_BLOCK_THEMATIC_BREAK);
            return;
        }

        const auto hashes = marky::delimiter_run_length(trimmed, '#');
        const auto heading_suffix = trimmed.substr(hashes);
        // The opening separator must be a standalone ASCII space.
        if (hashes >= 1 && hashes <= 6 && heading_suffix.starts_with(' ') &&
            combining_accent_width(heading_suffix.substr(1)) == 0) {
            flush_pending();
            auto body = trim_whitespace(heading_suffix);
            const auto last_non_hash = body.find_last_not_of('#');
            if (last_non_hash != std::string_view::npos && body[last_non_hash] == ' ') {
                body = trim_whitespace(body.substr(0, last_non_hash + 1));
            }
            text.assign(body);
            flush(MARKY_BLOCK_HEADING, static_cast<uint32_t>(hashes));
            return;
        }

        const auto leading = list_indent(line);
        const auto content = line.substr(leading);
        const auto marker = list_marker(content);
        const bool continues_list = !items.empty() && leading >= 2;
        // Swift recognizes a list from trimmed lines, then prepares each item
        // from its original line. A bare marker is only read in a continuation.
        if (marker && (trimmed.size() > marker->width || continues_list)) {
            if (items.empty()) {
                flush_pending();
            }
            const auto ordered_marker = marker->kind == MARKY_LIST_MARKER_ORDERED
                                            ? content.substr(0, marker->width) : std::string_view{};
            items.push_back({leading / 2, marker->kind, std::string(ordered_marker),
                             std::string(marker->source)});
            return;
        }
        if (continues_list) {
            items.back().source.push_back('\n');
            items.back().source.append(trim_whitespace(line));
            return;
        }
        if (!items.empty()) {
            flush_pending();
        }

        if (!text.empty()) {
            text.push_back(hard_break ? '\n' : ' ');
        }
        text.append(trim_whitespace(line));
        hard_break = line.ends_with("  ") || line.ends_with('\\');
    };

    for (;;) {
        if (cancellation_requested(token)) {
            return std::nullopt;
        }
        const auto newline = source.find('\n');
        auto line = source.substr(0, newline);
        if (newline != std::string_view::npos && line.ends_with('\r')) {
            line.remove_suffix(1);
        }
        consume_line(line);
#ifdef MARKY_CORE_TEST_CHECKPOINTS
        marky::test::checkpoint(marky::test::Checkpoint::afterBlockLine);
#endif

        if (newline == std::string_view::npos) {
            break;
        }
        source.remove_prefix(newline + 1);
    }
    if (open) {
        flush(MARKY_BLOCK_CODE);
    } else {
        flush_pending(true);
    }
    return blocks;
}

const MarkyDocument::List* list_at(const MarkyDocument* document, size_t block_index) {
    if (block_index >= marky_document_block_count(document)) {
        return nullptr;
    }
    return std::get_if<MarkyDocument::List>(&document->blocks[block_index].content);
}

}

MarkyStatus marky_document_create(const char* utf8, size_t byte_count,
                                  MarkyDocument** out_document) {
    return marky_document_create_cancellable(utf8, byte_count, nullptr, out_document);
}

MarkyStatus marky_cancellation_token_create(MarkyCancellationToken** out_token) try {
    if (out_token == nullptr) {
        return MARKY_STATUS_INVALID_ARGUMENT;
    }
    *out_token = nullptr;
#ifdef MARKY_CORE_TEST_CHECKPOINTS
    marky::test::checkpoint(marky::test::Checkpoint::beforeTokenAllocation);
#endif
    *out_token = new MarkyCancellationToken;
    return MARKY_STATUS_OK;
} catch (const std::bad_alloc&) {
    return MARKY_STATUS_ALLOCATION_FAILURE;
} catch (...) {
    return MARKY_STATUS_INTERNAL_ERROR;
}

void marky_cancellation_token_request(MarkyCancellationToken* token) {
    if (token != nullptr) {
        token->requested.store(true, std::memory_order_relaxed);
    }
}

void marky_cancellation_token_release(MarkyCancellationToken* token) {
    delete token;
}

MarkyStatus marky_document_create_cancellable(const char* utf8, size_t byte_count,
                                              const MarkyCancellationToken* token,
                                              MarkyDocument** out_document) try {
    if (out_document == nullptr) {
        return MARKY_STATUS_INVALID_ARGUMENT;
    }
    *out_document = nullptr;
    if (utf8 == nullptr && byte_count != 0) {
        return MARKY_STATUS_INVALID_ARGUMENT;
    }
    if (cancellation_requested(token)) {
        return MARKY_STATUS_CANCELLED;
    }

    const auto input = byte_count == 0 ? std::string_view("") : std::string_view(utf8, byte_count);
    auto blocks = parse_blocks(input, token);
    if (!blocks) {
        return MARKY_STATUS_CANCELLED;
    }
#ifdef MARKY_CORE_TEST_CHECKPOINTS
    marky::test::checkpoint(marky::test::Checkpoint::beforeDocumentAllocation);
#endif
    if (cancellation_requested(token)) {
        return MARKY_STATUS_CANCELLED;
    }

    auto document = std::make_unique<MarkyDocument>(std::move(*blocks));
#ifdef MARKY_CORE_TEST_CHECKPOINTS
    marky::test::checkpoint(marky::test::Checkpoint::beforeDocumentPublication);
#endif
    if (cancellation_requested(token)) {
        return MARKY_STATUS_CANCELLED;
    }
    *out_document = document.release();
    return MARKY_STATUS_OK;
} catch (const std::bad_alloc&) {
    return MARKY_STATUS_ALLOCATION_FAILURE;
} catch (...) {
    return MARKY_STATUS_INTERNAL_ERROR;
}

size_t marky_document_block_count(const MarkyDocument* document) {
    return document != nullptr ? document->blocks.size() : 0;
}

MarkyStatus marky_document_block_at(const MarkyDocument* document, size_t index,
                                    MarkyBlockKind* out_kind, MarkyUtf8View* out_text) {
    if (out_kind != nullptr) {
        *out_kind = MARKY_BLOCK_INVALID;
    }
    if (out_text != nullptr) {
        *out_text = {};
    }
    if (out_kind == nullptr || out_text == nullptr || index >= marky_document_block_count(document)) {
        return MARKY_STATUS_INVALID_ARGUMENT;
    }

    const auto& block = document->blocks[index];
    *out_kind = block.kind;
    const auto* text = std::get_if<std::string>(&block.content);
    *out_text = text != nullptr ? MarkyUtf8View{text->data(), text->size()} : MarkyUtf8View{"", 0};
    return MARKY_STATUS_OK;
}

MarkyStatus marky_document_paragraph_at(const MarkyDocument* document, size_t index,
                                        MarkyUtf8View* out_text) {
    MarkyBlockKind kind;
    const auto status = marky_document_block_at(document, index, &kind, out_text);
    if (status == MARKY_STATUS_OK && kind != MARKY_BLOCK_PARAGRAPH) {
        *out_text = {};
        return MARKY_STATUS_INVALID_ARGUMENT;
    }
    return status;
}

MarkyStatus marky_document_heading_level_at(const MarkyDocument* document, size_t index,
                                            uint32_t* out_level) {
    if (out_level == nullptr) {
        return MARKY_STATUS_INVALID_ARGUMENT;
    }
    *out_level = 0;
    if (index >= marky_document_block_count(document) ||
        document->blocks[index].kind != MARKY_BLOCK_HEADING) {
        return MARKY_STATUS_INVALID_ARGUMENT;
    }
    *out_level = document->blocks[index].heading_level;
    return MARKY_STATUS_OK;
}

size_t marky_document_list_item_count(const MarkyDocument* document, size_t block_index) {
    const auto* items = list_at(document, block_index);
    return items != nullptr ? items->size() : 0;
}

MarkyStatus marky_document_list_item_at(const MarkyDocument* document, size_t block_index,
                                       size_t item_index, MarkyListItemView* out_item) {
    if (out_item == nullptr) {
        return MARKY_STATUS_INVALID_ARGUMENT;
    }
    *out_item = {};
    const auto* items = list_at(document, block_index);
    if (items == nullptr || item_index >= items->size()) {
        return MARKY_STATUS_INVALID_ARGUMENT;
    }

    const auto& item = (*items)[item_index];
    *out_item = {
        item.depth, item.marker_kind,
        {item.ordered_marker.data(), item.ordered_marker.size()},
        {item.source.data(), item.source.size()}
    };
    return MARKY_STATUS_OK;
}

void marky_document_release(MarkyDocument* document) {
    delete document;
}
