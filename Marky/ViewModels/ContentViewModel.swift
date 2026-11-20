import Foundation
import MarkyCore
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

    @Published private(set) var root: FileNode?
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
    private var projectIndex: ProjectIndex?
    private var orderedFavorites: [ProjectIndex.Favorite] = []
    private var sidebarSearchTask: Task<Void, Never>?
    private let ownedTestDefaultsSuite: String?
    private let skipAutomaticRestoration: Bool
    private let resourceAccess: ProjectResourceAccessing
    private let scanProject: @Sendable (URL) async throws -> ProjectIndex
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
        scanProject: @escaping @Sendable (URL) async throws -> ProjectIndex = { try await FileNode.loadProjectIndex(at: $0) },
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
        sidebarSearchTask?.cancel()
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
        projectIndex = nil
        orderedFavorites = []
        rebuildDisplayedNodes()
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
        await waitForSidebarSearch()
    }

    func waitForSidebarSearch() async {
        await sidebarSearchTask?.value
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
                let newIndex: ProjectIndex
                let selectedFile: URL?
                if isDirectory {
                    do {
                        newIndex = try await scanProject(grantedURL)
                        selectedFile = selectedOverride?.canonicalDocumentURL
                    } catch {
                        try Task.checkCancellation()
                        guard let selectedOverride else { throw error }
                        // A picked file remains usable when its parent's sibling
                        // subtree is unreadable. This fallback is explicitly partial.
                        let fileAccess = resourceAccess.startAccessing(selectedOverride)
                        do {
                            newIndex = try await ProjectIndex.singleFile(at: selectedOverride)
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
                    }
                } else {
                    newIndex = try await ProjectIndex.singleFile(at: grantedURL)
                    selectedFile = grantedURL.canonicalDocumentURL
                }
                try Task.checkCancellation()
                guard self?.projectLoadID == requestID else { return }
                let newRoot = newIndex.root
                // Only the originally opened directory grant can authorize its alias.
                let alias: URL? = mode == .folder && selectedOverride == nil && accessed
                    && grantedURL.standardizedFileURL.path != newRoot.url.path ? grantedURL : nil
                let saved = self?.favoritesStore.savedPaths(for: newRoot.url, authorizedAlias: alias)
                let missing: Set<String>
                if newIndex.scanState == MarkyProjectScanState(MARKY_PROJECT_SCAN_COMPLETE), let saved {
                    let unindexed = Set(saved.canonical + saved.alias).filter {
                        ProjectIndex.pathSegments($0) != nil && newIndex.favoriteIndex(for: $0) == nil
                    }
                    missing = try await probeMissingFavorites(unindexed, newRoot).intersection(unindexed)
                } else {
                    missing = []
                }
                try Task.checkCancellation()
                guard let self, requestID == self.projectLoadID else { return }
                // Read and write the latest defaults in one main-actor turn.
                let favoritePaths = try self.favoritesStore.reconcileFavorites(
                    for: newRoot.url, authorizedAlias: alias, confirmedMissing: missing, scanState: newIndex.scanState
                )
                self.stopCurrentSecurityScopeIfNeeded()
                if candidateAccess {
                    self.securityScopedURL = candidateURL
                    adoptedScope = true
                }
                self.publishSidebar(files: [], favorites: [])
                self.projectIndex = newIndex
                self.root = newRoot
                self.selectedURL = selectedFile
                self.expandedFolderURLs.removeAll()
                self.splitViewVisibility = .all
                self.reloadFavorites(favoritePaths, in: newIndex)
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
            var missing: Set<String> = []
            for path in paths {
                guard let segments = ProjectIndex.pathSegments(path) else { continue }
                var url = root.url
                for (index, segment) in segments.enumerated() {
                    try Task.checkCancellation()
                    url.appendPathComponent(segment)
                    do {
                        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                        if index < segments.count - 1 && (values.isDirectory != true || values.isSymbolicLink != false) {
                            break
                        }
                    } catch {
                        // Stop at inaccessible ancestors, and never descend through a link.
                        if ProjectScanError.resourceFailure(error) == .missing { missing.insert(path) }
                        break
                    }
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
        guard !node.isDirectory, let projectIndex,
              let path = projectIndex.relativePath(for: node.url) else { return }

        let url = projectIndex.root.url
        var paths = Set(favoritesStore.savedPaths(for: url, authorizedAlias: nil).canonical)
        if paths.remove(path) == nil { paths.insert(path) }
        let sorted = paths.sorted()
        favoritesStore.saveReconciledPaths(sorted, for: url, migrating: nil)
        reloadFavorites(sorted, in: projectIndex)
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

    private func reloadFavorites(_ paths: [String], in index: ProjectIndex) {
        orderedFavorites = index.orderedFavorites(paths)
        let nodes = index.favoriteNodes(orderedFavorites.map(\.index))
        favoriteFileURLs = Set(nodes.map(\.url))
        rebuildDisplayedNodes()
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
        sidebarSearchTask?.cancel()
        sidebarSearchTask = nil
        guard let index = projectIndex else {
            displayedNodes = []
            displayedSections = []
            return
        }

        let query = sidebarSearchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
        let favorites = orderedFavorites
        if query.isEmpty {
            publishSidebar(files: index.root.children ?? [], favorites: index.favoriteNodes(favorites.map(\.index)))
            return
        }

        sidebarSearchTask = Task { [weak self] in
            do {
                let token = try CoreCancellationToken { _ in ProjectScanError.unavailable }
                let worker = Task.detached(priority: .userInitiated) {
                    try index.search(query, favorites: favorites, token: token.handle)
                }
                let result = try await withTaskCancellationHandler {
                    try await worker.value
                } onCancel: {
                    token.request()
                    worker.cancel()
                }
                try Task.checkCancellation()
                self?.publishSidebar(files: result.files, favorites: result.favorites)
            } catch is CancellationError {
                // A more recent query or project owns the sidebar now.
            } catch {
                guard !Task.isCancelled else { return }
                self?.errorMessage = "Couldn't search this project."
            }
        }
    }

    private func publishSidebar(files: [FileNode], favorites: [FileNode]) {
        displayedNodes = files
        displayedSections = [
            SidebarSection(kind: .favorites, title: String(localized: "Favorites"), nodes: favorites),
            SidebarSection(kind: .files, title: String(localized: "Files"), nodes: files)
        ]
    }
}
