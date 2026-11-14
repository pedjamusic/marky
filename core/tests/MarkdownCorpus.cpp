#include "MarkyCore.h"

#include <array>
#include <cstdlib>
#include <fstream>
#include <iostream>
#include <iterator>
#include <memory>
#include <string>
#include <string_view>
#include <vector>

namespace {

std::string_view bytes(MarkyUtf8View view) {
    return view.data ? std::string_view(view.data, view.byte_count) : std::string_view{};
}

void require(bool condition) {
    if (!condition) {
        std::cerr << "Invalid document accessor result or source range\n";
        std::exit(1);
    }
}

void json_string(std::string_view text) {
    constexpr char hex[] = "0123456789abcdef";
    std::cout << '"';
    for (const unsigned char byte : text) {
        if (byte < 0x20) {
            std::cout << "\\u00" << hex[byte >> 4] << hex[byte & 15];
        } else {
            if (byte == '"' || byte == '\\') {
                std::cout << '\\';
            }
            std::cout << static_cast<char>(byte);
        }
    }
    std::cout << '"';
}

void optional_field(std::string_view key, MarkyUtf8View view) {
    if (view.data) {
        std::cout << ",\"" << key << "\":";
        json_string(bytes(view));
    }
}

template<class Emit>
void array(size_t count, const Emit& emit) {
    std::cout << '[';
    for (size_t index = 0; index < count; ++index) {
        if (index > 0) {
            std::cout << ',';
        }
        emit(index);
    }
    std::cout << ']';
}

struct Run {
    std::string text;
    MarkyInlineFlags traits;
    MarkyUtf8View destination;
};

using Line = std::vector<Run>;

void append(Line& line, std::string_view text, const MarkyInlineRunView& run) {
    if (text.empty()) {
        return;
    }
    constexpr MarkyInlineFlags visible_traits =
        MARKY_INLINE_STRONG | MARKY_INLINE_EMPHASIS | MARKY_INLINE_STRIKETHROUGH | MARKY_INLINE_CODE;
    const auto traits = run.flags & visible_traits;
    const auto destination = run.link_destination;
    if (!line.empty() && line.back().traits == traits &&
        (line.back().destination.data == nullptr) == (destination.data == nullptr) &&
        bytes(line.back().destination) == bytes(destination)) {
        line.back().text.append(text);
    } else {
        line.push_back({std::string(text), traits, destination});
    }
}

std::vector<Line> read_region(const MarkyDocument* document, MarkyInlineLocation location,
                              std::string_view source, bool split_lines = false) {
    std::vector<Line> lines(1);
    size_t previous_end = 0;
    const auto count = marky_document_inline_run_count(document, location);
    for (size_t index = 0; index < count; ++index) {
        MarkyInlineRunView run{};
        require(marky_document_inline_run_at(document, location, index, &run) == MARKY_STATUS_OK);
        require(run.source_begin >= previous_end && run.source_end > run.source_begin &&
                run.source_end <= source.size());
        previous_end = run.source_end;
        auto text = bytes(run.text);
        if (split_lines) {
            for (auto lf = text.find('\n'); lf != text.npos; lf = text.find('\n')) {
                append(lines.back(), text.substr(0, lf), run);
                lines.emplace_back();
                text.remove_prefix(lf + 1);
            }
        }
        append(lines.back(), text, run);
    }
    return lines;
}

void emit_runs(const Line& line) {
    array(line.size(), [&](size_t index) {
        const auto& run = line[index];
        std::cout << "{\"text\":";
        json_string(run.text);
        std::cout << ",\"traits\":[";
        constexpr std::array names{"strong", "emphasis", "strike", "code"};
        constexpr std::array flags{MARKY_INLINE_STRONG, MARKY_INLINE_EMPHASIS,
                                   MARKY_INLINE_STRIKETHROUGH, MARKY_INLINE_CODE};
        bool comma = false;
        for (size_t trait = 0; trait < names.size(); ++trait) {
            if (run.traits & flags[trait]) {
                if (comma) {
                    std::cout << ',';
                }
                json_string(names[trait]);
                comma = true;
            }
        }
        std::cout << ']';
        optional_field("destination", run.destination);
        std::cout << '}';
    });
}

void emit_block(const MarkyDocument* document, size_t index) {
    MarkyBlockKind kind{};
    MarkyUtf8View text{};
    require(marky_document_block_at(document, index, &kind, &text) == MARKY_STATUS_OK);
    constexpr std::array names{"", "paragraph", "code", "heading", "thematicBreak", "list", "quote", "table", "image"};
    require(kind > MARKY_BLOCK_INVALID && kind < names.size());
    std::cout << "{\"kind\":";
    json_string(names[kind]);

    switch (kind) {
    case MARKY_BLOCK_HEADING: {
        uint32_t level{};
        require(marky_document_heading_level_at(document, index, &level) == MARKY_STATUS_OK);
        std::cout << ",\"level\":" << level;
        [[fallthrough]];
    }
    case MARKY_BLOCK_PARAGRAPH:
        std::cout << ",\"runs\":";
        emit_runs(read_region(document, {index, 0, 0}, bytes(text)).front());
        break;
    case MARKY_BLOCK_CODE:
        optional_field("text", text);
        break;
    case MARKY_BLOCK_IMAGE: {
        MarkyImageView image{};
        require(marky_document_image_at(document, index, &image) == MARKY_STATUS_OK);
        optional_field("alt", image.alt);
        optional_field("destination", image.destination);
        optional_field("title", image.title);
        break;
    }
    case MARKY_BLOCK_LIST:
        std::cout << ",\"items\":";
        array(marky_document_list_item_count(document, index), [&](size_t row) {
            MarkyListItemView item{};
            require(marky_document_list_item_at(document, index, row, &item) == MARKY_STATUS_OK);
            constexpr std::array markers{"", "bullet", "", "taskUnchecked", "taskChecked"};
            require(item.marker_kind > MARKY_LIST_MARKER_INVALID && item.marker_kind < markers.size());
            std::cout << "{\"depth\":" << item.depth << ",\"marker\":";
            json_string(item.marker_kind == MARKY_LIST_MARKER_ORDERED ? bytes(item.ordered_marker) :
                        std::string_view(markers[item.marker_kind]));
            std::cout << ",\"runs\":";
            emit_runs(read_region(document, {index, row, 0}, bytes(item.source)).front());
            std::cout << '}';
        });
        break;
    case MARKY_BLOCK_QUOTE: {
        std::vector<size_t> depths;
        std::string source;
        const auto count = marky_document_quote_line_count(document, index);
        for (size_t row = 0; row < count; ++row) {
            MarkyQuoteLineView line{};
            require(marky_document_quote_line_at(document, index, row, &line) == MARKY_STATUS_OK);
            if (row > 0) {
                source += '\n';
            }
            source.append(bytes(line.source));
            depths.push_back(line.depth);
        }
        const auto lines = read_region(document, {index, 0, 0}, source, true);
        require(lines.size() == depths.size());
        std::cout << ",\"lines\":";
        array(lines.size(), [&](size_t row) {
            std::cout << "{\"depth\":" << depths[row] << ",\"runs\":";
            emit_runs(lines[row]);
            std::cout << '}';
        });
        break;
    }
    case MARKY_BLOCK_TABLE: {
        const auto columns = marky_document_table_column_count(document, index);
        std::vector<MarkyTableColumnView> headers(columns);
        std::cout << ",\"headers\":";
        array(columns, [&](size_t column) {
            auto& header = headers[column];
            require(marky_document_table_column_at(document, index, column, &header) == MARKY_STATUS_OK);
            emit_runs(read_region(document, {index, 0, column}, bytes(header.header)).front());
        });
        std::cout << ",\"alignments\":";
        array(columns, [&](size_t column) {
            constexpr std::array alignments{"", "left", "center", "right"};
            const auto alignment = headers[column].alignment;
            require(alignment > MARKY_TABLE_ALIGNMENT_INVALID && alignment < alignments.size());
            json_string(alignments[alignment]);
        });
        std::cout << ",\"rows\":";
        array(marky_document_table_row_count(document, index), [&](size_t row) {
            array(columns, [&](size_t column) {
                MarkyUtf8View cell{};
                require(marky_document_table_cell_at(document, index, row, column, &cell) == MARKY_STATUS_OK);
                emit_runs(read_region(document, {index, row + 1, column}, bytes(cell)).front());
            });
        });
        break;
    }
    }
    std::cout << '}';
}

}

int main(int argc, char* argv[]) {
    require(argc == 2);
    // Binary mode preserves CRLF and UTF-8 on Windows.
    std::ifstream input(argv[1], std::ios::binary);
    require(input.is_open());
    const std::string source(std::istreambuf_iterator<char>(input), {});
    MarkyDocument* raw = nullptr;
    require(marky_document_create(source.data(), source.size(), &raw) == MARKY_STATUS_OK && raw);
    const std::unique_ptr<MarkyDocument, decltype(&marky_document_release)> document(raw, marky_document_release);
    array(marky_document_block_count(raw), [&](size_t index) { emit_block(raw, index); });
    std::cout << '\n';
}
