#include "MarkyCore.h"
#include "CancellationToken.h"
#include "Utf8.h"

#include <array>
#include <memory>
#include <new>
#include <set>
#include <string>
#include <string_view>
#include <vector>

struct MarkyProjectFavoriteResult {
    bool migrate_alias = false;
    std::vector<std::string> paths;
};

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

MarkyProjectFavoriteDisposition marky_project_favorite_membership(
    MarkyProjectScanState scan_state, MarkyProjectFavoriteAvailability availability) {
    if (scan_state != MARKY_PROJECT_SCAN_COMPLETE && scan_state != MARKY_PROJECT_SCAN_PARTIAL) {
        return MARKY_PROJECT_FAVORITE_RETAIN_HIDDEN;
    }
    switch (availability) {
    case MARKY_PROJECT_FAVORITE_INDEXED_DOCUMENT:
        return MARKY_PROJECT_FAVORITE_RETAIN_VISIBLE;
    case MARKY_PROJECT_FAVORITE_AUTHORIZED_MISSING:
        return scan_state == MARKY_PROJECT_SCAN_COMPLETE ? MARKY_PROJECT_FAVORITE_PRUNE
                                                        : MARKY_PROJECT_FAVORITE_RETAIN_HIDDEN;
    default:
        return MARKY_PROJECT_FAVORITE_RETAIN_HIDDEN;
    }
}

MarkyStatus marky_project_reconcile_favorites(MarkyProjectFavoriteReconciliation input,
                                             const MarkyCancellationToken* token,
                                             MarkyProjectFavoriteResult** out_result) try {
    if (out_result == nullptr) {
        return MARKY_STATUS_INVALID_ARGUMENT;
    }
    *out_result = nullptr;
    if (marky::cancellation_requested(token)) {
        return MARKY_STATUS_CANCELLED;
    }

    const bool prune = marky_project_favorite_membership(input.scan_state, MARKY_PROJECT_FAVORITE_AUTHORIZED_MISSING)
        == MARKY_PROJECT_FAVORITE_PRUNE;
    const bool migrate_alias = input.alias_is_authorized != 0;
    std::set<std::string_view> saved_paths;
    struct PathUpdate {
        MarkyProjectFavoritePaths list;
        bool remove;
    };
    constexpr MarkyProjectFavoritePaths empty{};
    const PathUpdate updates[] = {
        {input.latest_canonical, false},
        {migrate_alias ? input.latest_alias : empty, false},
        {prune ? input.confirmed_missing : empty, true}
    };
    for (const auto& update : updates) {
        const auto [paths, count] = update.list;
        if (paths == nullptr && count != 0) {
            return MARKY_STATUS_INVALID_ARGUMENT;
        }
        for (size_t index = 0; index < count; ++index) {
            if (marky::cancellation_requested(token)) {
                return MARKY_STATUS_CANCELLED;
            }
            const auto [data, byte_count] = paths[index];
            if (data == nullptr && byte_count != 0) {
                return MARKY_STATUS_INVALID_ARGUMENT;
            }
            const auto path = byte_count == 0 ? std::string_view{} : std::string_view(data, byte_count);
            if (update.remove) {
                saved_paths.erase(path);
            } else {
                saved_paths.insert(path);
            }
        }
    }

    auto result = std::make_unique<MarkyProjectFavoriteResult>();
    result->migrate_alias = migrate_alias;
    result->paths.reserve(saved_paths.size());
    for (const auto path : saved_paths) {
        if (marky::cancellation_requested(token)) {
            return MARKY_STATUS_CANCELLED;
        }
        result->paths.emplace_back(path);
    }
    if (marky::cancellation_requested(token)) {
        return MARKY_STATUS_CANCELLED;
    }
    *out_result = result.release();
    return MARKY_STATUS_OK;
} catch (const std::bad_alloc&) {
    return MARKY_STATUS_ALLOCATION_FAILURE;
} catch (...) {
    return MARKY_STATUS_INTERNAL_ERROR;
}

size_t marky_project_favorite_result_count(const MarkyProjectFavoriteResult* result) {
    return result == nullptr ? 0 : result->paths.size();
}

uint8_t marky_project_favorite_result_migrates_alias(const MarkyProjectFavoriteResult* result) {
    return result != nullptr && result->migrate_alias;
}

MarkyUtf8View marky_project_favorite_result_path(const MarkyProjectFavoriteResult* result, size_t index) {
    if (result == nullptr || index >= result->paths.size()) {
        return {};
    }
    const auto& path = result->paths[index];
    return {path.data(), path.size()};
}

void marky_project_favorite_result_release(MarkyProjectFavoriteResult* result) {
    delete result;
}
