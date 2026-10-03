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
        outlineView.headerView = nil
        outlineView.focusRingType = .none
        outlineView.backgroundColor = .clear
        outlineView.style = .sourceList
        outlineView.rowHeight = MarkyTheme.sidebarFilesOutlineRowHeight
        outlineView.rowSizeStyle = .custom
        outlineView.intercellSpacing = NSSize(width: 0, height: MarkyTheme.sidebarFilesOutlineRowSpacing)
        outlineView.indentationPerLevel = 0
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
        private var isApplyingState = false

        init(parent: FilesOutlineView) {
            self.parent = parent
        }

        func apply(to outlineView: NSOutlineView) {
            rootNodes = parent.nodes
            nodesByURL = [:]
            index(nodes: rootNodes)

            isApplyingState = true
            outlineView.reloadData()
            syncExpansion(in: outlineView, nodes: rootNodes)
            syncSelection(in: outlineView)
            isApplyingState = false
        }

        func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
            children(for: item).count
        }

        func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
            children(for: item)[index].url as NSURL
        }

        func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
            guard let node = node(for: item) else { return false }
            return node.isDirectory && !(node.children ?? []).isEmpty
        }

        func outlineView(_ outlineView: NSOutlineView, shouldShowOutlineCellForItem item: Any) -> Bool {
            false
        }

        func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
            MarkyTheme.sidebarFilesOutlineRowHeight
        }

        func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
            guard let node = node(for: item) else { return false }
            return !node.isDirectory
        }

        func outlineView(_ outlineView: NSOutlineView, shouldExpandItem item: Any) -> Bool {
            guard !isApplyingState, let node = node(for: item) else { return true }
            parent.onSetFolderExpanded(node, true)
            return true
        }

        func outlineView(_ outlineView: NSOutlineView, shouldCollapseItem item: Any) -> Bool {
            guard !isApplyingState, let node = node(for: item) else { return true }
            parent.onSetFolderExpanded(node, false)
            return true
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
                    outlineLevel: outlineView.level(forItem: item),
                    showsDisclosure: node.isDirectory && !(node.children ?? []).isEmpty,
                    isExpanded: outlineView.isItemExpanded(item),
                    showsFavoriteButton: !node.isDirectory,
                    isFavorite: parent.favoriteFileURLs.contains(node.url)
                ),
                onToggleDisclosure: { [weak outlineView] in
                    guard let outlineView else { return }
                    if outlineView.isItemExpanded(item) {
                        outlineView.collapseItem(item)
                    } else {
                        outlineView.expandItem(item)
                    }
                },
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
            guard let item,
                  let url = item as? NSURL
            else { return nil }
            return nodesByURL[url as URL]
        }

        private func index(nodes: [FileNode]) {
            for node in nodes {
                nodesByURL[node.url] = node
                index(nodes: node.children ?? [])
            }
        }

        private func syncExpansion(in outlineView: NSOutlineView, nodes: [FileNode]) {
            for node in nodes where node.isDirectory {
                let item = node.url as NSURL
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

            let row = outlineView.row(forItem: selectedURL as NSURL)
            guard row >= 0 else {
                outlineView.deselectAll(nil)
                return
            }

            outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        }
    }
}
#endif
