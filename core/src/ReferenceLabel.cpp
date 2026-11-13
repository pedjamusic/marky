#include "ReferenceLabel.h"

#include "generated/UnicodeData.h"

#include <algorithm>
#include <cstdint>
#include <iterator>
#include <tuple>
#include <utility>
#include <vector>

namespace marky {
namespace {

std::uint32_t read_scalar(std::string_view& source) {
    const auto lead = static_cast<unsigned char>(source.front());
    if (lead <= 0x7F) {
        source.remove_prefix(1);
        return lead;
    }
    const std::size_t width = lead < 0xE0 ? 2 : (lead < 0xF0 ? 3 : 4);
    std::uint32_t scalar = lead & (0x7F >> width);
    for (std::size_t offset = 1; offset < width; ++offset) {
        scalar = (scalar << 6) | (static_cast<unsigned char>(source[offset]) & 0x3F);
    }
    source.remove_prefix(width);
    return scalar;
}

void append_utf8(std::string& output, std::uint32_t scalar) {
    if (scalar <= 0x7F) {
        output.push_back(static_cast<char>(scalar));
        return;
    }
    const auto append_continuation = [&](unsigned shift) {
        output.push_back(static_cast<char>(0x80 | ((scalar >> shift) & 0x3F)));
    };
    if (scalar <= 0x7FF) {
        output.push_back(static_cast<char>(0xC0 | (scalar >> 6)));
    } else {
        if (scalar <= 0xFFFF) {
            output.push_back(static_cast<char>(0xE0 | (scalar >> 12)));
        } else {
            output.push_back(static_cast<char>(0xF0 | (scalar >> 18)));
            append_continuation(12);
        }
        append_continuation(6);
    }
    append_continuation(0);
}

template <typename Entry, std::size_t size>
const Entry* find_scalar(const Entry (&entries)[size], std::uint32_t scalar) {
    const auto entry = std::ranges::lower_bound(entries, scalar, {}, &Entry::scalar);
    return entry != std::end(entries) && entry->scalar == scalar ? entry : nullptr;
}

bool is_label_whitespace(std::uint32_t scalar) {
    if (scalar <= 0x7F) {
        return scalar == ' ' || (scalar >= '\t' && scalar <= '\r');
    }
    constexpr auto& ranges = unicode_data::whitespace_ranges;
    const auto range = std::ranges::lower_bound(ranges, scalar, {}, &unicode_data::ScalarRange::last);
    return range != std::end(ranges) && range->first <= scalar;
}

struct CombiningMark {
    std::uint32_t scalar;
    std::uint8_t combining_class;
    std::size_t input_order;
};

class CanonicalLabel {
public:
    explicit CanonicalLabel(std::size_t source_size) { output.reserve(source_size); }

    void append(std::uint32_t scalar) {
        // Hangul decomposes into two or three Jamo with combining class zero.
        constexpr std::uint32_t hangul_base = 0xAC00;
        constexpr std::uint32_t leading_base = 0x1100;
        constexpr std::uint32_t vowel_base = 0x1161;
        constexpr std::uint32_t trailing_base = 0x11A7;
        constexpr std::uint32_t trailing_count = 28;
        constexpr std::uint32_t vowel_trailing_count = 21 * trailing_count;
        constexpr std::uint32_t syllable_count = 19 * vowel_trailing_count;
        if (scalar >= hangul_base && scalar < hangul_base + syllable_count) {
            const auto syllable = scalar - hangul_base;
            flush_marks();
            append_utf8(output, leading_base + syllable / vowel_trailing_count);
            append_utf8(output, vowel_base + (syllable % vowel_trailing_count) / trailing_count);
            if (const auto trailing = syllable % trailing_count) {
                append_utf8(output, trailing_base + trailing);
            }
        } else if (const auto mapping = find_scalar(unicode_data::canonical_decompositions, scalar)) {
            for (std::size_t offset = 0; offset < mapping->length; ++offset) {
                append_decomposed(mapping->values[offset]);
            }
        } else {
            append_decomposed(scalar);
        }
    }

    void append_ascii(char byte) {
        flush_marks();
        output.push_back(byte);
    }

    std::string finish() {
        flush_marks();
        return std::move(output);
    }

private:
    void append_decomposed(std::uint32_t scalar) {
        if (const auto combining = find_scalar(unicode_data::combining_classes, scalar)) {
            marks.push_back({scalar, combining->value, marks.size()});
        } else {
            flush_marks();
            append_utf8(output, scalar);
        }
    }

    void flush_marks() {
        if (marks.empty()) {
            return;
        }
        // Marks with equal combining classes retain their input order.
        std::ranges::sort(marks, {}, [](const CombiningMark& mark) {
            return std::tie(mark.combining_class, mark.input_order);
        });
        for (const auto& mark : marks) {
            append_utf8(output, mark.scalar);
        }
        marks.clear();
    }

    std::string output;
    std::vector<CombiningMark> marks;
};

}

std::string normalize_reference_label(std::string_view source) {
    CanonicalLabel label(source.size());
    bool has_content = false;
    bool pending_space = false;
    while (!source.empty()) {
        const auto scalar = read_scalar(source);
        if (is_label_whitespace(scalar)) {
            pending_space = has_content;
            continue;
        }
        if (pending_space) {
            label.append_ascii(' ');
            pending_space = false;
        }
        has_content = true;
        if (scalar <= 0x7F) {
            const auto lowered = scalar >= 'A' && scalar <= 'Z' ? scalar + ('a' - 'A') : scalar;
            label.append_ascii(static_cast<char>(lowered));
        } else if (const auto mapping = find_scalar(unicode_data::lowercase_mappings, scalar)) {
            for (std::size_t offset = 0; offset < mapping->length; ++offset) {
                label.append(mapping->values[offset]);
            }
        } else {
            label.append(scalar);
        }
    }
    return label.finish();
}

}
