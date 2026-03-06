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
    @Published private(set) var expandedFolderURLs: Set<URL> = []
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

    func requestFileImport() {
        importMode = .file
    }

    func requestFolderImport() {
        importMode = .folder
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
                expandedFolderURLs.removeAll()
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
        expandedFolderURLs.removeAll()
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
            expandedFolderURLs.removeAll()
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
        expandedFolderURLs.removeAll()
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
        expandedFolderURLs.removeAll()
        splitViewVisibility = .all
    }

    func handlePickedURL(_ pickedURL: URL, mode: ImportMode) {
        switch mode {
        case .file:
            openPickedFile(pickedURL)
        case .folder:
            openPickedFolder(pickedURL)
        }
    }

    func handleFileImporterResult(_ result: Result<[URL], Error>) {
        guard let mode = importMode else { return }
        defer { importMode = nil }

        switch result {
        case .success(let urls):
            guard let pickedURL = urls.first else { return }
            handlePickedURL(pickedURL, mode: mode)
        case .failure(let error):
            errorMessage = "Couldn't import the selected item. \(error.localizedDescription)"
        }
    }

    func collapseAllSidebarFolders() {
        expandedFolderURLs.removeAll()
        sidebarListRefreshID = UUID()
    }

    func selectNode(_ node: FileNode) {
        guard !node.isDirectory else {
            toggleFolderExpansion(node)
            return
        }
        selectedURL = node.url
    }

    func folderExpansionBinding(for node: FileNode) -> Binding<Bool> {
        Binding(
            get: { [weak self] in
                guard let self else { return false }
                return self.isFolderExpanded(node)
            },
            set: { [weak self] isExpanded in
                self?.setFolder(node, expanded: isExpanded)
            }
        )
    }

    func toggleFolderExpansion(for node: FileNode) {
        toggleFolderExpansion(node)
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

    private var hasActiveSidebarSearchQuery: Bool {
        !sidebarSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func isFolderExpanded(_ node: FileNode) -> Bool {
        guard node.isDirectory else { return false }
        if hasActiveSidebarSearchQuery {
            return true
        }
        return expandedFolderURLs.contains(node.url)
    }

    private func setFolder(_ node: FileNode, expanded: Bool) {
        guard node.isDirectory else { return }
        if expanded {
            expandedFolderURLs.insert(node.url)
        } else {
            expandedFolderURLs.remove(node.url)
        }
    }

    private func toggleFolderExpansion(_ node: FileNode) {
        guard node.isDirectory else { return }
        if expandedFolderURLs.contains(node.url) {
            expandedFolderURLs.remove(node.url)
        } else {
            expandedFolderURLs.insert(node.url)
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
        expandedFolderURLs.removeAll()
        splitViewVisibility = .all
        return true
    }
}
