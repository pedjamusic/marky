import Foundation
import SwiftUI
import UniformTypeIdentifiers
import Combine

@MainActor
final class ContentViewModel: ObservableObject {
    enum ImportMode {
        case file
        case folder
    }

    @Published var root: FileNode?
    @Published var selectedURL: URL?
    @Published var importMode: ImportMode?
    @Published var sidebarSearchText = ""
    @Published var sidebarListRefreshID = UUID()
    @Published var splitViewVisibility: NavigationSplitViewVisibility = .automatic
    @Published var errorMessage: String?

    private var securityScopedURL: URL?
    private let projectSessionService: ProjectSessionServicing

    static let markdownFileTypes: [UTType] = {
        var types = ["md", "markdown", "mdown", "mkd"].compactMap { UTType(filenameExtension: $0) }
        types.append(.plainText)
        return types
    }()

    init(projectSessionService: ProjectSessionServicing? = nil) {
        self.projectSessionService = projectSessionService ?? ProjectSessionService()
    }

    deinit {
        securityScopedURL?.stopAccessingSecurityScopedResource()
    }

    var displayedNodes: [FileNode] {
        guard let root else { return [] }
        let nodes = root.children ?? []
        let query = sidebarSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return nodes }
        return filterNodes(nodes, query: query)
    }

    func restoreBookmarkIfNeeded() {
        if bootstrapSidebarForUITestingIfRequested() {
            return
        }
        guard root == nil else { return }

        do {
            guard let restored = try projectSessionService.restoreBookmarkedURL() else { return }
            guard FileManager.default.fileExists(atPath: restored.url.path) else {
                projectSessionService.clearBookmark()
                return
            }

            stopCurrentSecurityScopeIfNeeded()

            if restored.url.startAccessingSecurityScopedResource() {
                securityScopedURL = restored.url
                let values = try restored.url.resourceValues(forKeys: [.isDirectoryKey])
                if values.isDirectory == true {
                    root = FileNode.buildProjectTree(at: restored.url)
                } else {
                    let parent = restored.url.deletingLastPathComponent()
                    root = FileNode(url: parent, name: parent.lastPathComponent, isDirectory: true, children: [
                        FileNode(url: restored.url, name: restored.url.lastPathComponent, isDirectory: false, children: nil)
                    ])
                    selectedURL = restored.url
                }
                splitViewVisibility = .all
                if restored.isStale {
                    try projectSessionService.saveBookmark(for: restored.url)
                }
            } else {
                projectSessionService.clearBookmark()
                errorMessage = "Couldn't access the previously opened location."
            }
        } catch {
            projectSessionService.clearBookmark()
            errorMessage = userSafeErrorMessage(for: error)
        }
    }

    func closeProject() {
        stopCurrentSecurityScopeIfNeeded()
        projectSessionService.clearBookmark()
        selectedURL = nil
        root = nil
    }

    func openPickedFile(_ fileURL: URL) {
        stopCurrentSecurityScopeIfNeeded()

        let folderURL = fileURL.deletingLastPathComponent()
        let folderAccess = folderURL.startAccessingSecurityScopedResource()
        if folderAccess {
            securityScopedURL = folderURL
            persistBookmarkOrReportError(for: folderURL)
            root = FileNode.buildProjectTree(at: folderURL)
            selectedURL = fileURL
            splitViewVisibility = .all
            return
        }

        let fileAccess = fileURL.startAccessingSecurityScopedResource()
        if fileAccess {
            securityScopedURL = fileURL
        }
        persistBookmarkOrReportError(for: fileURL)
        root = FileNode(url: folderURL, name: folderURL.lastPathComponent, isDirectory: true, children: [
            FileNode(url: fileURL, name: fileURL.lastPathComponent, isDirectory: false, children: nil)
        ])
        selectedURL = fileURL
        splitViewVisibility = .all
    }

    func openPickedFolder(_ folderURL: URL) {
        stopCurrentSecurityScopeIfNeeded()
        let needsAccess = folderURL.startAccessingSecurityScopedResource()
        if needsAccess {
            securityScopedURL = folderURL
        }
        persistBookmarkOrReportError(for: folderURL)
        root = FileNode.buildProjectTree(at: folderURL)
        selectedURL = nil
        splitViewVisibility = .all
    }

    func collapseAllSidebarFolders() {
        sidebarListRefreshID = UUID()
    }

    func selectNode(_ node: FileNode) {
        guard !node.isDirectory else { return }
        selectedURL = node.url
    }

    private func stopCurrentSecurityScopeIfNeeded() {
        if let current = securityScopedURL {
            current.stopAccessingSecurityScopedResource()
            securityScopedURL = nil
        }
    }

    private func filterNodes(_ nodes: [FileNode], query: String) -> [FileNode] {
        let q = query.lowercased()
        return nodes.compactMap { node in
            if node.isDirectory {
                let filteredChildren = filterNodes(node.children ?? [], query: query)
                if node.name.lowercased().contains(q) || !filteredChildren.isEmpty {
                    return FileNode(url: node.url, name: node.name, isDirectory: true, children: filteredChildren)
                }
                return nil
            }
            return node.name.lowercased().contains(q) ? node : nil
        }
    }

    private func persistBookmarkOrReportError(for url: URL) {
        do {
            try projectSessionService.saveBookmark(for: url)
        } catch {
            errorMessage = userSafeErrorMessage(for: error)
        }
    }

    private func userSafeErrorMessage(for error: Error) -> String {
        switch error {
        case ProjectSessionError.bookmarkEncodingFailed:
            return "Couldn't save project access. You may need to reopen this location next time."
        case ProjectSessionError.bookmarkResolutionFailed:
            return "Couldn't restore the last opened project."
        default:
            return "An unexpected project access error occurred."
        }
    }

    @discardableResult
    private func bootstrapSidebarForUITestingIfRequested() -> Bool {
        guard root == nil else { return false }
        let env = ProcessInfo.processInfo.environment
        guard env["MARKY_UI_TEST_SEED"] == "1" else { return false }

        let fixtures = [
            FileNode(url: URL(fileURLWithPath: "/tmp/README.md"), name: "README.md", isDirectory: false, children: nil),
            FileNode(url: URL(fileURLWithPath: "/tmp/MEMORY.md"), name: "MEMORY.md", isDirectory: false, children: nil),
            FileNode(url: URL(fileURLWithPath: "/tmp/docs"), name: "docs", isDirectory: true, children: [
                FileNode(url: URL(fileURLWithPath: "/tmp/docs/GUIDE.md"), name: "GUIDE.md", isDirectory: false, children: nil)
            ])
        ]

        root = FileNode(
            url: URL(fileURLWithPath: "/tmp/marky-ui-seed-root"),
            name: "marky-ui-seed-root",
            isDirectory: true,
            children: fixtures
        )
        selectedURL = nil
        splitViewVisibility = .all
        return true
    }
}
