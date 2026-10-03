import Foundation
import SwiftUI
import UniformTypeIdentifiers
import Combine

@MainActor
final class ContentViewModel: ObservableObject {
    struct SidebarSection: Identifiable, Equatable {
        enum Kind: String, Equatable, Hashable {
            case favorites
            case files
        }

        let kind: Kind
        let title: String
        let nodes: [FileNode]

        var id: Kind { kind }
    }

    enum ImportMode {
        case file
        case folder
    }

    @Published var root: FileNode? {
        didSet {
            rebuildDisplayedNodes()
        }
    }
    @Published var selectedURL: URL?
    @Published var importMode: ImportMode?
    @Published var sidebarSearchText = "" {
        didSet {
            rebuildDisplayedNodes()
        }
    }
    @Published private(set) var displayedNodes: [FileNode] = []
    @Published private(set) var displayedSections: [SidebarSection] = []
    @Published var sidebarListRefreshID = UUID()
    @Published private(set) var expandedFolderURLs: Set<URL> = []
    @Published private(set) var collapsedSectionKinds: Set<SidebarSection.Kind> = []
    @Published var splitViewVisibility: NavigationSplitViewVisibility = .automatic
    @Published var errorMessage: String?
    @Published private(set) var favoriteFileURLs: Set<URL> = []

    private var securityScopedURL: URL?
    private let projectSessionService: ProjectSessionServicing
    private let favoritesStore: ProjectFavoritesStoring

    static let markdownFileTypes: [UTType] = {
        var types = ["md", "markdown", "mdown", "mkd"].compactMap { UTType(filenameExtension: $0) }
        types.append(.plainText)
        return types
    }()

    init(
        projectSessionService: ProjectSessionServicing? = nil,
        favoritesStore: ProjectFavoritesStoring? = nil
    ) {
        self.projectSessionService = projectSessionService ?? ProjectSessionService()
        self.favoritesStore = favoritesStore ?? ProjectFavoritesStore()
    }

    deinit {
        securityScopedURL?.stopAccessingSecurityScopedResource()
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
                    finishOpeningProject(selectedFileURL: nil)
                } else {
                    let parent = restored.url.deletingLastPathComponent()
                    root = FileNode(url: parent, name: parent.lastPathComponent, isDirectory: true, children: [
                        FileNode(url: restored.url, name: restored.url.lastPathComponent, isDirectory: false, children: nil)
                    ])
                    finishOpeningProject(selectedFileURL: restored.url)
                }
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
        favoriteFileURLs.removeAll()
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
            finishOpeningProject(selectedFileURL: fileURL)
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
        finishOpeningProject(selectedFileURL: fileURL)
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
        finishOpeningProject(selectedFileURL: nil)
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

    func toggleSidebarSection(_ kind: SidebarSection.Kind) {
        if collapsedSectionKinds.contains(kind) {
            collapsedSectionKinds.remove(kind)
        } else {
            collapsedSectionKinds.insert(kind)
        }
    }

