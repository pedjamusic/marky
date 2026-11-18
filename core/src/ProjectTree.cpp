#include "MarkyCore.h"
#include "CancellationToken.h"

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
            entry.metadata.kind > MARKY_PROJECT_ENTRY_OTHER ||
            (entry.metadata.kind == MARKY_PROJECT_ENTRY_SYMLINK &&
             entry.metadata.target_kind > MARKY_PROJECT_ENTRY_OTHER) ||
            (entry.metadata.name_extension.data == nullptr && entry.metadata.name_extension.byte_count != 0)) {
            return MARKY_STATUS_INVALID_ARGUMENT;
        }
        const auto disposition = marky_project_classify_entry(entry.metadata);
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
        if (entry.identity.data == nullptr || entry.identity.byte_count == 0 ||
            (entry.name.data == nullptr && entry.name.byte_count != 0) ||
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
    if (tree == nullptr || out_index == nullptr || identity.data == nullptr || identity.byte_count == 0) {
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
        if (segments[index].data == nullptr || segments[index].byte_count == 0) {
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
