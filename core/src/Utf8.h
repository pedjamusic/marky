#ifndef MARKY_UTF8_H
#define MARKY_UTF8_H

#include <cstddef>
#include <cstdint>
#include <string_view>

namespace marky {

inline bool is_valid_utf8(const char* data, std::size_t size) noexcept {
    if (data == nullptr) {
        return size == 0;
    }
    for (std::size_t index = 0; index < size;) {
        const auto lead = static_cast<unsigned char>(data[index++]);
        if (lead <= 0x7F) {
            continue;
        }
        if (lead < 0xC2 || lead > 0xF4) {
            return false;
        }
        const std::size_t trailing = lead < 0xE0 ? 1 : (lead < 0xF0 ? 2 : 3);
        if (trailing > size - index) {
            return false;
        }
        const auto second = static_cast<unsigned char>(data[index]);
        // Reject overlong forms, surrogate code points, and values above U+10FFFF.
        if ((lead == 0xE0 && second < 0xA0) || (lead == 0xED && second > 0x9F) ||
            (lead == 0xF0 && second < 0x90) || (lead == 0xF4 && second > 0x8F)) {
            return false;
        }
        for (std::size_t offset = 0; offset < trailing; ++offset) {
            const auto byte = static_cast<unsigned char>(data[index++]);
            if (byte < 0x80 || byte > 0xBF) {
                return false;
            }
        }
    }
    return true;
}

// The view begins at a scalar in nonempty, validated UTF-8.
inline std::uint32_t read_utf8_scalar(std::string_view& source) {
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

}

#endif
