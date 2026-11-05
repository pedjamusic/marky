import AppKit
import Foundation
import Testing
@testable import Marky

@MainActor
struct FilesOutlineTests {
    private final class PointerWindow: NSWindow {
        var pointerLocation = NSPoint(x: -100, y: -100)
        override var mouseLocationOutsideOfEventStream: NSPoint { pointerLocation }
    }

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

    @Test(arguments: [false, true])
    func searchExpansionPreservesManualFolderState(initiallyExpanded: Bool) {
        let folderURL = URL(fileURLWithPath: "/outline-fixture/docs", isDirectory: true)
        let child = FileNode(url: folderURL.appendingPathComponent("GUIDE.md"), name: "GUIDE.md", isDirectory: false, children: nil)
        let folder = FileNode(url: folderURL, name: "docs", isDirectory: true, children: [child])
        var manualExpansion: Set<URL> = initiallyExpanded ? [folderURL] : []
        var searching = false
        func state() -> FilesOutlineView {
            FilesOutlineView(nodes: [folder], selectedURL: nil, expandedFolderURLs: manualExpansion, favoriteFileURLs: [], expandAllFolders: searching, onSelectNode: { _ in }, onSetFolderExpanded: { node, expanded in
                if expanded { manualExpansion.insert(node.url) } else { manualExpansion.remove(node.url) }
            }, onToggleFavorite: { _ in })
        }
        let coordinator = state().makeCoordinator()
        let outline = TrackingOutlineView()
        outline.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("files")))
        outline.outlineTableColumn = outline.tableColumns[0]
        outline.dataSource = coordinator
        outline.delegate = coordinator
        coordinator.apply(to: outline)
        let folderItem = coordinator.outlineView(outline, child: 0, ofItem: nil)
        searching = true
        coordinator.parent = state()
        coordinator.apply(to: outline)
        #expect(outline.numberOfRows == 2)
        outline.collapseItem(folderItem)
        #expect(outline.isItemExpanded(folderItem))
        #expect(outline.numberOfRows == 2)
        #expect(manualExpansion.contains(folderURL) == initiallyExpanded)
        searching = false
        coordinator.parent = state()
        coordinator.apply(to: outline)
        #expect(outline.isItemExpanded(folderItem) == initiallyExpanded)
        #expect(outline.numberOfRows == (initiallyExpanded ? 2 : 1))
    }

    @Test
    func newlyAttachedRowShowsFavoriteUnderStationaryPointer() throws {
        let window = PointerWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 100), styleMask: .borderless, backing: .buffered, defer: false)
        window.pointerLocation = NSPoint(x: 100, y: 10)
        let row = SidebarOutlineRowView(frame: window.contentLayoutRect)
        row.configure(with: SidebarOutlineRowConfiguration(title: "GUIDE.md", icon: .file, showsFavoriteButton: true, isFavorite: false), onToggleFavorite: {})
        let button = try #require(row.subviews.compactMap { $0 as? NSButton }.first)
        #expect(button.isHidden)
        window.contentView = row
        #expect(!button.isHidden)
        window.contentView = nil
        #expect(button.isHidden)
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
        let window = PointerWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 200), styleMask: .borderless, backing: .buffered, defer: false)
        let scrollView = NSScrollView(frame: window.contentLayoutRect)
        outline.frame = scrollView.bounds
        scrollView.documentView = outline
        window.contentView = scrollView
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
        let row = try #require(outline.view(atColumn: 0, row: outline.row(forItem: fileItem), makeIfNecessary: true))
        let favoriteButton = try #require(row.subviews.compactMap { $0 as? NSButton }
            .first { $0.accessibilityLabel() == String(localized: "Remove from Favorites") })
        #expect(!favoriteButton.isHidden)
        window.pointerLocation = row.convert(NSPoint(x: row.bounds.midX, y: row.bounds.midY), to: nil)
        coordinator.parent = state(selected: fileURL)
        coordinator.apply(to: outline)
        let updatedRow = try #require(outline.view(atColumn: 0, row: outline.row(forItem: fileItem), makeIfNecessary: true))
        let addButton = try #require(updatedRow.subviews.compactMap { $0 as? NSButton }
            .first { $0.accessibilityLabel() == String(localized: "Add to Favorites") })
        #expect(!addButton.isHidden)
        let exitEvent = try #require(NSEvent.enterExitEvent(with: .mouseExited, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber, context: nil, eventNumber: 0, trackingNumber: 0, userData: nil))
        updatedRow.mouseExited(with: exitEvent)
        #expect(addButton.isHidden)
    }
}
