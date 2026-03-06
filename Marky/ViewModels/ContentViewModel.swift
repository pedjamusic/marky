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

    init(projectSessionService: ProjectSessionServicing = ProjectSessionService()) {
        self.projectSessionService = projectSessionService
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
                let values = try? restored.url.resourceValues(forKeys: [.isDirectoryKey])
                if values?.isDirectory == true {
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
                    projectSessionService.saveBookmark(for: restored.url)
                }
            } else {
                projectSessionService.clearBookmark()
            }
        } catch {
            projectSessionService.clearBookmark()
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
            projectSessionService.saveBookmark(for: folderURL)
            root = FileNode.buildProjectTree(at: folderURL)
            selectedURL = fileURL
            splitViewVisibility = .all
            return
        }

        let fileAccess = fileURL.startAccessingSecurityScopedResource()
        if fileAccess {
            securityScopedURL = fileURL
        }
        projectSessionService.saveBookmark(for: fileURL)
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
        projectSessionService.saveBookmark(for: folderURL)
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
}
