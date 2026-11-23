#include "MarkyCore.h"
#include "CancellationToken.h"
#include "Utf8.h"

#ifdef MARKY_CORE_TEST_CHECKPOINTS
#include "DocumentTestCheckpoints.h"
#endif

#include <map>
#include <memory>
#include <new>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

struct MarkyProjectTree {
    struct Node {
        std::string identity;
        std::string name;
        size_t parent_index;
        bool is_directory;
    };

    MarkyProjectScanState scan_state;
    std::vector<Node> nodes;
    // Keys borrow strings from nodes, which reserves its final capacity before insertion.
    std::map<std::string_view, size_t> by_identity;
    std::map<std::pair<size_t, std::string_view>, size_t> by_parent_and_name;
};

struct MarkyProjectQueryResult {
    std::vector<size_t> file_indices;
    std::vector<size_t> favorite_indices;
};

namespace {

struct EntryDecision {
    MarkyProjectEntryDisposition disposition = MARKY_PROJECT_ENTRY_SKIP;
    bool retain = false;
    size_t node_index = 0;
};

std::string copy_text(MarkyUtf8View text) {
    return text.byte_count == 0 ? std::string{} : std::string(text.data, text.byte_count);
}

}

MarkyStatus marky_project_tree_create(const MarkyProjectTreeEntry* entries, size_t entry_count,
                                     MarkyProjectScanState scan_state, const MarkyCancellationToken* token,
                                     MarkyProjectTree** out_tree) try {
    if (out_tree == nullptr) {
        return MARKY_STATUS_INVALID_ARGUMENT;
    }
    *out_tree = nullptr;
    if (marky::cancellation_requested(token)) {
        return MARKY_STATUS_CANCELLED;
    }
    switch (scan_state) {
    case MARKY_PROJECT_SCAN_UNKNOWN:
        return MARKY_STATUS_PROJECT_SCAN_UNKNOWN;
    case MARKY_PROJECT_SCAN_FAILED:
        return MARKY_STATUS_PROJECT_SCAN_FAILED;
    case MARKY_PROJECT_SCAN_COMPLETE:
    case MARKY_PROJECT_SCAN_PARTIAL:
        break;
    default:
        return MARKY_STATUS_INVALID_ARGUMENT;
    }
    if (entries == nullptr || entry_count == 0 || entries[0].parent_index != 0) {
        return MARKY_STATUS_INVALID_ARGUMENT;
    }

    std::vector<EntryDecision> decisions(entry_count);
    decisions[0] = {MARKY_PROJECT_ENTRY_SCAN_DIRECTORY, true, 0};
    for (size_t index = 1; index < entry_count; ++index) {
        if (marky::cancellation_requested(token)) {
            return MARKY_STATUS_CANCELLED;
        }
        const auto& entry = entries[index];
        if (entry.parent_index >= index ||
            decisions[entry.parent_index].disposition != MARKY_PROJECT_ENTRY_SCAN_DIRECTORY ||
            entry.metadata.kind > MARKY_PROJECT_ENTRY_PICKED_FILE ||
            (entry.metadata.kind == MARKY_PROJECT_ENTRY_PICKED_FILE &&
             (scan_state != MARKY_PROJECT_SCAN_PARTIAL || entry_count != 2)) ||
            (entry.metadata.kind == MARKY_PROJECT_ENTRY_SYMLINK &&
             entry.metadata.target_kind > MARKY_PROJECT_ENTRY_OTHER) ||
            !marky::is_valid_utf8(entry.metadata.name_extension.data, entry.metadata.name_extension.byte_count)) {
            return MARKY_STATUS_INVALID_ARGUMENT;
        }
        const auto disposition = entry.metadata.kind == MARKY_PROJECT_ENTRY_PICKED_FILE
            ? MARKY_PROJECT_ENTRY_DOCUMENT : marky_project_classify_entry(entry.metadata);
        if ((!entry.metadata.is_hidden && entry.metadata.kind == MARKY_PROJECT_ENTRY_UNKNOWN) ||
            disposition == MARKY_PROJECT_ENTRY_NEEDS_TARGET_METADATA) {
            return MARKY_STATUS_PROJECT_SCAN_UNKNOWN;
        }
        decisions[index] = {disposition, disposition == MARKY_PROJECT_ENTRY_DOCUMENT, 0};
    }

    // A reverse pass visits descendants before their parents, including deep trees.
    size_t retained_count = 1;
    for (size_t index = entry_count - 1; index > 0; --index) {
        if (marky::cancellation_requested(token)) {
            return MARKY_STATUS_CANCELLED;
        }
        if (decisions[index].retain) {
            decisions[entries[index].parent_index].retain = true;
            ++retained_count;
        }
    }

    auto tree = std::make_unique<MarkyProjectTree>();
    tree->scan_state = scan_state;
    tree->nodes.reserve(retained_count);
    for (size_t index = 0; index < entry_count; ++index) {
        if (marky::cancellation_requested(token)) {
            return MARKY_STATUS_CANCELLED;
        }
        auto& decision = decisions[index];
        if (!decision.retain) {
            continue;
        }
        const auto& entry = entries[index];
        if (entry.identity.byte_count == 0 || !marky::is_valid_utf8(entry.identity.data, entry.identity.byte_count) ||
            !marky::is_valid_utf8(entry.name.data, entry.name.byte_count) ||
            (index != 0 && entry.name.byte_count == 0)) {
            return MARKY_STATUS_INVALID_ARGUMENT;
        }
        decision.node_index = tree->nodes.size();
        tree->nodes.push_back({
            copy_text(entry.identity), copy_text(entry.name), decisions[entry.parent_index].node_index,
            decision.disposition == MARKY_PROJECT_ENTRY_SCAN_DIRECTORY
        });
        const auto& node = tree->nodes.back();
        if (!tree->by_identity.emplace(node.identity, decision.node_index).second ||
            (decision.node_index != 0 &&
             !tree->by_parent_and_name.emplace(std::pair{node.parent_index, std::string_view(node.name)},
                                               decision.node_index).second)) {
            return MARKY_STATUS_INVALID_ARGUMENT;
        }
#ifdef MARKY_CORE_TEST_CHECKPOINTS
        marky::test::checkpoint(marky::test::Checkpoint::afterProjectTreeNode);
#endif
    }
    if (marky::cancellation_requested(token)) {
        return MARKY_STATUS_CANCELLED;
    }
    *out_tree = tree.release();
    return MARKY_STATUS_OK;
} catch (const std::bad_alloc&) {
    return MARKY_STATUS_ALLOCATION_FAILURE;
} catch (...) {
    return MARKY_STATUS_INTERNAL_ERROR;
}

