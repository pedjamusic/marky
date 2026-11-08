#ifndef MARKY_LITERAL_SYNTAX_H
#define MARKY_LITERAL_SYNTAX_H

#include <string_view>

namespace marky {

inline std::size_t delimiter_run_length(std::string_view text, char delimiter) noexcept {
    const auto end = text.find_first_not_of(delimiter);
    return end == std::string_view::npos ? text.size() : end;
}

// The caller identifies an opening run and handles escapes outside code spans.
// Return the byte offset just after the matching complete run, or npos.
inline std::size_t code_span_end(std::string_view text, std::size_t opening,
                                 std::size_t opening_length) noexcept {
    auto cursor = opening + opening_length;
    while ((cursor = text.find('`', cursor)) != std::string_view::npos) {
        const auto length = delimiter_run_length(text.substr(cursor), '`');
        cursor += length;
        if (length == opening_length) {
            return cursor;
        }
    }
    return std::string_view::npos;
}

}

#endif
