import AppKit
import Foundation
import Testing
@testable import Marky

@MainActor
struct FilesOutlineTests {
    private final class TrackingOutlineView: NSOutlineView {
        var fullReloadCount = 0
        var testClickedRow = -1

        override var clickedRow: Int { testClickedRow }

        override func reloadData() {
            fullReloadCount += 1
            super.reloadData()
        }
    }

    @Test
    func rowTapAndCollapseAllRemoveChildrenFromVisibleOutlineRows() {
        let folderURL = URL(fileURLWithPath: "/outline-fixture/docs", isDirectory: true)
        let fileURL = folderURL.appendingPathComponent("GUIDE.md")
        let child = FileNode(url: fileURL, name: "GUIDE.md", isDirectory: false, children: nil)
        let folder = FileNode(url: folderURL, name: "docs", isDirectory: true, children: [child])
        var expanded: Set<URL> = []
        func state() -> FilesOutlineView {
            FilesOutlineView(
                nodes: [folder], selectedURL: nil, expandedFolderURLs: expanded,
                favoriteFileURLs: [], expandAllFolders: false,
                onSelectNode: { _ in },
                onSetFolderExpanded: { node, isExpanded in
                    if isExpanded { expanded.insert(node.url) } else { expanded.remove(node.url) }
                }, onToggleFavorite: { _ in }
            )
        }
        let coordinator = state().makeCoordinator()
        let outline = TrackingOutlineView()
        outline.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("files")))
        outline.outlineTableColumn = outline.tableColumns[0]
        outline.dataSource = coordinator
        outline.delegate = coordinator
        coordinator.apply(to: outline)
        let folderItem = coordinator.outlineView(outline, child: 0, ofItem: nil)
        let fileItem = coordinator.outlineView(outline, child: 0, ofItem: folderItem)
        #expect(outline.numberOfRows == 1)

        outline.testClickedRow = 0
        coordinator.handleRowClick(outline)
        #expect(expanded == [folderURL])
        coordinator.parent = state()
        coordinator.apply(to: outline)
        #expect(outline.numberOfRows == 2)
        #expect(outline.row(forItem: fileItem) == 1)

        coordinator.handleRowClick(outline)
        #expect(expanded.isEmpty)
        coordinator.parent = state()
        coordinator.apply(to: outline)
        #expect(!outline.isItemExpanded(folderItem))
        #expect(outline.numberOfRows == 1)
        #expect(outline.row(forItem: fileItem) == -1)

        coordinator.handleRowClick(outline)
        coordinator.parent = state()
        coordinator.apply(to: outline)
        #expect(outline.numberOfRows == 2)
        expanded.removeAll()
        coordinator.parent = state()
        coordinator.apply(to: outline)
        #expect(!outline.isItemExpanded(folderItem))
        #expect(outline.numberOfRows == 1)
        #expect(outline.row(forItem: fileItem) == -1)
    }

    @Test
    func selectionAndFavoriteChangesRetainExpandedFolderAndVisibleChild() throws {
        let folderURL = URL(fileURLWithPath: "/outline-fixture/docs", isDirectory: true)
        let fileURL = folderURL.appendingPathComponent("GUIDE.md")
        let file = FileNode(url: fileURL, name: "GUIDE.md", isDirectory: false, children: nil)
        let folder = FileNode(url: folderURL, name: "docs", isDirectory: true, children: [file])
        func state(selected: URL? = nil, favorites: Set<URL> = []) -> FilesOutlineView {
            FilesOutlineView(
                nodes: [folder], selectedURL: selected, expandedFolderURLs: [folderURL],
                favoriteFileURLs: favorites, expandAllFolders: false,
                onSelectNode: { _ in }, onSetFolderExpanded: { _, _ in }, onToggleFavorite: { _ in }
            )
        }
        let coordinator = state().makeCoordinator()
        let outline = TrackingOutlineView()
        outline.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("files")))
        outline.outlineTableColumn = outline.tableColumns[0]
        outline.dataSource = coordinator
        outline.delegate = coordinator
        coordinator.apply(to: outline)
        let folderItem = coordinator.outlineView(outline, child: 0, ofItem: nil)
        let fileItem = coordinator.outlineView(outline, child: 0, ofItem: folderItem)
        let reloadCount = outline.fullReloadCount
        #expect(outline.isItemExpanded(folderItem))
        #expect(outline.row(forItem: fileItem) >= 0)

        coordinator.parent = state(selected: fileURL)
        coordinator.apply(to: outline)
        #expect(outline.fullReloadCount == reloadCount)
        #expect(outline.isItemExpanded(folderItem))
        #expect(outline.selectedRow == outline.row(forItem: fileItem))

        coordinator.parent = state(selected: fileURL, favorites: [fileURL])
        coordinator.apply(to: outline)
        #expect(outline.fullReloadCount == reloadCount)
        #expect(outline.isItemExpanded(folderItem))
        #expect(outline.selectedRow == outline.row(forItem: fileItem))
        let row = try #require(coordinator.outlineView(outline, viewFor: outline.tableColumns[0], item: fileItem))
        let favoriteButton = try #require(row.subviews.compactMap { $0 as? NSButton }
            .first { $0.accessibilityLabel() == String(localized: "Remove from Favorites") })
        #expect(!favoriteButton.isHidden)
    }
}
