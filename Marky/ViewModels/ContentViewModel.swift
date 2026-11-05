import Foundation
import SwiftUI
import UniformTypeIdentifiers
import Combine
import OSLog

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
            filesByRelativePath = root.map { fileNodesByRelativePath(in: $0) } ?? [:]
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
    private var projectLoadTask: Task<Void, Never>?
    private var projectLoadID = UUID()
    private var isProjectLoadPending = false
    private var ownedUITestFixtureURL: URL?
    private var storedFavoritePaths: Set<String> = []
    private var filesByRelativePath: [String: FileNode] = [:]
    private let ownedTestDefaultsSuite: String?
    private let skipAutomaticRestoration: Bool
    private let resourceAccess: ProjectResourceAccessing
    private let scanProject: @Sendable (URL) async throws -> FileNode
    private let probeMissingFavorites: @Sendable (Set<String>, FileNode) async throws -> Set<String>
    private let projectSessionService: ProjectSessionServicing
    private let favoritesStore: ProjectFavoritesStoring

    static let markdownFileTypes: [UTType] = {
        var types = FileNode.markdownFileExtensions.compactMap { UTType(filenameExtension: $0) }
        types.append(.plainText)
        return types
    }()

    init(
        projectSessionService: ProjectSessionServicing? = nil,
        favoritesStore: ProjectFavoritesStoring? = nil,
        resourceAccess: ProjectResourceAccessing? = nil,
        scanProject: @escaping @Sendable (URL) async throws -> FileNode = { try await FileNode.loadProjectTree(at: $0) },
        probeMissingFavorites: (@Sendable (Set<String>, FileNode) async throws -> Set<String>)? = nil
    ) {
        let testDefaults: UserDefaults?
        let environment = ProcessInfo.processInfo.environment
        skipAutomaticRestoration = environment["XCTestConfigurationFilePath"] != nil && projectSessionService == nil
        if environment["MARKY_UI_TEST_SEED"] == "1" || environment["XCTestConfigurationFilePath"] != nil || environment["MARKY_TEST_DEFAULTS_SUITE"] != nil {
            let suite = environment["MARKY_TEST_DEFAULTS_SUITE"] ?? "Marky.Tests.\(UUID().uuidString)"
            ownedTestDefaultsSuite = environment["MARKY_TEST_DEFAULTS_SUITE"] == nil ? suite : nil
            testDefaults = UserDefaults(suiteName: suite)
        } else {
            ownedTestDefaultsSuite = nil
            testDefaults = nil
        }
        self.projectSessionService = projectSessionService ?? ProjectSessionService(userDefaults: testDefaults ?? .standard)
        self.favoritesStore = favoritesStore ?? ProjectFavoritesStore(userDefaults: testDefaults ?? .standard)
        self.resourceAccess = resourceAccess ?? ProjectResourceAccess()
        self.scanProject = scanProject
        self.probeMissingFavorites = probeMissingFavorites ?? { try await Self.confirmedMissingFavorites($0, in: $1) }
    }

    isolated deinit {
        projectLoadTask?.cancel()
        if let securityScopedURL { resourceAccess.stopAccessing(securityScopedURL) }
        if let ownedTestDefaultsSuite { UserDefaults.standard.removePersistentDomain(forName: ownedTestDefaultsSuite) }
        if let ownedUITestFixtureURL {
            do {
                try FileManager.default.removeItem(at: ownedUITestFixtureURL)
            } catch {
                Logger(subsystem: "rocks.toodear.Marky", category: "UITesting")
                    .error("Could not remove temporary UI test fixture.")
            }
        }
    }

    func requestFileImport() {
        importMode = .file
    }

    func requestFolderImport() {
        importMode = .folder
    }

    func restoreBookmarkIfNeeded() {
        guard !isProjectLoadPending else { return }
        if bootstrapSidebarForUITestingIfRequested() {
            return
        }
        guard root == nil else { return }
        if skipAutomaticRestoration { return }

        do {
            guard let restored = try projectSessionService.restoreBookmarkedURL() else { return }
            beginOpening(restored.url, mode: nil, persistBookmark: restored.isStale)
        } catch {
            errorMessage = userSafeErrorMessage(for: error)
        }
    }

    func closeProject() {
        projectLoadTask?.cancel()
        projectLoadID = UUID()
        isProjectLoadPending = false
        stopCurrentSecurityScopeIfNeeded()
        projectSessionService.clearBookmark()
        selectedURL = nil
        root = nil
        expandedFolderURLs.removeAll()
        favoriteFileURLs.removeAll()
        storedFavoritePaths.removeAll()
    }

    func openPickedFile(_ fileURL: URL) {
        let parent = fileURL.deletingLastPathComponent()
        if resourceAccess.startAccessing(parent) {
            beginOpening(parent, mode: .folder, persistBookmark: true, preactivatedAccess: true, selectedOverride: fileURL)
        } else {
            beginOpening(fileURL, mode: .file, persistBookmark: true)
        }
    }

    func openPickedFolder(_ folderURL: URL) {
        beginOpening(folderURL, mode: .folder, persistBookmark: true)
    }

    /// Waits for the current request; useful when callers need its published outcome.
    func waitForProjectLoad() async {
        await projectLoadTask?.value
    }

    private func beginOpening(_ grantedURL: URL, mode: ImportMode?, persistBookmark: Bool,
                              preactivatedAccess: Bool? = nil, selectedOverride: URL? = nil) {
        projectLoadTask?.cancel()
        let requestID = UUID()
        projectLoadID = requestID
        isProjectLoadPending = true
        errorMessage = nil
        // Activate the original granted URL before any filesystem inspection. Canonical
        // URLs are identities only; they must not replace the scope's lifetime URL.
        let accessed = preactivatedAccess ?? resourceAccess.startAccessing(grantedURL)
        let scanProject = self.scanProject
        let probeMissingFavorites = self.probeMissingFavorites
        let resourceAccess = self.resourceAccess
        projectLoadTask = Task { [weak self] in
            var adoptedScope = false
            var candidateURL = grantedURL
            var candidateAccess = accessed
            defer {
                if candidateAccess && !adoptedScope { resourceAccess.stopAccessing(candidateURL) }
                if let self, self.projectLoadID == requestID { self.isProjectLoadPending = false }
            }
            do {
                let isDirectory: Bool
                if let mode {
                    isDirectory = mode == .folder
                } else {
                    // Resource inspection belongs off the main actor too.
                    isDirectory = try await Task.detached {
                        do {
                            return try grantedURL.canonicalFileURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
                        } catch {
                            throw ProjectScanError.resourceFailure(error)
                        }
                    }.value
                }
                let newRoot: FileNode
                let selectedFile: URL?
                var fullProjectScope = isDirectory
                if isDirectory {
                    do {
                        newRoot = try await scanProject(grantedURL)
                        selectedFile = selectedOverride?.canonicalDocumentURL
                    } catch {
                        try Task.checkCancellation()
                        guard let selectedOverride else { throw error }
                        // A picked file remains usable when its parent's sibling
                        // subtree is unreadable. This fallback is explicitly partial.
                        let fileAccess = resourceAccess.startAccessing(selectedOverride)
                        do {
                            newRoot = try await Self.singleFileRoot(at: selectedOverride)
                        } catch {
                            if fileAccess { resourceAccess.stopAccessing(selectedOverride) }
                            throw error
                        }
                        if fileAccess {
                            if candidateAccess { resourceAccess.stopAccessing(candidateURL) }
                            candidateURL = selectedOverride
                            candidateAccess = true
                        }
                        selectedFile = selectedOverride.canonicalDocumentURL
                        fullProjectScope = false
                    }
                } else {
                    newRoot = try await Self.singleFileRoot(at: grantedURL)
                    selectedFile = grantedURL.canonicalDocumentURL
                }
                try Task.checkCancellation()
                guard self?.projectLoadID == requestID else { return }
                let grantedProjectURL = isDirectory ? grantedURL : grantedURL.deletingLastPathComponent()
                self?.favoritesStore.migrateFavorites(from: grantedProjectURL, to: newRoot.url)
                let pathsToProbe = Set(self?.favoritesStore.favoriteRelativePaths(for: newRoot.url) ?? [])
                let missing: Set<String>
                if fullProjectScope {
                    missing = try await probeMissingFavorites(pathsToProbe, newRoot)
                } else {
                    missing = []
                }
                try Task.checkCancellation()
                guard let self, requestID == self.projectLoadID else { return }
                // The existing project stays interactive during the probe. Apply its
                // result to the latest store, including edits made by another window.
                var favoritePaths = Set(self.favoritesStore.favoriteRelativePaths(for: newRoot.url))
                favoritePaths.subtract(missing)
                self.stopCurrentSecurityScopeIfNeeded()
                if candidateAccess {
                    self.securityScopedURL = candidateURL
                    adoptedScope = true
                }
                self.root = newRoot
                self.storedFavoritePaths = favoritePaths
                self.finishOpeningProject(selectedFileURL: selectedFile)
                if persistBookmark { self.persistBookmarkOrReportError(for: candidateURL) }
            } catch is CancellationError {
                // Superseding/closing a request is not a user-facing access failure.
            } catch {
                guard let self, requestID == self.projectLoadID, !Task.isCancelled else { return }
                self.errorMessage = self.userSafeErrorMessage(for: error)
            }
        }
    }

    /// Checks unindexed saved paths off-main; inaccessible paths remain unknown.
    private nonisolated static func confirmedMissingFavorites(_ paths: Set<String>, in root: FileNode) async throws -> Set<String> {
        let worker = Task.detached(priority: .userInitiated) {
            var indexedPaths: Set<String> = []
            var nodes = root.children ?? []
            while let node = nodes.popLast() {
                try Task.checkCancellation()
                if node.isDirectory { nodes.append(contentsOf: node.children ?? []) }
                else if node.url.path.hasPrefix(root.url.path + "/") {
                    indexedPaths.insert(String(node.url.path.dropFirst(root.url.path.count + 1)))
                }
            }
            var missing: Set<String> = []
            for path in paths.subtracting(indexedPaths) {
                try Task.checkCancellation()
                let url = root.url.appendingPathComponent(path).standardizedFileURL
                // Stored paths are untrusted persistence data. Never inspect outside the project.
                guard !path.hasPrefix("/"), url.path.hasPrefix(root.url.path + "/") else { continue }
                do {
                    _ = try url.resourceValues(forKeys: [.isRegularFileKey])
                } catch {
                    // Access denial or transient I/O is unknown, so retain the saved favorite.
                    if ProjectScanError.resourceFailure(error) == .missing { missing.insert(path) }
                }
            }
            return missing
        }
        return try await withTaskCancellationHandler {
            try await worker.value
        } onCancel: {
            worker.cancel()
        }
    }

    private nonisolated static func singleFileRoot(at url: URL) async throws -> FileNode {
        try await Task.detached {
            do {
                guard try url.canonicalFileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else {
                    throw ProjectScanError.unavailable
                }
            } catch {
                throw ProjectScanError.resourceFailure(error)
            }
            let file = url.canonicalDocumentURL
            let parent = file.deletingLastPathComponent()
            return FileNode(url: parent, name: parent.lastPathComponent, isDirectory: true,
                            children: [FileNode(url: file, name: file.lastPathComponent, isDirectory: false, children: nil)])
        }.value
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

        guard let path = relativePath(for: node.url.canonicalDocumentURL, in: root.url) else { return }
        if storedFavoritePaths.contains(path) {
            storedFavoritePaths.remove(path)
        } else {
            storedFavoritePaths.insert(path)
        }
        favoriteFileURLs = Set(storedFavoritePaths.compactMap { filesByRelativePath[$0]?.url })
        persistFavorites(for: root)
        rebuildDisplayedNodes()
    }

    func isFavorite(_ node: FileNode) -> Bool {
        favoriteFileURLs.contains(node.url.canonicalDocumentURL)
    }

    private func stopCurrentSecurityScopeIfNeeded() {
        if let current = securityScopedURL {
            resourceAccess.stopAccessing(current)
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

        let allFilesByRelativePath = filesByRelativePath
        let storedPaths = storedFavoritePaths
        favoriteFileURLs = Set(
            storedPaths.compactMap { allFilesByRelativePath[$0]?.url }
        )
        persistFavorites(for: root)
        rebuildDisplayedNodes()
    }

    private func persistFavorites(for root: FileNode) {
        let relativePaths = storedFavoritePaths.sorted()

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
        case ProjectScanError.missing:
            return "Couldn't find the selected location. It may be temporarily unavailable."
        case ProjectScanError.accessDenied:
            return "Couldn't access the selected location. Check your permission and reopen it."
        case is ProjectScanError:
            return "Couldn't read the selected location. Check that it is available and you have permission to access it."
        default:
            return "An unexpected project access error occurred."
        }
    }

    @discardableResult
    func bootstrapSidebarForUITestingIfRequested(environment env: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        guard root == nil else { return false }
        guard env["MARKY_UI_TEST_SEED"] == "1" else { return false }

        let fixtureURL: URL?
        do {
            if env["MARKY_UI_TEST_PROJECT_PATH"] == nil || env["MARKY_UI_TEST_FIXTURE_JSON"] != nil {
                let id = env["MARKY_UI_TEST_FIXTURE_ID"] ?? UUID().uuidString
                guard UUID(uuidString: id) != nil else { throw ProjectScanError.unavailable }
                let documents: [String: String]
                if let json = env["MARKY_UI_TEST_FIXTURE_JSON"] {
                    guard let data = json.data(using: .utf8) else { throw ProjectScanError.unavailable }
                    documents = try JSONDecoder().decode([String: String].self, from: data)
                } else {
                    documents = ["README.md": "# Welcome\n\nReader fixture.", "MEMORY.md": "# Memory", "docs/GUIDE.md": "# Guide"]
                }
                let folder = FileManager.default.temporaryDirectory.appendingPathComponent("MarkyUITests-" + id, isDirectory: true).canonicalFileURL
                ownedUITestFixtureURL = folder
                for (relativePath, text) in documents {
                    let document = folder.appendingPathComponent(relativePath).standardizedFileURL
                    guard !relativePath.hasPrefix("/"), document.path.hasPrefix(folder.path + "/") else {
                        throw ProjectScanError.unavailable
                    }
                    try FileManager.default.createDirectory(at: document.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try text.write(to: document, atomically: true, encoding: .utf8)
                }
                fixtureURL = folder
            } else {
                fixtureURL = env["MARKY_UI_TEST_PROJECT_PATH"].map { URL(fileURLWithPath: $0, isDirectory: true) }
            }
        } catch {
            errorMessage = "Couldn't prepare the UI test project."
            return true
        }
        if let folder = fixtureURL {
            openPickedFolder(folder)
            let seedRequestID = projectLoadID
            Task { [weak self] in
                await self?.waitForProjectLoad()
                guard let self, self.projectLoadID == seedRequestID, self.root?.url == folder.canonicalFileURL else { return }
                self.selectedURL = folder.appendingPathComponent("README.md").canonicalDocumentURL
            }
            return true
        }

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
            SidebarSection(kind: .favorites, title: String(localized: "Favorites"), nodes: favoriteNodes),
            SidebarSection(kind: .files, title: String(localized: "Files"), nodes: filteredNodes)
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
        filesByRelativePath.values
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
        // Published project trees already carry canonical identities. Path math
        // here must stay cheap: search and indexing must not resolve the filesystem.
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
