//
//  MarkyTests.swift
//  MarkyTests
//
//  Created by Predrag Drljaca on 3/5/26.
//

import Foundation
import Testing
import SwiftUI
@testable import Marky
#if os(macOS)
import AppKit
import Darwin
#endif

struct MarkyTests {
    private final class ThrowingProjectSessionService: ProjectSessionServicing {
        let saveError: Error?
        let restoreError: Error?

        init(saveError: Error? = nil, restoreError: Error? = nil) {
            self.saveError = saveError
            self.restoreError = restoreError
        }

        func saveBookmark(for url: URL) throws {
            if let saveError { throw saveError }
        }

        func restoreBookmarkedURL() throws -> RestoredProjectBookmark? {
            if let restoreError { throw restoreError }
            return nil
        }

        func clearBookmark() {}
    }

    private final class InMemoryFavoritesStore: ProjectFavoritesStoring {
        var favoritesByProject: [String: [String]] = [:]

        func favoriteRelativePaths(for projectURL: URL) -> [String] {
            favoritesByProject[projectURL.canonicalFileURL.path] ?? []
        }

        func saveFavoriteRelativePaths(_ relativePaths: [String], for projectURL: URL) {
            favoritesByProject[projectURL.canonicalFileURL.path] = relativePaths
        }

        func clearFavorites(for projectURL: URL) {
            favoritesByProject.removeValue(forKey: projectURL.canonicalFileURL.path)
        }
    }

