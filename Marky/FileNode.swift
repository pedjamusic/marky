import Foundation

public struct FileNode: Identifiable, Hashable, Equatable, Sendable {
    public nonisolated let url: URL
    public nonisolated let name: String
    public nonisolated let isDirectory: Bool
    public nonisolated var children: [FileNode]?

    public nonisolated var id: URL { url }

    nonisolated static let markdownFileExtensions = ["md", "markdown", "mdown", "mkd"]
}

enum ProjectScanError: Error, Equatable, Sendable {
    case missing
    case accessDenied
    case unavailable
    case notDirectory
    case unreadableDirectory

    nonisolated static func resourceFailure(_ error: Error, fallback: ProjectScanError = .unavailable) -> ProjectScanError {
        let error = error as NSError
        guard error.domain == NSCocoaErrorDomain else { return fallback }
        switch error.code {
        case NSFileNoSuchFileError, NSFileReadNoSuchFileError: return .missing
        case NSFileReadNoPermissionError: return .accessDenied
        default: return fallback
        }
    }
}

extension URL {
    nonisolated var canonicalFileURL: URL { resolvingSymlinksInPath().standardizedFileURL }
    /// Resolve directory aliases while preserving a document's own symlink name.
    nonisolated var canonicalDocumentURL: URL {
        deletingLastPathComponent().canonicalFileURL.appendingPathComponent(lastPathComponent)
    }
}

public extension FileNode {
    /// A successful result represents a complete scan. Any unreadable subtree fails the scan.
    nonisolated static func buildProjectTree(at rootURL: URL) throws -> FileNode {
        try Task.checkCancellation()
        let root = rootURL.canonicalFileURL
        let values: URLResourceValues
        do {
            values = try root.resourceValues(forKeys: [.isDirectoryKey])
        } catch {
            throw ProjectScanError.resourceFailure(error)
        }
        guard values.isDirectory == true else { throw ProjectScanError.notDirectory }
        return FileNode(url: root, name: root.lastPathComponent, isDirectory: true,
                        children: try childNodes(for: root))
    }

    nonisolated static func loadProjectTree(at url: URL) async throws -> FileNode {
        let worker = Task.detached(priority: .userInitiated) {
            try buildProjectTree(at: url)
        }
        return try await withTaskCancellationHandler {
            try await worker.value
        } onCancel: {
            worker.cancel()
        }
    }
}

private extension FileNode {
    nonisolated static func childNodes(for directoryURL: URL) throws -> [FileNode] {
        try Task.checkCancellation()
        let contents: [URL]
        do {
            contents = try FileManager.default.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey, .isSymbolicLinkKey, .isPackageKey, .isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants, .skipsSubdirectoryDescendants]
            )
        } catch {
            throw ProjectScanError.resourceFailure(error, fallback: .unreadableDirectory)
        }

        var nodes: [FileNode] = []
        for url in contents {
            try Task.checkCancellation()
            if url.lastPathComponent.hasPrefix(".") { continue }
            let values: URLResourceValues
            do {
                values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isPackageKey, .isRegularFileKey])
            } catch {
                throw ProjectScanError.resourceFailure(error, fallback: .unreadableDirectory)
            }
            if values.isPackage == true { continue }
            // Never recurse through linked directories. Linked documents keep
            // their project-local spelling, distinct from their target's identity.
            if values.isSymbolicLink == true {
                guard markdownFileExtensions.contains(url.pathExtension.lowercased()) else { continue }
                do {
                    let target = try url.canonicalFileURL.resourceValues(forKeys: [.isRegularFileKey, .isPackageKey])
                    guard target.isRegularFile == true, target.isPackage != true else { continue }
                } catch {
                    throw ProjectScanError.resourceFailure(error, fallback: .unreadableDirectory)
                }
            }
            if values.isDirectory == true {
                let canonicalURL = url.canonicalFileURL
                let children = try childNodes(for: canonicalURL)
                if !children.isEmpty {
                    nodes.append(FileNode(url: canonicalURL, name: url.lastPathComponent, isDirectory: true, children: children))
                }
            } else if markdownFileExtensions.contains(url.pathExtension.lowercased()),
                      values.isRegularFile == true || values.isSymbolicLink == true {
                nodes.append(FileNode(url: url.canonicalDocumentURL, name: url.lastPathComponent, isDirectory: false, children: nil))
            }
        }
        return nodes.sorted { a, b in
            if a.isDirectory != b.isDirectory { return a.isDirectory }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }
}
