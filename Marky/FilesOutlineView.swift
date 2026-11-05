import SwiftUI

#if os(macOS)
import AppKit

struct FilesOutlineView: NSViewRepresentable {
    let nodes: [FileNode]
    let selectedURL: URL?
    let expandedFolderURLs: Set<URL>
    let favoriteFileURLs: Set<URL>
    let expandAllFolders: Bool
    let onSelectNode: (FileNode) -> Void
    let onSetFolderExpanded: (FileNode, Bool) -> Void
    let onToggleFavorite: (FileNode) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let outlineView = NSOutlineView()
        outlineView.setAccessibilityIdentifier("files-outline")
        outlineView.headerView = nil
        outlineView.focusRingType = .none
        outlineView.backgroundColor = .clear
        outlineView.style = .sourceList
        outlineView.rowHeight = MarkyTheme.sidebarFilesOutlineRowHeight
        outlineView.rowSizeStyle = .custom
        outlineView.intercellSpacing = NSSize(width: 0, height: MarkyTheme.sidebarFilesOutlineRowSpacing)
        // Native disclosure cells also preserve AppKit's collapse behavior.
        outlineView.indentationPerLevel = MarkyTheme.sidebarFilesOutlineIndentPerLevel
        outlineView.floatsGroupRows = false
        outlineView.allowsEmptySelection = true
        outlineView.dataSource = context.coordinator
        outlineView.delegate = context.coordinator
        outlineView.target = context.coordinator
        outlineView.action = #selector(Coordinator.handleRowClick(_:))

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("files"))
        column.resizingMask = .autoresizingMask
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column

        scrollView.documentView = outlineView
        context.coordinator.apply(to: outlineView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let outlineView = scrollView.documentView as? NSOutlineView else { return }
        context.coordinator.apply(to: outlineView)
    }

    final class Coordinator: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {
        var parent: FilesOutlineView
        private var rootNodes: [FileNode] = []
        private var nodesByURL: [URL: FileNode] = [:]
        // NSOutlineView retains expansion state by item identity. Keep the same objects
        // across data source queries and incremental updates for this tree.
        private final class Item: NSObject {
            let url: URL
            init(url: URL) { self.url = url }
        }
        private var itemsByURL: [URL: Item] = [:]
        private var isApplyingState = false
        private var hasAppliedState = false
        private var expandedFolderURLs: Set<URL> = []
        private var favoriteFileURLs: Set<URL> = []
        private var expandAllFolders = false

        init(parent: FilesOutlineView) {
            self.parent = parent
        }

        func apply(to outlineView: NSOutlineView) {
            let structureChanged = !hasAppliedState || rootNodes != parent.nodes
            let expansionChanged = structureChanged || expandedFolderURLs != parent.expandedFolderURLs
                || expandAllFolders != parent.expandAllFolders
            let changedFavorites = favoriteFileURLs.symmetricDifference(parent.favoriteFileURLs)

            isApplyingState = true
            defer { isApplyingState = false }
            if structureChanged {
                rootNodes = parent.nodes
                nodesByURL.removeAll(keepingCapacity: true)
                itemsByURL.removeAll(keepingCapacity: true)
                index(nodes: rootNodes)
                outlineView.reloadData()
            }
            if expansionChanged {
                syncExpansion(in: outlineView, nodes: rootNodes)
            }
            if !structureChanged {
                let rows = IndexSet(changedFavorites.compactMap { url in
                    let row = outlineView.row(forItem: item(for: url))
                    return row >= 0 ? row : nil
                })
                if !rows.isEmpty {
                    outlineView.reloadData(forRowIndexes: rows, columnIndexes: IndexSet(integer: 0))
                }
            }
            syncSelection(in: outlineView)
            expandedFolderURLs = parent.expandedFolderURLs
            favoriteFileURLs = parent.favoriteFileURLs
            expandAllFolders = parent.expandAllFolders
            hasAppliedState = true
        }

        func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
            children(for: item).count
        }

        func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
            self.item(for: children(for: item)[index].url)
        }

        func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
            guard let node = node(for: item) else { return false }
            return node.isDirectory && !(node.children ?? []).isEmpty
        }

        func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
            MarkyTheme.sidebarFilesOutlineRowHeight
        }

        func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
            guard let node = node(for: item) else { return false }
            return !node.isDirectory
        }

        func outlineViewItemDidExpand(_ notification: Notification) {
            publishExpansion(from: notification, isExpanded: true)
        }

        func outlineViewItemDidCollapse(_ notification: Notification) {
            publishExpansion(from: notification, isExpanded: false)
        }

        private func publishExpansion(from notification: Notification, isExpanded: Bool) {
            guard !isApplyingState,
                  let node = node(for: notification.userInfo?["NSObject"])
            else { return }
            parent.onSetFolderExpanded(node, isExpanded)
        }

        func outlineViewSelectionDidChange(_ notification: Notification) {
            guard !isApplyingState,
                  let outlineView = notification.object as? NSOutlineView
            else { return }

            let row = outlineView.selectedRow
            guard row >= 0, let node = node(for: outlineView.item(atRow: row)) else { return }
            parent.onSelectNode(node)
        }

        @objc
        func handleRowClick(_ outlineView: NSOutlineView) {
            let row = outlineView.clickedRow
            guard row >= 0,
                  let item = outlineView.item(atRow: row),
                  let node = node(for: item),
                  node.isDirectory
            else { return }

            if outlineView.isItemExpanded(item) {
                outlineView.collapseItem(item)
            } else {
                outlineView.expandItem(item)
            }
        }

        func outlineView(
            _ outlineView: NSOutlineView,
            viewFor tableColumn: NSTableColumn?,
            item: Any
        ) -> NSView? {
            guard let node = node(for: item) else { return nil }

            let identifier = NSUserInterfaceItemIdentifier("FilesOutlineCell")
            let rowView = (outlineView.makeView(withIdentifier: identifier, owner: nil) as? SidebarOutlineRowView)
                ?? SidebarOutlineRowView(frame: .zero)
            rowView.identifier = identifier
            rowView.configure(
                with: SidebarOutlineRowConfiguration(
                    title: node.name,
                    icon: node.isDirectory ? .folder : .file,
                    showsFavoriteButton: !node.isDirectory,
                    isFavorite: parent.favoriteFileURLs.contains(node.url)
                ),
                onToggleFavorite: { [weak self] in
                    guard let self else { return }
                    self.parent.onToggleFavorite(node)
                }
            )
            return rowView
        }

        private func children(for item: Any?) -> [FileNode] {
            guard let item else { return rootNodes }
            return node(for: item)?.children ?? []
        }

        private func node(for item: Any?) -> FileNode? {
            guard let outlineItem = item as? Item else { return nil }
            return nodesByURL[outlineItem.url]
        }

        private func item(for url: URL) -> Item {
            if let item = itemsByURL[url] { return item }
            let item = Item(url: url)
            itemsByURL[url] = item
            return item
        }

        private func index(nodes: [FileNode]) {
            for node in nodes {
                nodesByURL[node.url] = node
                index(nodes: node.children ?? [])
            }
        }

        private func syncExpansion(in outlineView: NSOutlineView, nodes: [FileNode]) {
            for node in nodes where node.isDirectory {
                let item = item(for: node.url)
                if parent.expandAllFolders || parent.expandedFolderURLs.contains(node.url) {
                    outlineView.expandItem(item)
                } else {
                    outlineView.collapseItem(item, collapseChildren: true)
                }
                syncExpansion(in: outlineView, nodes: node.children ?? [])
            }
        }

        private func syncSelection(in outlineView: NSOutlineView) {
            guard let selectedURL = parent.selectedURL else {
                outlineView.deselectAll(nil)
                return
            }

            let row = outlineView.row(forItem: item(for: selectedURL))
            guard row >= 0 else {
                outlineView.deselectAll(nil)
                return
            }

            if outlineView.selectedRow != row {
                outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            }
        }
    }
}
#endif
