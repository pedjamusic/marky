#include "MarkyCore.h"
#include "Utf8.h"

#include <array>
#include <string_view>

namespace {

bool is_markdown_extension(MarkyUtf8View extension) {
    if (extension.data == nullptr || extension.byte_count == 0) {
        return false;
    }

    constexpr std::string_view longest_extension = "markdown";
    std::array<char, longest_extension.size()> lowercase;
    std::string_view source(extension.data, extension.byte_count);
    size_t length = 0;
    while (!source.empty() && length < lowercase.size()) {
        auto scalar = marky::read_utf8_scalar(source);
        if (scalar == 0x212A) {
            // The Kelvin sign lowercases to ASCII k, matching the native scanner.
            scalar = 'k';
        } else if (scalar >= 'A' && scalar <= 'Z') {
            scalar += 'a' - 'A';
        }
        if (scalar < 'a' || scalar > 'z') {
            return false;
        }
        lowercase[length++] = static_cast<char>(scalar);
    }
    if (!source.empty()) {
        return false;
    }

    const std::string_view value(lowercase.data(), length);
    return value == "md" || value == longest_extension || value == "mdown" || value == "mkd";
}

}

MarkyProjectEntryDisposition marky_project_classify_entry(MarkyProjectEntryMetadata entry) {
    if (entry.is_hidden) {
        return MARKY_PROJECT_ENTRY_SKIP;
    }
    switch (entry.kind) {
    case MARKY_PROJECT_ENTRY_DIRECTORY:
        return MARKY_PROJECT_ENTRY_SCAN_DIRECTORY;
    case MARKY_PROJECT_ENTRY_REGULAR_FILE:
        return is_markdown_extension(entry.name_extension) ? MARKY_PROJECT_ENTRY_DOCUMENT
                                                            : MARKY_PROJECT_ENTRY_SKIP;
    case MARKY_PROJECT_ENTRY_SYMLINK:
        if (!is_markdown_extension(entry.name_extension)) {
            return MARKY_PROJECT_ENTRY_SKIP;
        }
        switch (entry.target_kind) {
        case MARKY_PROJECT_ENTRY_UNKNOWN:
            return MARKY_PROJECT_ENTRY_NEEDS_TARGET_METADATA;
        case MARKY_PROJECT_ENTRY_REGULAR_FILE:
            return MARKY_PROJECT_ENTRY_DOCUMENT;
        default:
            return MARKY_PROJECT_ENTRY_SKIP;
        }
    default:
        return MARKY_PROJECT_ENTRY_SKIP;
    }
}
