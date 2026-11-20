import Foundation
import MarkyCore

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
        try NativeProjectScan.build(at: rootURL, token: nil)
    }

    nonisolated static func loadProjectTree(at url: URL) async throws -> FileNode {
        try Task.checkCancellation()
        let token = try CoreCancellationToken { _ in ProjectScanError.unavailable }
        let worker = Task.detached(priority: .userInitiated) {
            try NativeProjectScan.build(at: url, token: token.handle)
        }
        return try await withTaskCancellationHandler {
            let tree = try await worker.value
            try Task.checkCancellation()
            return tree
        } onCancel: {
            token.request()
            worker.cancel()
        }
    }
}

private nonisolated enum NativeProjectScan {
    private struct Entry {
        let url: URL
        let name: String
        let nameExtension: String
        let parentIndex: Int
        let kind: MarkyProjectEntryKind
        let targetKind: MarkyProjectEntryKind
    }

    private static let entryKeys: Set<URLResourceKey> = [
        .isDirectoryKey, .isHiddenKey, .isSymbolicLinkKey, .isPackageKey, .isRegularFileKey
    ]

    static func build(at rootURL: URL, token: OpaquePointer?) throws -> FileNode {
        try Task.checkCancellation()
        let root = rootURL.canonicalFileURL
        let values: URLResourceValues
        do {
            values = try root.resourceValues(forKeys: [.isDirectoryKey])
        } catch {
            throw ProjectScanError.resourceFailure(error)
        }
        guard values.isDirectory == true else { throw ProjectScanError.notDirectory }

        var entries = [Entry(url: root, name: root.lastPathComponent, nameExtension: "", parentIndex: 0,
                             kind: MarkyProjectEntryKind(MARKY_PROJECT_ENTRY_DIRECTORY),
                             targetKind: MarkyProjectEntryKind(MARKY_PROJECT_ENTRY_UNKNOWN))]
        try enumerate(root, parentIndex: 0, entries: &entries)
        return try assemble(entries, token: token)
    }

    private static func enumerate(_ directory: URL, parentIndex: Int, entries: inout [Entry]) throws {
        try Task.checkCancellation()
        let contents: [URL]
        do {
            contents = try FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: Array(entryKeys),
                options: [.skipsHiddenFiles, .skipsPackageDescendants, .skipsSubdirectoryDescendants]
            )
        } catch {
            throw ProjectScanError.resourceFailure(error, fallback: .unreadableDirectory)
        }

        for url in contents {
            try Task.checkCancellation()
            let name = url.lastPathComponent
            if name.hasPrefix(".") { continue }
            let values = try readChildMetadata(at: url, keys: entryKeys)
            if values.isHidden == true { continue }

            let nameExtension = url.pathExtension
            let kind: MarkyProjectEntryKind
            switch values {
            case _ where values.isPackage == true: kind = MarkyProjectEntryKind(MARKY_PROJECT_ENTRY_PACKAGE)
            case _ where values.isSymbolicLink == true: kind = MarkyProjectEntryKind(MARKY_PROJECT_ENTRY_SYMLINK)
            case _ where values.isDirectory == true: kind = MarkyProjectEntryKind(MARKY_PROJECT_ENTRY_DIRECTORY)
            case _ where values.isRegularFile == true: kind = MarkyProjectEntryKind(MARKY_PROJECT_ENTRY_REGULAR_FILE)
            default: kind = MarkyProjectEntryKind(MARKY_PROJECT_ENTRY_OTHER)
            }

            let disposition = nameExtension.withCString { bytes in
                marky_project_classify_entry(MarkyProjectEntryMetadata(
                    name_extension: MarkyUtf8View(data: bytes, byte_count: nameExtension.utf8.count),
                    kind: kind, target_kind: MarkyProjectEntryKind(MARKY_PROJECT_ENTRY_UNKNOWN), is_hidden: 0
                ))
            }
            var targetKind = MarkyProjectEntryKind(MARKY_PROJECT_ENTRY_UNKNOWN)
            if disposition == MarkyProjectEntryDisposition(MARKY_PROJECT_ENTRY_NEEDS_TARGET_METADATA) {
                let target = try readChildMetadata(at: url.canonicalFileURL, keys: [.isRegularFileKey, .isPackageKey])
                if target.isPackage == true {
                    targetKind = MarkyProjectEntryKind(MARKY_PROJECT_ENTRY_PACKAGE)
                } else if target.isRegularFile == true {
                    targetKind = MarkyProjectEntryKind(MARKY_PROJECT_ENTRY_REGULAR_FILE)
                } else {
                    targetKind = MarkyProjectEntryKind(MARKY_PROJECT_ENTRY_OTHER)
                }
            } else if disposition == MarkyProjectEntryDisposition(MARKY_PROJECT_ENTRY_SKIP) {
                continue
            }

            let isDirectory = disposition == MarkyProjectEntryDisposition(MARKY_PROJECT_ENTRY_SCAN_DIRECTORY)
            let nativeURL = isDirectory ? url.canonicalFileURL : url.canonicalDocumentURL
            let index = entries.count
            entries.append(Entry(url: nativeURL, name: name, nameExtension: nameExtension, parentIndex: parentIndex,
                                 kind: kind, targetKind: targetKind))
            if isDirectory {
                try enumerate(nativeURL, parentIndex: index, entries: &entries)
            }
        }
    }

    private static func readChildMetadata(at url: URL, keys: Set<URLResourceKey>) throws -> URLResourceValues {
        do {
            return try url.resourceValues(forKeys: keys)
        } catch {
            throw ProjectScanError.resourceFailure(error, fallback: .unreadableDirectory)
        }
    }

    private static func assemble(_ entries: [Entry], token: OpaquePointer?) throws -> FileNode {
        var bytes = Data()
        func append(_ text: String) -> Range<Int> {
            let start = bytes.count
            bytes.append(contentsOf: text.utf8)
            return start..<bytes.count
        }

        var urls: [String: URL] = [:]
        urls.reserveCapacity(entries.count)
        let text = try entries.map { entry in
            try Task.checkCancellation()
            let identity = entry.url.absoluteString
            urls[identity] = entry.url
            return (identity: append(identity), name: append(entry.name), nameExtension: append(entry.nameExtension))
        }
        var tree: OpaquePointer?
        // The contiguous buffer keeps every borrowed UTF-8 view valid through tree creation.
        let status = try bytes.withUnsafeBytes { buffer in
            let chars = buffer.bindMemory(to: CChar.self)
            func view(_ range: Range<Int>) -> MarkyUtf8View {
                MarkyUtf8View(data: chars.baseAddress?.advanced(by: range.lowerBound), byte_count: range.count)
            }
            let input = try entries.indices.map { index in
                try Task.checkCancellation()
                let entry = entries[index]
                let strings = text[index]
                return MarkyProjectTreeEntry(
                    identity: view(strings.identity), name: view(strings.name), parent_index: entry.parentIndex,
                    metadata: MarkyProjectEntryMetadata(name_extension: view(strings.nameExtension),
                                                       kind: entry.kind, target_kind: entry.targetKind, is_hidden: 0)
                )
            }
            return marky_project_tree_create(input, input.count, MarkyProjectScanState(MARKY_PROJECT_SCAN_COMPLETE),
                                             token, &tree)
        }
        defer { marky_project_tree_release(tree) }
        if status == MarkyStatus(MARKY_STATUS_CANCELLED) { throw CancellationError() }
        guard status == MarkyStatus(MARKY_STATUS_OK), let tree else { throw ProjectScanError.unavailable }
        return try copyTree(tree, urls: urls)
    }

    private static func copyTree(_ tree: OpaquePointer, urls: [String: URL]) throws -> FileNode {
        let count = marky_project_tree_node_count(tree)
        var children = [[FileNode]](repeating: [], count: count)
        for index in (0..<count).reversed() {
            try Task.checkCancellation()
            var view = MarkyProjectTreeNodeView()
            guard marky_project_tree_node_at(tree, index, &view) == MarkyStatus(MARKY_STATUS_OK),
                  let url = urls[copyText(view.identity)]
            else { throw ProjectScanError.unavailable }
            let isDirectory = view.is_directory != 0
            children[index].reverse()
            children[index].sort { a, b in
                if a.isDirectory != b.isDirectory { return a.isDirectory }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
            let node = FileNode(url: url, name: copyText(view.name), isDirectory: isDirectory,
                                children: isDirectory ? children[index] : nil)
            if index == 0 { return node }
            children[index] = []
            children[view.parent_index].append(node)
        }
        throw ProjectScanError.unavailable
    }

    private static func copyText(_ view: MarkyUtf8View) -> String {
        String(decoding: UnsafeRawBufferPointer(start: view.data, count: view.byte_count), as: UTF8.self)
    }
}
