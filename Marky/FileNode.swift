import Foundation

public struct FileNode: Identifiable, Hashable, Equatable {
    public let url: URL
    public let name: String
    public let isDirectory: Bool
    public var children: [FileNode]?

    public var id: URL { url }
}

public extension FileNode {
    /// Build a project tree rooted at `rootURL`, including only directories that contain
    /// markdown files (recursively) and markdown files themselves.
    static func buildProjectTree(at rootURL: URL) -> FileNode {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        _ = fm.fileExists(atPath: rootURL.path, isDirectory: &isDir)
        let rootName = rootURL.lastPathComponent

        let children = isDir.boolValue ? childNodes(for: rootURL) : []
        return FileNode(url: rootURL, name: rootName, isDirectory: true, children: children)
    }
}

private extension FileNode {
    static func childNodes(for directoryURL: URL) -> [FileNode] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey], options: [.skipsPackageDescendants, .skipsSubdirectoryDescendants]) else {
            return []
        }

        var nodes: [FileNode] = []
        for url in contents {
            if isHidden(url) { continue }

            var isDir: ObjCBool = false
            fm.fileExists(atPath: url.path, isDirectory: &isDir)
            let name = url.lastPathComponent

            if isDir.boolValue {
                // Recursively build children for subdirectory
                let childChildren = childNodes(for: url)
                // Include directory only if it contains markdown files (directly or nested)
                if !childChildren.isEmpty {
                    nodes.append(FileNode(url: url, name: name, isDirectory: true, children: childChildren))
                }
            } else if isMarkdownFile(url) {
                nodes.append(FileNode(url: url, name: name, isDirectory: false, children: nil))
            }
        }

        // Sort: directories first, then files; name localized case-insensitive
        nodes.sort { a, b in
            if a.isDirectory != b.isDirectory {
                return a.isDirectory && !b.isDirectory
            }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
        return nodes
    }

    static func isHidden(_ url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys: [.isHiddenKey])
        return values?.isHidden == true || url.lastPathComponent.hasPrefix(".")
    }

    static func isMarkdownFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ["md", "markdown", "mdown", "mkd"].contains(ext)
    }
}