    func isSidebarSectionCollapsed(_ kind: SidebarSection.Kind) -> Bool {
        collapsedSectionKinds.contains(kind)
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

    func setFolderExpansion(for node: FileNode, isExpanded: Bool) {
        setFolder(node, expanded: isExpanded)
    }

    func toggleFavorite(for node: FileNode) {
        guard !node.isDirectory, let root else { return }

        if favoriteFileURLs.contains(node.url) {
            favoriteFileURLs.remove(node.url)
        } else {
            favoriteFileURLs.insert(node.url)
        }

        persistFavorites(for: root)
        rebuildDisplayedNodes()
    }

    func isFavorite(_ node: FileNode) -> Bool {
        favoriteFileURLs.contains(node.url)
    }

    private func stopCurrentSecurityScopeIfNeeded() {
        if let current = securityScopedURL {
            current.stopAccessingSecurityScopedResource()
            securityScopedURL = nil
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

    private func finishOpeningProject(selectedFileURL: URL?) {
        self.selectedURL = selectedFileURL
        expandedFolderURLs.removeAll()
        splitViewVisibility = .all
        reloadFavoritesForCurrentProject()
    }

    private func reloadFavoritesForCurrentProject() {
        guard let root else {
            favoriteFileURLs.removeAll()
            return
        }

        let allFilesByRelativePath = fileNodesByRelativePath(in: root)
        let storedPaths = favoritesStore.favoriteRelativePaths(for: root.url)
        favoriteFileURLs = Set(
            storedPaths.compactMap { allFilesByRelativePath[$0]?.url }
        )
        persistFavorites(for: root)
        rebuildDisplayedNodes()
    }

    private func persistFavorites(for root: FileNode) {
        let relativePaths = favoriteFileURLs
            .compactMap { relativePath(for: $0, in: root.url) }
            .sorted()

        if relativePaths.isEmpty {
            favoritesStore.clearFavorites(for: root.url)
        } else {
            favoritesStore.saveFavoriteRelativePaths(relativePaths, for: root.url)
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

    private func rebuildDisplayedNodes() {
        guard let root else {
            displayedNodes = []
            displayedSections = []
            return
        }

        let query = normalizedSidebarSearchQuery
        let nodes = root.children ?? []
        let filteredNodes = query.isEmpty ? nodes : filterNodes(nodes, normalizedQuery: query)
        displayedNodes = filteredNodes

        let favoriteNodes = displayedFavoriteNodes(in: root, normalizedQuery: query)
        displayedSections = [
            SidebarSection(kind: .favorites, title: "Favorites", nodes: favoriteNodes),
            SidebarSection(kind: .files, title: "Files", nodes: filteredNodes)
        ]
    }

    private var normalizedSidebarSearchQuery: String {
        sidebarSearchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .localizedLowercase
    }

    private func filterNodes(_ nodes: [FileNode], normalizedQuery query: String) -> [FileNode] {
        nodes.compactMap { node in
            if node.isDirectory {
                let filteredChildren = filterNodes(node.children ?? [], normalizedQuery: query)
                if node.name.localizedLowercase.contains(query) || !filteredChildren.isEmpty {
                    return FileNode(url: node.url, name: node.name, isDirectory: true, children: filteredChildren)
                }
                return nil
            }
            return node.name.localizedLowercase.contains(query) ? node : nil
        }
    }

    private func displayedFavoriteNodes(in root: FileNode, normalizedQuery query: String) -> [FileNode] {
        fileNodesByRelativePath(in: root)
            .values
            .filter { favoriteFileURLs.contains($0.url) }
            .filter { query.isEmpty || favoriteMatchesQuery($0, normalizedQuery: query, rootURL: root.url) }
            .sorted { lhs, rhs in
                let nameComparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
                if nameComparison != .orderedSame {
                    return nameComparison == .orderedAscending
                }

                let lhsPath = relativePath(for: lhs.url, in: root.url) ?? lhs.url.path
                let rhsPath = relativePath(for: rhs.url, in: root.url) ?? rhs.url.path
                return lhsPath.localizedCaseInsensitiveCompare(rhsPath) == .orderedAscending
            }
    }

    private func favoriteMatchesQuery(_ node: FileNode, normalizedQuery query: String, rootURL: URL) -> Bool {
        if node.name.localizedLowercase.contains(query) {
            return true
        }

        guard let relativePath = relativePath(for: node.url, in: rootURL) else {
            return false
        }
        return relativePath.localizedLowercase.contains(query)
    }

    private func fileNodesByRelativePath(in root: FileNode) -> [String: FileNode] {
        var nodesByPath: [String: FileNode] = [:]
        for fileNode in flattenedFileNodes(in: root.children ?? []) {
            guard let relativePath = relativePath(for: fileNode.url, in: root.url) else { continue }
            nodesByPath[relativePath] = fileNode
        }
        return nodesByPath
    }

    private func flattenedFileNodes(in nodes: [FileNode]) -> [FileNode] {
        nodes.flatMap { node in
            if node.isDirectory {
                return flattenedFileNodes(in: node.children ?? [])
            }
            return [node]
        }
    }

    private func relativePath(for fileURL: URL, in rootURL: URL) -> String? {
        let rootPath = rootURL.standardizedFileURL.path
        let filePath = fileURL.standardizedFileURL.path

        guard filePath == rootPath || filePath.hasPrefix(rootPath + "/") else {
            return nil
        }

        if filePath == rootPath {
            return fileURL.lastPathComponent
        }

        return String(filePath.dropFirst(rootPath.count + 1))
    }
}
