#ifndef MARKY_UTF8_H
#define MARKY_UTF8_H

#include <cstddef>
#include <cstdint>
#include <string_view>

namespace marky {

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