void marky_project_tree_release(MarkyProjectTree* tree) {
    delete tree;
}

MarkyProjectScanState marky_project_tree_scan_state(const MarkyProjectTree* tree) {
    if (tree == nullptr) {
        return MARKY_PROJECT_SCAN_UNKNOWN;
    }
    return tree->scan_state;
}

size_t marky_project_tree_node_count(const MarkyProjectTree* tree) {
    return tree != nullptr ? tree->nodes.size() : 0;
}

MarkyStatus marky_project_tree_node_at(const MarkyProjectTree* tree, size_t index,
                                      MarkyProjectTreeNodeView* out_node) {
    if (tree == nullptr || index >= tree->nodes.size() || out_node == nullptr) {
        return MARKY_STATUS_INVALID_ARGUMENT;
    }
    const auto& node = tree->nodes[index];
    *out_node = {{node.identity.data(), node.identity.size()}, {node.name.data(), node.name.size()},
                 node.parent_index, node.is_directory};
    return MARKY_STATUS_OK;
}

MarkyStatus marky_project_tree_find_identity(const MarkyProjectTree* tree, MarkyUtf8View identity,
                                            size_t* out_index) {
    if (tree == nullptr || out_index == nullptr || identity.byte_count == 0 ||
        !marky::is_valid_utf8(identity.data, identity.byte_count)) {
        return MARKY_STATUS_INVALID_ARGUMENT;
    }
    const auto match = tree->by_identity.find(std::string_view(identity.data, identity.byte_count));
    if (match == tree->by_identity.end()) {
        return MARKY_STATUS_PROJECT_NODE_NOT_FOUND;
    }
    *out_index = match->second;
    return MARKY_STATUS_OK;
}

