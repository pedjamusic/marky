#ifndef MARKY_LITERAL_SYNTAX_H
#define MARKY_LITERAL_SYNTAX_H

#include "ListCharacterProperties.h"

#include <algorithm>
#include <optional>
#include <string_view>
#include <unordered_map>
#include <vector>

namespace marky {

inline std::size_t delimiter_run_length(std::string_view text, char delimiter) noexcept {
    const auto end = text.find_first_not_of(delimiter);
    return end == std::string_view::npos ? text.size() : end;
}

inline std::size_t backtick_run_length(std::string_view text) noexcept {
    const auto length = delimiter_run_length(text, '`');
    // A backtick with a combining suffix is a different character in Swift.
    return length != 0 && grapheme_suffix_width(text.substr(length)) != 0 ? length - 1 : length;
}

inline std::size_t next_backtick_run(std::string_view text, std::size_t& cursor) noexcept {
    while ((cursor = text.find('`', cursor)) != std::string_view::npos) {
        if (const auto length = backtick_run_length(text.substr(cursor))) {
            return length;
        }
        ++cursor;
    }
    return 0;
}

// The caller identifies an opening run and handles escapes outside code spans.
// Return the byte offset just after the matching complete run, or npos.
inline std::size_t code_span_end(std::string_view text, std::size_t opening,
                                 std::size_t opening_length) noexcept {
    for (auto cursor = opening + opening_length; const auto length = next_backtick_run(text, cursor);
         cursor += length) {
        if (length == opening_length) {
            return cursor + length;
        }
    }
    return std::string_view::npos;
}

// Callers visit potential openings from left to right. Successful matches
// advance past the bytes they scanned. After a miss, index the remaining
// runs on demand so later misses cannot rescan the same suffix repeatedly.
class CodeSpanMatcher {
public:
    explicit CodeSpanMatcher(std::string_view text) : text(text) {}

    std::size_t end(std::size_t opening, std::size_t length) {
        if (!saw_unmatched) {
            const auto result = code_span_end(text, opening, length);
            saw_unmatched = result == std::string_view::npos;
            return result;
        }
        const auto search_start = opening + length;
        if (!closers) {
            closers.emplace();
            for (auto cursor = search_start; const auto run = next_backtick_run(text, cursor); cursor += run) {
                (*closers)[run].push_back(cursor);
            }
        }
        const auto runs = closers->find(length);
        if (runs == closers->end()) {
            return std::string_view::npos;
        }
        const auto& positions = runs->second;
        const auto closing = std::lower_bound(positions.begin(), positions.end(), search_start);
        return closing == positions.end() ? std::string_view::npos : *closing + length;
    }

private:
    std::string_view text;
    bool saw_unmatched = false;
    std::optional<std::unordered_map<std::size_t, std::vector<std::size_t>>> closers;
};

}

#endif