    @MainActor
    @Test("buildProjectTree keeps markdown files and directories that contain them")
    func buildProjectTreeFiltersNonMarkdownFiles() async throws {
        try await Self.withTemporaryDirectory { root in
            let docs = root.appendingPathComponent("docs", isDirectory: true)
            let nested = docs.appendingPathComponent("nested", isDirectory: true)
            let images = root.appendingPathComponent("images", isDirectory: true)
            try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: images, withIntermediateDirectories: true)

            try "# Guide".write(to: docs.appendingPathComponent("guide.md"), atomically: true, encoding: .utf8)
            try "plain text".write(to: docs.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)
            try "Nested markdown".write(to: nested.appendingPathComponent("nested.markdown"), atomically: true, encoding: .utf8)
            try "not markdown".write(to: images.appendingPathComponent("photo.png"), atomically: true, encoding: .utf8)

            let tree = try FileNode.buildProjectTree(at: root)
            let rootChildren = tree.children ?? []

            let docsNode = rootChildren.first(where: { $0.name == "docs" && $0.isDirectory })
            #expect(docsNode != nil)
            #expect(rootChildren.contains(where: { $0.name == "images" }) == false)
            #expect(docsNode?.children?.contains(where: { $0.name == "guide.md" && !$0.isDirectory }) == true)
            #expect(docsNode?.children?.contains(where: { $0.name == "notes.txt" }) == false)
            #expect(docsNode?.children?.contains(where: { $0.name == "nested" && $0.isDirectory }) == true)
        }
    }

    @MainActor
    @Test("restoreBookmarkIfNeeded maps typed bookmark resolution failures to user-safe message")
    func restoreBookmarkIfNeededMapsBookmarkResolutionFailure() {
        let service = ThrowingProjectSessionService(restoreError: ProjectSessionError.bookmarkResolutionFailed)
        let viewModel = ContentViewModel(projectSessionService: service)

        viewModel.restoreBookmarkIfNeeded()

        #expect(viewModel.errorMessage == "Couldn't restore the last opened project.")
    }

    @MainActor
    @Test("openPickedFolder maps typed bookmark encoding failures to user-safe message")
    func openPickedFolderMapsBookmarkEncodingFailure() async throws {
        let service = ThrowingProjectSessionService(saveError: ProjectSessionError.bookmarkEncodingFailed)
        let viewModel = ContentViewModel(projectSessionService: service)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("A3-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        viewModel.openPickedFolder(folder)
        await viewModel.waitForProjectLoad()

        #expect(viewModel.errorMessage == "Couldn't save project access. You may need to reopen this location next time.")
    }

    @MainActor
    @Test("handleFileImporterResult routes picked URL by mode and clears import mode")
    func handleFileImporterResultRoutesAndClearsMode() async throws {
        let service = ThrowingProjectSessionService()
        let viewModel = ContentViewModel(projectSessionService: service)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("A4-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        viewModel.importMode = .folder
        viewModel.handleFileImporterResult(.success([folder]))
        await viewModel.waitForProjectLoad()

        #expect(viewModel.importMode == nil)
        #expect(viewModel.root?.url == folder.canonicalFileURL)
        #expect(viewModel.selectedURL == nil)
    }

    @MainActor
    @Test("handleFileImporterResult maps failures and clears import mode")
    func handleFileImporterResultMapsFailureAndClearsMode() {
        enum ImportFailure: Error { case failed }

        let service = ThrowingProjectSessionService()
        let viewModel = ContentViewModel(projectSessionService: service)
        viewModel.importMode = .file

        viewModel.handleFileImporterResult(.failure(ImportFailure.failed))

        #expect(viewModel.importMode == nil)
        #expect(viewModel.errorMessage?.contains("Couldn't import the selected item.") == true)
    }

    @Test("appearance mode maps to expected color scheme override")
    func appearanceModeMapsToColorScheme() {
        #expect(AppAppearanceMode.system.colorScheme == nil)
        #expect(AppAppearanceMode.light.colorScheme == .light)
        #expect(AppAppearanceMode.dark.colorScheme == .dark)
    }

    @MainActor
    @Test("selectNode toggles folder expansion and collapseAll clears expanded folders")
    func selectNodeTogglesFolderExpansion() {
        let service = ThrowingProjectSessionService()
        let viewModel = ContentViewModel(projectSessionService: service)
        let folderURL = URL(fileURLWithPath: "/tmp/a5-folder", isDirectory: true)
        let folder = FileNode(url: folderURL, name: "a5-folder", isDirectory: true, children: [])

        #expect(viewModel.expandedFolderURLs.contains(folderURL) == false)
        viewModel.selectNode(folder)
        #expect(viewModel.expandedFolderURLs.contains(folderURL) == true)
        viewModel.selectNode(folder)
        #expect(viewModel.expandedFolderURLs.contains(folderURL) == false)

        viewModel.selectNode(folder)
        #expect(viewModel.expandedFolderURLs.contains(folderURL) == true)
        viewModel.collapseAllSidebarFolders()
        #expect(viewModel.expandedFolderURLs.isEmpty)
    }

    @MainActor
    @Test("sidebar sections can collapse and expand independently")
    func sidebarSectionsToggleIndependently() {
        let service = ThrowingProjectSessionService()
        let viewModel = ContentViewModel(projectSessionService: service)

        #expect(viewModel.isSidebarSectionCollapsed(.favorites) == false)
        #expect(viewModel.isSidebarSectionCollapsed(.files) == false)

        viewModel.toggleSidebarSection(.favorites)
        #expect(viewModel.isSidebarSectionCollapsed(.favorites) == true)
        #expect(viewModel.isSidebarSectionCollapsed(.files) == false)

        viewModel.toggleSidebarSection(.files)
        #expect(viewModel.isSidebarSectionCollapsed(.favorites) == true)
        #expect(viewModel.isSidebarSectionCollapsed(.files) == true)

        viewModel.toggleSidebarSection(.favorites)
        #expect(viewModel.isSidebarSectionCollapsed(.favorites) == false)
        #expect(viewModel.isSidebarSectionCollapsed(.files) == true)
    }

    @MainActor
    @Test("displayedNodes updates only from root and search query changes")
    func displayedNodesTracksRootAndSearchQuery() {
        let service = ThrowingProjectSessionService()
        let viewModel = ContentViewModel(projectSessionService: service)

        let readme = FileNode(url: URL(fileURLWithPath: "/tmp/README.md"), name: "README.md", isDirectory: false, children: nil)
        let guide = FileNode(url: URL(fileURLWithPath: "/tmp/docs/GUIDE.md"), name: "GUIDE.md", isDirectory: false, children: nil)
        let docs = FileNode(url: URL(fileURLWithPath: "/tmp/docs"), name: "docs", isDirectory: true, children: [guide])

        viewModel.root = FileNode(
            url: URL(fileURLWithPath: "/tmp/root"),
            name: "root",
            isDirectory: true,
            children: [readme, docs]
        )

        #expect(viewModel.displayedNodes.count == 2)

        viewModel.sidebarSearchText = "guide"
        #expect(viewModel.displayedNodes.count == 1)
        #expect(viewModel.displayedNodes.first?.name == "docs")
        #expect(viewModel.displayedNodes.first?.children?.first?.name == "GUIDE.md")

        let beforeSelection = viewModel.displayedNodes
        viewModel.selectedURL = readme.url
        #expect(viewModel.displayedNodes == beforeSelection)
    }

    @MainActor
    @Test("favorites persist as project-relative paths and restore for reopened project")
    func favoritesPersistAndRestoreForProject() async throws {
        let service = ThrowingProjectSessionService()
        let favoritesStore = InMemoryFavoritesStore()

        try await Self.withTemporaryDirectory { root in
            let docs = root.appendingPathComponent("docs", isDirectory: true)
            try FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)

            let readme = root.appendingPathComponent("README.md")
            let guide = docs.appendingPathComponent("GUIDE.md")
            try "# Readme".write(to: readme, atomically: true, encoding: .utf8)
            try "# Guide".write(to: guide, atomically: true, encoding: .utf8)

            let firstViewModel = ContentViewModel(projectSessionService: service, favoritesStore: favoritesStore)
            firstViewModel.openPickedFolder(root)
            await firstViewModel.waitForProjectLoad()

            let readmeNode = firstViewModel.displayedNodes.first(where: { $0.url == readme })
            #expect(readmeNode != nil)
            if let readmeNode {
                firstViewModel.toggleFavorite(for: readmeNode)
            }

            #expect(favoritesStore.favoriteRelativePaths(for: root) == ["README.md"])

            let restoredViewModel = ContentViewModel(projectSessionService: service, favoritesStore: favoritesStore)
            restoredViewModel.openPickedFolder(root)
            await restoredViewModel.waitForProjectLoad()

            #expect(restoredViewModel.favoriteFileURLs.contains(readme))
            #expect(restoredViewModel.displayedSections.first?.title == "Favorites")
            #expect(restoredViewModel.displayedSections.first?.nodes.map(\.url) == [readme])

            if let restoredReadme = restoredViewModel.displayedSections.first?.nodes.first {
                restoredViewModel.toggleFavorite(for: restoredReadme)
            }

            #expect(restoredViewModel.favoriteFileURLs.isEmpty)
            #expect(restoredViewModel.displayedSections.first?.nodes.isEmpty == true)
            #expect(favoritesStore.favoriteRelativePaths(for: root).isEmpty)
        }
    }

    @MainActor
    @Test("missing favorite files are removed from persisted project favorites")
    func missingFavoritesArePrunedWhenProjectOpens() async throws {
        let service = ThrowingProjectSessionService()
        let favoritesStore = InMemoryFavoritesStore()

        try await Self.withTemporaryDirectory { root in
            let readme = root.appendingPathComponent("README.md")
            try "# Readme".write(to: readme, atomically: true, encoding: .utf8)
            favoritesStore.saveFavoriteRelativePaths(["README.md", "REMOVED.md"], for: root)

            let viewModel = ContentViewModel(projectSessionService: service, favoritesStore: favoritesStore)
            viewModel.openPickedFolder(root)
            await viewModel.waitForProjectLoad()

            #expect(viewModel.favoriteFileURLs == [readme])
            #expect(favoritesStore.favoriteRelativePaths(for: root) == ["README.md"])
        }
    }

    @MainActor
    @Test("favorites section remains visible and filters by search query")
    func favoritesSectionRemainsVisibleAndFiltersBySearch() async throws {
        let service = ThrowingProjectSessionService()
        let favoritesStore = InMemoryFavoritesStore()

        try await Self.withTemporaryDirectory { root in
            let guide = root.appendingPathComponent("GUIDE.md")
            let notes = root.appendingPathComponent("NOTES.md")
            try "# Guide".write(to: guide, atomically: true, encoding: .utf8)
            try "# Notes".write(to: notes, atomically: true, encoding: .utf8)

            favoritesStore.saveFavoriteRelativePaths(["GUIDE.md"], for: root)

            let viewModel = ContentViewModel(projectSessionService: service, favoritesStore: favoritesStore)
            viewModel.openPickedFolder(root)
            await viewModel.waitForProjectLoad()

            #expect(viewModel.displayedSections.map(\.title) == ["Favorites", "Files"])
            #expect(viewModel.displayedSections[0].nodes.map(\.url) == [guide])

            viewModel.sidebarSearchText = "notes"

            #expect(viewModel.displayedSections[0].title == "Favorites")
            #expect(viewModel.displayedSections[0].nodes.isEmpty)
            #expect(viewModel.displayedSections[1].nodes.count == 1)
            #expect(viewModel.displayedSections[1].nodes.first?.url == notes)
        }
    }

    @MainActor
    @Test("buildProjectTree skips symbolic-link directories to prevent recursive cycles")
    func buildProjectTreeSkipsDirectorySymlinks() async throws {
        try await Self.withTemporaryDirectory { root in
            let notes = root.appendingPathComponent("notes", isDirectory: true)
            try FileManager.default.createDirectory(at: notes, withIntermediateDirectories: true)

            try "- item".write(to: notes.appendingPathComponent("todo.md"), atomically: true, encoding: .utf8)

            let loop = notes.appendingPathComponent("loop", isDirectory: true)
            try FileManager.default.createSymbolicLink(atPath: loop.path, withDestinationPath: root.path)

            let tree = try FileNode.buildProjectTree(at: root)
            let notesNode = tree.children?.first(where: { $0.name == "notes" && $0.isDirectory })

            #expect(notesNode != nil)
            #expect(notesNode?.children?.contains(where: { $0.name == "todo.md" && !$0.isDirectory }) == true)
            #expect(notesNode?.children?.contains(where: { $0.name == "loop" }) == false)
        }
    }

    @MainActor
    private final class RecordingResourceAccess: ProjectResourceAccessing {
        var allowAccess = true
        var allowedURLs: Set<URL>?
        var starts: [URL] = []
        var stops: [URL] = []
        var onStart: (() -> Void)?
        func startAccessing(_ url: URL) -> Bool {
            starts.append(url)
            onStart?()
            return allowedURLs?.contains(url) ?? allowAccess
        }
        func stopAccessing(_ url: URL) { stops.append(url) }
    }

    private final class RestoringSession: ProjectSessionServicing {
        let url: URL
        var cleared = false
        var restoreCalls = 0
        init(url: URL) { self.url = url }
        func restoreBookmarkedURL() throws -> RestoredProjectBookmark? {
            restoreCalls += 1
            return RestoredProjectBookmark(url: url, isStale: false)
        }
        func saveBookmark(for url: URL) throws {}
        func clearBookmark() { cleared = true }
    }

    private actor SuspendedScan {
        var requests: [URL: CheckedContinuation<FileNode, Error>] = [:]
        func scan(_ url: URL) async throws -> FileNode {
            try await withCheckedThrowingContinuation { requests[url] = $0 }
        }
        func hasRequest(_ url: URL) -> Bool { requests[url] != nil }
        func fail(_ url: URL) {
            requests.removeValue(forKey: url)?.resume(throwing: ProjectScanError.unreadableDirectory)
        }
        func finish(_ url: URL) {
            requests.removeValue(forKey: url)?.resume(returning:
                FileNode(url: url, name: url.lastPathComponent, isDirectory: true, children: []))
        }
    }

    private actor SuspendedFavoriteProbe {
        private var shouldSuspend = false
        private var continuation: CheckedContinuation<Set<String>, Never>?
        func arm() { shouldSuspend = true }
        func isPending() -> Bool { continuation != nil }
        func probe() async -> Set<String> {
            guard shouldSuspend else { return [] }
            return await withCheckedContinuation { continuation = $0 }
        }
        func finish(missing: Set<String>) {
            continuation?.resume(returning: missing)
            continuation = nil
        }
    }

    @MainActor
    @Test("reopening preserves favorite edits made while missing-file checks are pending")
    func favoriteEditsDuringReopenArePreserved() async throws {
        try await Self.withTemporaryDirectory { root in
            let readme = root.appendingPathComponent("README.md")
            let guide = root.appendingPathComponent("GUIDE.md")
            try "# Readme".write(to: readme, atomically: true, encoding: .utf8)
            try "# Guide".write(to: guide, atomically: true, encoding: .utf8)
            let store = InMemoryFavoritesStore()
            store.saveFavoriteRelativePaths(["README.md", "DELETED.md"], for: root)
            let probe = SuspendedFavoriteProbe()
            let model = ContentViewModel(projectSessionService: ThrowingProjectSessionService(), favoritesStore: store,
                                         probeMissingFavorites: { _, _ in await probe.probe() })
            model.openPickedFolder(root)
            await model.waitForProjectLoad()
            let readmeNode = try #require(model.displayedNodes.first { $0.url == readme })
            let guideNode = try #require(model.displayedNodes.first { $0.url == guide })
            await probe.arm()
            model.openPickedFolder(root)
            while !(await probe.isPending()) { await Task.yield() }
            model.toggleFavorite(for: readmeNode)
            model.toggleFavorite(for: guideNode)
            // An independent window can also update the shared store while this
            // window's previous project remains interactive.
            store.saveFavoriteRelativePaths(store.favoriteRelativePaths(for: root) + ["NEW-UNKNOWN.txt"], for: root)
            await probe.finish(missing: ["DELETED.md"])
            await model.waitForProjectLoad()
            #expect(store.favoriteRelativePaths(for: root) == ["GUIDE.md", "NEW-UNKNOWN.txt"])
            #expect(model.favoriteFileURLs == [guide])
        }
    }

    @MainActor
    @Test("single-file opens and favorite toggles preserve favorites outside the partial view")
    func partialProjectPreservesFavorites() async throws {
        try await Self.withTemporaryDirectory { root in
            let readme = root.appendingPathComponent("README.md")
            try "Readme".write(to: readme, atomically: true, encoding: .utf8)
            let store = InMemoryFavoritesStore()
            store.saveFavoriteRelativePaths(["README.md", "GUIDE.md"], for: root)
            let access = RecordingResourceAccess()
            access.allowAccess = false
            let model = ContentViewModel(projectSessionService: ThrowingProjectSessionService(), favoritesStore: store, resourceAccess: access)
            model.openPickedFile(readme)
            await model.waitForProjectLoad()
            #expect(store.favoriteRelativePaths(for: root) == ["GUIDE.md", "README.md"])
            let node = try #require(model.root?.children?.first)
            model.toggleFavorite(for: node)
            #expect(store.favoriteRelativePaths(for: root) == ["GUIDE.md"])
            model.toggleFavorite(for: node)
            #expect(store.favoriteRelativePaths(for: root) == ["GUIDE.md", "README.md"])
        }
    }

    @MainActor
    @Test("a picked file survives parent scan failure without pruning sibling favorites")
    func pickedFileFallsBackAfterParentScanFailure() async throws {
        try await Self.withTemporaryDirectory { root in
            let file = root.appendingPathComponent("README.md")
            try "Readme".write(to: file, atomically: true, encoding: .utf8)
            let store = InMemoryFavoritesStore()
            store.saveFavoriteRelativePaths(["README.md", "SIBLING.md"], for: root)
            let access = RecordingResourceAccess()
            let model = ContentViewModel(projectSessionService: ThrowingProjectSessionService(), favoritesStore: store,
                                         resourceAccess: access, scanProject: { _ in throw ProjectScanError.unreadableDirectory })
            model.openPickedFile(file)
            await model.waitForProjectLoad()
            #expect(model.root?.children?.map(\.url) == [file])
            #expect(model.selectedURL == file)
            #expect(store.favoriteRelativePaths(for: root) == ["README.md", "SIBLING.md"])
            #expect(access.starts == [root, file])
            #expect(access.stops == [root])
            model.closeProject()
            #expect(access.stops == [root, file])
        }
    }

    @MainActor
    @Test("failed scans retain current project and saved favorites, and balance candidate scope")
    func failedScanRetainsCurrentProject() async throws {
        try await Self.withTemporaryDirectory { root in
            let readme = root.appendingPathComponent("README.md")
            try "Readme".write(to: readme, atomically: true, encoding: .utf8)
            let store = InMemoryFavoritesStore()
            let access = RecordingResourceAccess()
            store.saveFavoriteRelativePaths(["README.md"], for: root)
            let model = ContentViewModel(projectSessionService: ThrowingProjectSessionService(), favoritesStore: store, resourceAccess: access)
            model.openPickedFolder(root)
            await model.waitForProjectLoad()
            let missing = root.appendingPathComponent("unavailable")
            store.saveFavoriteRelativePaths(["SAVED.md"], for: missing)
            model.openPickedFolder(missing)
            await model.waitForProjectLoad()
            #expect(model.root?.url == root)
            #expect(model.favoriteFileURLs == [readme])
            #expect(store.favoriteRelativePaths(for: missing) == ["SAVED.md"])
            #expect(access.stops == [missing])
            #expect(model.errorMessage != nil)
            model.closeProject()
            #expect(access.stops == [missing, root])
        }
    }

    @MainActor
    @Test("restoration activates granted scope before checking the resource and retains unavailable bookmarks")
    func restorationAccessOrderAndUnavailableBookmark() async throws {
        try await Self.withTemporaryDirectory { root in
            let folder = root.appendingPathComponent("restored", isDirectory: true)
            let session = RestoringSession(url: folder)
            let access = RecordingResourceAccess()
            access.onStart = {
                do { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true) }
                catch { Issue.record("Could not create restoration fixture: \(error)") }
            }
            let model = ContentViewModel(projectSessionService: session, resourceAccess: access)
            model.restoreBookmarkIfNeeded()
            await model.waitForProjectLoad()
            #expect(model.root?.url == folder)
            #expect(access.starts == [folder])
            model.closeProject()
            #expect(access.stops == [folder])

            let unavailable = RestoringSession(url: root.appendingPathComponent("absent"))
            let failingAccess = RecordingResourceAccess()
            let failing = ContentViewModel(projectSessionService: unavailable, resourceAccess: failingAccess)
            failing.restoreBookmarkIfNeeded()
            await failing.waitForProjectLoad()
            #expect(failing.root == nil)
            #expect(!unavailable.cleared)
            #expect(failingAccess.stops == failingAccess.starts)
        }
    }

    @MainActor
    @Test("canonical project aliases share favorites while scope keeps the granted URL")
    func projectAliasesShareIdentity() async throws {
        try await Self.withTemporaryDirectory { root in
            let project = root.appendingPathComponent("project", isDirectory: true)
            try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
            let file = project.appendingPathComponent("README.md")
            try "Readme".write(to: file, atomically: true, encoding: .utf8)
            let alias = root.appendingPathComponent("alias", isDirectory: true)
            try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: project)
            let store = InMemoryFavoritesStore()
            store.saveFavoriteRelativePaths(["README.md"], for: alias)
            let access = RecordingResourceAccess()
            let model = ContentViewModel(projectSessionService: ThrowingProjectSessionService(), favoritesStore: store, resourceAccess: access)
            model.openPickedFolder(alias)
            await model.waitForProjectLoad()
            #expect(model.root?.url == project)
            #expect(model.favoriteFileURLs == [file])
            #expect(model.isFavorite(FileNode(url: alias.appendingPathComponent("README.md"), name: "README.md", isDirectory: false)))
            model.closeProject()
            #expect(access.starts == [alias])
            #expect(access.stops == [alias])
        }
    }

    @MainActor
    @Test("Markdown file links retain distinct project-local identities and favorites")
    func linkedDocumentsKeepDistinctIdentity() async throws {
        try await Self.withTemporaryDirectory { root in
            let target = root.appendingPathComponent("README.md")
            let linked = root.appendingPathComponent("LINK.md")
            try "Readme".write(to: target, atomically: true, encoding: .utf8)
            try FileManager.default.createSymbolicLink(at: linked, withDestinationURL: target)
            try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("loop"), withDestinationURL: root)
            // Unrelated dangling links must not make a Markdown project unreadable.
            try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("broken.txt"),
                                                       withDestinationURL: root.appendingPathComponent("absent.txt"))
            try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("directory.md"), withDestinationURL: root)
            let store = InMemoryFavoritesStore()
            let model = ContentViewModel(projectSessionService: ThrowingProjectSessionService(), favoritesStore: store)
            model.openPickedFolder(root)
            await model.waitForProjectLoad()
            #expect(Set(model.displayedNodes.map(\.id)) == [target, linked])
            let linkNode = try #require(model.displayedNodes.first { $0.url == linked })
            model.toggleFavorite(for: linkNode)
            #expect(store.favoriteRelativePaths(for: root) == ["LINK.md"])
            #expect(!model.isFavorite(FileNode(url: target, name: "README.md", isDirectory: false)))
            model.openPickedFolder(root)
            await model.waitForProjectLoad()
            #expect(model.favoriteFileURLs == [linked])
            #expect(model.displayedSections.first?.nodes.map(\.url) == [linked])
        }
    }

    @MainActor
    @Test("favorites store preserves legacy granted-path keys when opened through a canonical alias")
    func favoritesStoreMigratesAliasKeys() async throws {
        try await Self.withTemporaryDirectory { root in
            let project = root.appendingPathComponent("project", isDirectory: true)
            try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
            let alias = root.appendingPathComponent("alias", isDirectory: true)
            try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: project)
            let suite = "MarkyTests.Favorites.\(UUID().uuidString)"
            let defaults = try #require(UserDefaults(suiteName: suite))
            defer { defaults.removePersistentDomain(forName: suite) }
            defaults.set([alias.path: ["README.md"]], forKey: "favorites")
            let store = ProjectFavoritesStore(userDefaults: defaults, favoritesByProjectKey: "favorites")
            // Only the current authorized alias is migrated; no historical paths are resolved.
            store.migrateFavorites(from: alias, to: project)
            #expect(store.favoriteRelativePaths(for: project) == ["README.md"])
            store.saveFavoriteRelativePaths(["GUIDE.md"], for: project)
            #expect(store.favoriteRelativePaths(for: alias) == ["GUIDE.md"])
            #expect(defaults.dictionary(forKey: "favorites")?[alias.path] == nil)
        }
    }

    @MainActor
    @Test("superseding or closing a scan prevents stale publication and releases candidate access")
    func supersedingAndClosingScans() async {
        let scanner = SuspendedScan()
        let access = RecordingResourceAccess()
        let model = ContentViewModel(projectSessionService: ThrowingProjectSessionService(), resourceAccess: access,
                                     scanProject: { try await scanner.scan($0) })
        let first = URL(fileURLWithPath: "/project-first")
        let second = URL(fileURLWithPath: "/project-second")
        model.openPickedFolder(first)
        while !(await scanner.hasRequest(first)) { await Task.yield() }
        model.openPickedFolder(second)
        while !(await scanner.hasRequest(second)) { await Task.yield() }
        await scanner.finish(second)
        await model.waitForProjectLoad()
        #expect(model.root?.url == second)
        await scanner.finish(first)
        while !access.stops.contains(first) { await Task.yield() }
        #expect(model.root?.url == second)
        model.openPickedFolder(first)
        while !(await scanner.hasRequest(first)) { await Task.yield() }
        model.closeProject()
        await scanner.finish(first)
        await model.waitForProjectLoad()
        #expect(model.root == nil)
        #expect(access.stops.filter { $0 == first }.count == 2)
        #expect(access.stops.filter { $0 == second }.count == 1)
    }

    @MainActor
    @Test("manual recursion skips Markdown packages and nonregular Markdown entries")
    func scannerSkipsPackagesAndSpecialFiles() async throws {
        try await Self.withTemporaryDirectory { root in
            let package = root.appendingPathComponent("Example.app", isDirectory: true)
            try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
            try "# Not a project file".write(to: package.appendingPathComponent("INTERNAL.md"), atomically: true, encoding: .utf8)
            var markdownPackage = root.appendingPathComponent("Package.md", isDirectory: true)
            try FileManager.default.createDirectory(at: markdownPackage, withIntermediateDirectories: true)
            try "# Internal".write(to: markdownPackage.appendingPathComponent("INTERNAL.md"), atomically: true, encoding: .utf8)
            var packageValues = URLResourceValues()
            packageValues.isPackage = true
            try markdownPackage.setResourceValues(packageValues)
            #expect(try markdownPackage.resourceValues(forKeys: [.isPackageKey]).isPackage == true)
            let readme = root.appendingPathComponent("README.md")
            try "# Readme".write(to: readme, atomically: true, encoding: .utf8)
            #if os(macOS)
            let fifo = root.appendingPathComponent("blocked.md")
            #expect(mkfifo(fifo.path, 0o600) == 0)
            try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("linked-fifo.md"), withDestinationURL: fifo)
            #endif
            let tree = try FileNode.buildProjectTree(at: root)
            #expect(tree.children?.map(\.url) == [readme])
        }
    }

    @MainActor
    @Test("an unreadable child makes a direct folder scan incomplete")
    func scannerReportsUnreadableChild() async throws {
        #if os(macOS)
        guard getuid() != 0 else { return }
        try await Self.withTemporaryDirectory { root in
            let child = root.appendingPathComponent("restricted", isDirectory: true)
            try FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
            try "# Hidden behind permission".write(to: child.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: child.path)
            defer {
                do { try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: child.path) }
                catch { Issue.record("Could not restore fixture permissions: \(error)") }
            }
            do {
                _ = try FileNode.buildProjectTree(at: root)
                Issue.record("Expected unreadable child scan failure")
            } catch {
                #expect(error as? ProjectScanError == .accessDenied)
            }
        }
        #endif
    }

    @MainActor
    @Test("partial fallback retains its parent grant when a separate file grant is unavailable")
    func partialFallbackRetainsParentScope() async throws {
        try await Self.withTemporaryDirectory { root in
            let file = root.appendingPathComponent("README.md")
            try "# Readme".write(to: file, atomically: true, encoding: .utf8)
            let access = RecordingResourceAccess()
            access.allowedURLs = [root]
            let model = ContentViewModel(projectSessionService: ThrowingProjectSessionService(), resourceAccess: access,
                                         scanProject: { _ in throw ProjectScanError.unreadableDirectory })
            model.openPickedFile(file)
            await model.waitForProjectLoad()
            #expect(model.selectedURL == file)
            #expect(model.root?.children?.map(\.url) == [file])
            #expect(access.starts == [root, file])
            #expect(access.stops.isEmpty)
            model.closeProject()
            #expect(access.stops == [root])
        }
    }

    @MainActor
    @Test("automatic restoration cannot replace an explicit pending open and retries after failure")
    func restorationRespectsPendingExplicitOpen() async {
        let scanner = SuspendedScan()
        let explicit = URL(fileURLWithPath: "/explicit-project")
        let restored = URL(fileURLWithPath: "/restored-project")
        let session = RestoringSession(url: restored)
        let access = RecordingResourceAccess()
        let model = ContentViewModel(projectSessionService: session, resourceAccess: access,
                                     scanProject: { try await scanner.scan($0) })
        model.openPickedFolder(explicit)
        while !(await scanner.hasRequest(explicit)) { await Task.yield() }
        model.restoreBookmarkIfNeeded()
        #expect(session.restoreCalls == 0)
        #expect(access.starts == [explicit])
        await scanner.fail(explicit)
        await model.waitForProjectLoad()
        model.restoreBookmarkIfNeeded()
        #expect(session.restoreCalls == 1)
        // Restoration first inspects real metadata, so this synthetic location fails safely.
        await model.waitForProjectLoad()
        #expect(access.starts == [explicit, restored])
        #expect(model.root == nil)
    }

    @MainActor
    @Test("complete scans retain excluded text and hidden favorites while pruning only confirmed missing files")
    func excludedFavoritesAreRetained() async throws {
        try await Self.withTemporaryDirectory { root in
            try "Text".write(to: root.appendingPathComponent("NOTES.txt"), atomically: true, encoding: .utf8)
            try "Hidden".write(to: root.appendingPathComponent(".hidden.md"), atomically: true, encoding: .utf8)
            try "Readme".write(to: root.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
            let store = InMemoryFavoritesStore()
            store.saveFavoriteRelativePaths(["NOTES.txt", ".hidden.md", "MISSING.md", "README.md"], for: root)
            let model = ContentViewModel(projectSessionService: ThrowingProjectSessionService(), favoritesStore: store)
            model.openPickedFolder(root)
            await model.waitForProjectLoad()
            #expect(store.favoriteRelativePaths(for: root) == [".hidden.md", "NOTES.txt", "README.md"])
            let node = try #require(model.displayedNodes.first)
            model.toggleFavorite(for: node)
            #expect(store.favoriteRelativePaths(for: root) == [".hidden.md", "NOTES.txt"])
        }
    }

    @MainActor
    @Test("authorized alias migration is dictionary-only and preserves unknown legacy locations")
    func favoritesAliasMigrationDefersUnknownLocations() throws {
        let suite = "MarkyTests.Favorites.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let canonical = URL(fileURLWithPath: "/canonical-project")
        let alias = URL(fileURLWithPath: "/authorized-alias")
        let unknown = "/Volumes/Disconnected/unknown-project"
        defaults.set([alias.path: ["ALIAS.md"], canonical.path: ["CURRENT.md"], unknown: ["KEEP.md"]], forKey: "favorites")
        let store = ProjectFavoritesStore(userDefaults: defaults, favoritesByProjectKey: "favorites")
        store.migrateFavorites(from: alias, to: canonical)
        #expect(store.favoriteRelativePaths(for: canonical) == ["ALIAS.md", "CURRENT.md"])
        #expect(store.favoriteRelativePaths(for: alias) == ["ALIAS.md", "CURRENT.md"])
        let reopened = ProjectFavoritesStore(userDefaults: defaults, favoritesByProjectKey: "favorites")
        #expect(reopened.favoriteRelativePaths(for: canonical) == ["ALIAS.md", "CURRENT.md"])
        reopened.clearFavorites(for: alias)
        #expect(store.favoriteRelativePaths(for: canonical).isEmpty)
        #expect(store.favoriteRelativePaths(for: alias).isEmpty)
        #expect(store.favoriteRelativePaths(for: URL(fileURLWithPath: unknown)) == ["KEEP.md"])
    }

    @MainActor
    @Test("default UI fixture uses real project-local documents and its cached favorites index")
    func defaultUIFixtureHasProjectLocalIdentity() async throws {
        let store = InMemoryFavoritesStore()
        let model = ContentViewModel(projectSessionService: ThrowingProjectSessionService(), favoritesStore: store)
        #expect(model.bootstrapSidebarForUITestingIfRequested(environment: ["MARKY_UI_TEST_SEED": "1"]))
        await model.waitForProjectLoad()
        let root = try #require(model.root)
        let readme = try #require(model.displayedNodes.first { $0.name == "README.md" })
        #expect(readme.url.deletingLastPathComponent() == root.url)
        #expect(try String(contentsOf: readme.url, encoding: .utf8).contains("Welcome"))
        model.toggleFavorite(for: readme)
        #expect(store.favoriteRelativePaths(for: root.url) == ["README.md"])
        #expect(model.displayedSections.first?.nodes.map(\.url) == [readme.url])
    }

    @MainActor
    @Test("deallocating a pending project request releases its candidate scope")
    func pendingRequestDeallocationBalancesAccess() async {
        let scanner = SuspendedScan()
        let access = RecordingResourceAccess()
        var model: ContentViewModel? = ContentViewModel(
            projectSessionService: ThrowingProjectSessionService(), resourceAccess: access,
            scanProject: { try await scanner.scan($0) })
        weak let weakModel = model
        let folder = URL(fileURLWithPath: "/pending-deallocation")
        model?.openPickedFolder(folder)
        while !(await scanner.hasRequest(folder)) { await Task.yield() }
        model = nil
        #expect(weakModel == nil)
        await scanner.finish(folder)
        while access.stops.isEmpty { await Task.yield() }
        #expect(access.stops == [folder])
    }

    #if os(macOS)
    @MainActor
    @Test("markdown renderer preserves paragraph breaks and keeps first heading flush")
    func markdownRendererPreservesParagraphBreaksAndKeepsFirstHeadingFlush() {
        let rendered = MarkdownRenderer.render(from: "# Title\n\nBody")
        #expect(rendered.string == "Title\n\nBody")

        let paragraph = rendered.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        #expect(paragraph != nil)
        #expect((paragraph?.paragraphSpacingBefore ?? -1) == 0)
    }

    @MainActor
    @Test("markdown renderer converts task/bullet list markers")
    func markdownRendererConvertsTaskAndBulletMarkers() {
        let rendered = MarkdownRenderer.render(from: "- [x] Done\n- [ ] Todo\n* Bullet\n• Existing")
        #expect(rendered.string == "☑ Done\n☐ Todo\n• Bullet\n• Existing")
    }

    @MainActor
    @Test("markdown renderer applies inline link and code transformations")
    func markdownRendererTransformsInlineElements() {
        let rendered = MarkdownRenderer.render(from: "A **bold** and `code` [site](https://example.com)")
        #expect(rendered.string == "A bold and code site")

        let nsString = rendered.string as NSString
        let siteRange = nsString.range(of: "site")
        let codeRange = nsString.range(of: "code")
        #expect(siteRange.location != NSNotFound)
        #expect(codeRange.location != NSNotFound)

        let linkValue = rendered.attribute(.link, at: siteRange.location, effectiveRange: nil)
        let linkURL = (linkValue as? URL) ?? (linkValue as? NSURL).flatMap { $0 as URL }
        #expect(linkURL?.absoluteString == "https://example.com")

        let codeBackground = rendered.attribute(.backgroundColor, at: codeRange.location, effectiveRange: nil)
        #expect(codeBackground != nil)
    }

    @MainActor
    @Test("markdown typography modes remain explicit and complete")
    func markdownTypographyModesAreComplete() {
        #expect(MarkdownTypographyMode.allCases.count == 3)
        #expect(MarkdownTypographyMode.allCases.contains(.allSystem))
        #expect(MarkdownTypographyMode.allCases.contains(.serifHeadingsSystemBody))
        #expect(MarkdownTypographyMode.allCases.contains(.systemHeadingsSerifBody))
    }

    @MainActor
    @Test("markdown reader text size presets remain explicit and complete")
    func markdownReaderTextSizePresetsAreComplete() {
        #expect(MarkdownReaderTextSizePreset.allCases.count == 3)
        #expect(MarkdownReaderTextSizePreset.allCases.contains(.slightlySmaller))
        #expect(MarkdownReaderTextSizePreset.allCases.contains(.default))
        #expect(MarkdownReaderTextSizePreset.allCases.contains(.slightlyBigger))
    }

    @MainActor
    @Test("serif body mode increases body point size")
    func markdownTypographySerifBodyModeIncreasesBodyPointSize() {
        let systemRendered = MarkdownRenderer.render(from: "Body", mode: .allSystem)
        let serifBodyRendered = MarkdownRenderer.render(from: "Body", mode: .systemHeadingsSerifBody)

        let systemFont = systemRendered.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        let serifBodyFont = serifBodyRendered.attribute(.font, at: 0, effectiveRange: nil) as? NSFont

        #expect(systemFont != nil)
        #expect(serifBodyFont != nil)
        #expect((serifBodyFont?.pointSize ?? 0) > (systemFont?.pointSize ?? 0))
    }

    @MainActor
    @Test("markdown heading scale keeps descending hierarchy")
    func markdownHeadingScaleIsDescending() {
        let rendered = MarkdownRenderer.render(from: "# H1\n## H2\n### H3", mode: .allSystem)
        let text = rendered.string as NSString
        let h1Range = text.range(of: "H1")
        let h2Range = text.range(of: "H2")
        let h3Range = text.range(of: "H3")

        #expect(h1Range.location != NSNotFound)
        #expect(h2Range.location != NSNotFound)
        #expect(h3Range.location != NSNotFound)

        let h1Font = rendered.attribute(.font, at: h1Range.location, effectiveRange: nil) as? NSFont
        let h2Font = rendered.attribute(.font, at: h2Range.location, effectiveRange: nil) as? NSFont
        let h3Font = rendered.attribute(.font, at: h3Range.location, effectiveRange: nil) as? NSFont

        #expect(h1Font != nil)
        #expect(h2Font != nil)
        #expect(h3Font != nil)
        #expect((h1Font?.pointSize ?? 0) > (h2Font?.pointSize ?? 0))
        #expect((h2Font?.pointSize ?? 0) > (h3Font?.pointSize ?? 0))
    }

    @MainActor
    @Test("reader text size presets scale body typography up and down subtly")
    func markdownReaderTextSizePresetsScaleBodyTypography() {
        let smallerRendered = MarkdownRenderer.render(
            from: "Body",
            mode: .allSystem,
            textSizePreset: .slightlySmaller
        )
        let defaultRendered = MarkdownRenderer.render(
            from: "Body",
            mode: .allSystem,
            textSizePreset: .default
        )
        let biggerRendered = MarkdownRenderer.render(
            from: "Body",
            mode: .allSystem,
            textSizePreset: .slightlyBigger
        )

        let smallerFont = smallerRendered.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        let defaultFont = defaultRendered.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        let biggerFont = biggerRendered.attribute(.font, at: 0, effectiveRange: nil) as? NSFont

        #expect(smallerFont != nil)
        #expect(defaultFont != nil)
        #expect(biggerFont != nil)
        #expect((smallerFont?.pointSize ?? 0) < (defaultFont?.pointSize ?? 0))
        #expect((defaultFont?.pointSize ?? 0) < (biggerFont?.pointSize ?? 0))
        #expect(abs((defaultFont?.pointSize ?? 0) - 16) < 0.01)
    }

    @MainActor
    @Test("markdown renderer handles fenced code blocks as literal monospaced content")
    func markdownRendererHandlesFencedCodeBlocks() {
        let rendered = MarkdownRenderer.render(from: "```swift\nlet x = **1**\n```")
        #expect(rendered.string == "let x = **1**")

        let font = rendered.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        let background = rendered.attribute(.backgroundColor, at: 0, effectiveRange: nil)
        #expect(font != nil)
        #expect(background != nil)
        #expect((font?.fontName.contains("Mono") ?? false) || (font?.fontName.contains("Menlo") ?? false))
    }

    @Test("markdown content blocks split prose and fenced code without parsing code markup")
    func markdownContentBlocksSplitFencedCode() {
        let blocks = MarkdownContentBlocks.parse(from: "Before\n\n```swift\nlet x = **1**\n```\n\nAfter")
        #expect(blocks.count == 3)

        if case .markdown(let before) = blocks[0] {
            #expect(before == "Before")
        } else {
            Issue.record("Expected markdown block before code fence")
        }

        if case .code(let code) = blocks[1] {
            #expect(code == "let x = **1**")
        } else {
            Issue.record("Expected code block between markdown blocks")
        }

        if case .markdown(let after) = blocks[2] {
            #expect(after == "After")
        } else {
            Issue.record("Expected markdown block after code fence")
        }
    }

    @Test("markdown content blocks prepare lightweight parsed blocks for rerendering")
    func markdownContentBlocksPrepareLightweightBlocks() {
        let blocks = MarkdownContentBlocks.prepare(
            from: "# Title\nBody line 1\nBody line 2\n\n1. one\n   - nested\n\n```swift\nlet x = 1\n```"
        )

        #expect(blocks.count == 4)

        if case .heading(let level, let source) = blocks[0].kind {
            #expect(level == 1)
            #expect(source == "Title")
        } else {
            Issue.record("Expected heading block first")
        }

        if case .paragraph(let source) = blocks[1].kind {
            #expect(source == "Body line 1 Body line 2")
        } else {
            Issue.record("Expected paragraph block second")
        }

        if case .list(let items) = blocks[2].kind {
            #expect(items.count == 2)
            #expect(items[0].marker == "1.")
            #expect(items[1].marker == "•")
            #expect(items[1].nestingLevel > items[0].nestingLevel)
        } else {
            Issue.record("Expected list block third")
        }

        if case .code(let source) = blocks[3].kind {
            #expect(source == "let x = 1")
        } else {
            Issue.record("Expected code block fourth")
        }
    }

    @MainActor
    @Test("markdown content blocks split prose into heading paragraph list and quote blocks")
    func markdownContentBlocksSplitProseRhythmBlocks() {
        let blocks = MarkdownContentBlocks.render(
            from: "# Title\nBody line 1\nBody line 2\n\n1. one\n   - nested\n2. two\n\n> quoted",
            mode: .allSystem,
            isDarkMode: false
        )

        #expect(blocks.count == 4)

        if case .heading(let level, _) = blocks[0].kind {
            #expect(level == 1)
        } else {
            Issue.record("Expected heading block first")
        }

        if case .paragraph(let text) = blocks[1].kind {
            #expect(String(text.characters) == "Body line 1 Body line 2")
        } else {
            Issue.record("Expected paragraph block second")
        }

        if case .list(let items) = blocks[2].kind {
            #expect(items.count == 3)
            #expect(items[0].marker == "1.")
            #expect(items[1].marker == "•")
            #expect(items[1].nestingLevel > items[0].nestingLevel)
            #expect(items[2].marker == "2.")
        } else {
            Issue.record("Expected list block third")
        }

        if case .quote = blocks[3].kind {
        } else {
            Issue.record("Expected quote block fourth")
        }
    }

    @MainActor
    @Test("light background token matches requested neutral OKLCH surface")
    func lightBackgroundTokenMatchesRequestedSurface() throws {
        let color = try #require(MarkyTheme.nsLightBackgroundBase.usingColorSpace(.sRGB))
        #expect(abs(color.redComponent - 0.97369) < 0.0001)
        #expect(abs(color.greenComponent - 0.97369) < 0.0001)
        #expect(abs(color.blueComponent - 0.97369) < 0.0001)
    }
    #endif

    @MainActor
    private static func withTemporaryDirectory(_ body: (URL) async throws -> Void) async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MarkyTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try await body(root.canonicalFileURL)
    }
}