MarkyStatus marky_project_tree_find_path(const MarkyProjectTree* tree, const MarkyUtf8View* segments,
                                        size_t segment_count, size_t* out_index) {
    if (tree == nullptr || out_index == nullptr || (segments == nullptr && segment_count != 0)) {
        return MARKY_STATUS_INVALID_ARGUMENT;
    }
    for (size_t index = 0; index < segment_count; ++index) {
        const auto [data, byte_count] = segments[index];
        if (byte_count == 0 || !marky::is_valid_utf8(data, byte_count)) {
            return MARKY_STATUS_INVALID_ARGUMENT;
        }
    }

    size_t parent = 0;
    for (size_t index = 0; index < segment_count; ++index) {
        const auto& segment = segments[index];
        const auto match = tree->by_parent_and_name.find({parent, std::string_view(segment.data, segment.byte_count)});
        if (match == tree->by_parent_and_name.end()) {
            return MARKY_STATUS_PROJECT_NODE_NOT_FOUND;
        }
        parent = match->second;
    }
    *out_index = parent;
    return MARKY_STATUS_OK;
}

MarkyStatus marky_project_tree_filter(const MarkyProjectTree* tree, MarkyProjectQuery query,
                                      const MarkyCancellationToken* token,
                                      MarkyProjectQueryResult** out_result) try {
    if (out_result == nullptr) {
        return MARKY_STATUS_INVALID_ARGUMENT;
    }
    *out_result = nullptr;
    if (marky::cancellation_requested(token)) {
        return MARKY_STATUS_CANCELLED;
    }
    if (tree == nullptr || (query.favorites == nullptr && query.favorite_count != 0)) {
        return MARKY_STATUS_INVALID_ARGUMENT;
    }
    const size_t node_count = tree->nodes.size();
    const bool empty_query = query.name_matches == nullptr;
    if (query.name_match_count != (empty_query ? 0 : node_count)) {
        return MARKY_STATUS_INVALID_ARGUMENT;
    }

    std::vector<uint8_t> visible;
    if (!empty_query) {
        visible.resize(node_count);
        // Parents precede their children, so each retained folder can retain its own parent.
        for (size_t index = node_count - 1; index > 0; --index) {
            if (marky::cancellation_requested(token)) {
                return MARKY_STATUS_CANCELLED;
            }
            if (visible[index] || query.name_matches[index]) {
                visible[index] = true;
                visible[tree->nodes[index].parent_index] = true;
            }
        }
    }

    auto result = std::make_unique<MarkyProjectQueryResult>();
    for (size_t index = 1; index < node_count; ++index) {
        if (marky::cancellation_requested(token)) {
            return MARKY_STATUS_CANCELLED;
        }
        if (empty_query || visible[index]) {
            result->file_indices.push_back(index);
        }
    }

    for (size_t index = 0; index < query.favorite_count; ++index) {
        if (marky::cancellation_requested(token)) {
            return MARKY_STATUS_CANCELLED;
        }
        const auto favorite = query.favorites[index];
        if (favorite.node_index >= node_count || tree->nodes[favorite.node_index].is_directory) {
            return MARKY_STATUS_INVALID_ARGUMENT;
        }
        if (empty_query || query.name_matches[favorite.node_index] || favorite.matches_relative_path) {
            result->favorite_indices.push_back(favorite.node_index);
        }
    }

#ifdef MARKY_CORE_TEST_CHECKPOINTS
    marky::test::checkpoint(marky::test::Checkpoint::beforeProjectQueryPublication);
#endif
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

MarkyProjectQueryResultView marky_project_query_result_view(const MarkyProjectQueryResult* result) {
    if (result == nullptr) {
        return {};
    }
    return {result->file_indices.data(), result->file_indices.size(),
            result->favorite_indices.data(), result->favorite_indices.size()};
}

void marky_project_query_result_release(MarkyProjectQueryResult* result) {
    delete result;
}
