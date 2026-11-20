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
        try NativeProjectScan.build(at: rootURL, token: nil).root
    }

    nonisolated static func loadProjectTree(at url: URL) async throws -> FileNode {
        try await loadProjectIndex(at: url).root
    }

    nonisolated internal static func loadProjectIndex(at url: URL) async throws -> ProjectIndex {
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

    static func build(at rootURL: URL, token: OpaquePointer?) throws -> ProjectIndex {
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
        return try assemble(entries, scanState: MarkyProjectScanState(MARKY_PROJECT_SCAN_COMPLETE), token: token)
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

        var children: [Entry] = []
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
            children.append(Entry(url: nativeURL, name: name, nameExtension: nameExtension, parentIndex: parentIndex,
                                  kind: kind, targetKind: targetKind))
        }

        children.sort { a, b in
            let directory = MarkyProjectEntryKind(MARKY_PROJECT_ENTRY_DIRECTORY)
            if (a.kind == directory) != (b.kind == directory) { return a.kind == directory }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
        for child in children {
            try Task.checkCancellation()
            let index = entries.count
            entries.append(child)
            if child.kind == MarkyProjectEntryKind(MARKY_PROJECT_ENTRY_DIRECTORY) {
                try enumerate(child.url, parentIndex: index, entries: &entries)
            }
        }
    }

    static func singleFile(at url: URL) throws -> ProjectIndex {
        do {
            guard try url.canonicalFileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else {
                throw ProjectScanError.unavailable
            }
        } catch {
            throw ProjectScanError.resourceFailure(error)
        }
        let file = url.canonicalDocumentURL
        let parent = file.deletingLastPathComponent()
        let unknown = MarkyProjectEntryKind(MARKY_PROJECT_ENTRY_UNKNOWN)
        return try assemble([
            Entry(url: parent, name: parent.lastPathComponent, nameExtension: "", parentIndex: 0,
                  kind: MarkyProjectEntryKind(MARKY_PROJECT_ENTRY_DIRECTORY), targetKind: unknown),
            Entry(url: file, name: file.lastPathComponent, nameExtension: file.pathExtension, parentIndex: 0,
                  kind: MarkyProjectEntryKind(MARKY_PROJECT_ENTRY_PICKED_FILE), targetKind: unknown)
        ], scanState: MarkyProjectScanState(MARKY_PROJECT_SCAN_PARTIAL), token: nil)
    }

    private static func readChildMetadata(at url: URL, keys: Set<URLResourceKey>) throws -> URLResourceValues {
        do {
            return try url.resourceValues(forKeys: keys)
        } catch {
            throw ProjectScanError.resourceFailure(error, fallback: .unreadableDirectory)
        }
    }

    private static func assemble(_ entries: [Entry], scanState: MarkyProjectScanState,
                                 token: OpaquePointer?) throws -> ProjectIndex {
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
            return (identity: append(identity), name: append(entry.name.precomposedStringWithCanonicalMapping), nameExtension: append(entry.nameExtension))
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
            return marky_project_tree_create(input, input.count, scanState, token, &tree)
        }
        if status == MarkyStatus(MARKY_STATUS_CANCELLED) { throw CancellationError() }
        guard status == MarkyStatus(MARKY_STATUS_OK), let tree else { throw ProjectScanError.unavailable }
        do {
            return try ProjectIndex(tree: tree, urls: urls)
        } catch {
            marky_project_tree_release(tree)
            throw error
        }
    }
}

nonisolated final class ProjectIndex: Sendable {
    typealias Favorite = (index: Int, path: String)

    let root: FileNode
    let scanState: MarkyProjectScanState
    private let nodes: [FileNode]
    private let parents: [Int]
    // The core tree is immutable after construction. Each call retains this owner
    // and owns its own query result. The handle never reaches the view model.
    private nonisolated(unsafe) let tree: OpaquePointer

    fileprivate init(tree: OpaquePointer, urls: [String: URL]) throws {
        let count = marky_project_tree_node_count(tree)
        var parents = [Int](repeating: 0, count: count)
        var children = [[FileNode]](repeating: [], count: count)
        var reversedNodes: [FileNode] = []
        reversedNodes.reserveCapacity(count)
        for index in (0..<count).reversed() {
            try Task.checkCancellation()
            var view = MarkyProjectTreeNodeView()
            guard marky_project_tree_node_at(tree, index, &view) == MarkyStatus(MARKY_STATUS_OK),
                  let url = urls[Self.copyText(view.identity)]
            else { throw ProjectScanError.unavailable }
            let isDirectory = view.is_directory != 0
            let node = FileNode(url: url, name: url.lastPathComponent, isDirectory: isDirectory,
                                children: isDirectory ? Array(children[index].reversed()) : nil)
            reversedNodes.append(node)
            children[index] = []
            parents[index] = view.parent_index
            if index != 0 { children[view.parent_index].append(node) }
        }
        guard let root = reversedNodes.last else { throw ProjectScanError.unavailable }
        self.root = root
        self.nodes = Array(reversedNodes.reversed())
        self.parents = parents
        self.scanState = marky_project_tree_scan_state(tree)
        self.tree = tree
    }

    deinit { marky_project_tree_release(tree) }

    static func singleFile(at url: URL) async throws -> ProjectIndex {
        let worker = Task.detached(priority: .userInitiated) { try NativeProjectScan.singleFile(at: url) }
        return try await withTaskCancellationHandler {
            try await worker.value
        } onCancel: {
            worker.cancel()
        }
    }

    static func pathSegments(_ path: String) -> [String]? {
        let segments = path.components(separatedBy: "/")
        guard !path.utf8.contains(0),
              segments.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else { return nil }
        return segments
    }

    func favoriteIndex(for path: String) -> Int? {
        guard let segments = Self.pathSegments(path) else { return nil }
        var bytes = Data()
        let ranges = segments.map { segment in
            let start = bytes.count
            bytes.append(contentsOf: segment.precomposedStringWithCanonicalMapping.utf8)
            return start..<bytes.count
        }
        var index = 0
        let status = bytes.withUnsafeBytes { buffer in
            let chars = buffer.bindMemory(to: CChar.self)
            let input = ranges.map { range in
                MarkyUtf8View(data: chars.baseAddress?.advanced(by: range.lowerBound), byte_count: range.count)
            }
            return marky_project_tree_find_path(tree, input, input.count, &index)
        }
        let availability = status == MarkyStatus(MARKY_STATUS_OK) && !nodes[index].isDirectory
            ? MARKY_PROJECT_FAVORITE_INDEXED_DOCUMENT : MARKY_PROJECT_FAVORITE_UNKNOWN
        let membership = marky_project_favorite_membership(scanState, MarkyProjectFavoriteAvailability(availability))
        return membership == MarkyProjectFavoriteDisposition(MARKY_PROJECT_FAVORITE_RETAIN_VISIBLE) ? index : nil
    }

    func relativePath(for url: URL) -> String? {
        let identity = url.absoluteString
        var index = 0
        let status = identity.withCString { bytes in
            marky_project_tree_find_identity(tree, MarkyUtf8View(data: bytes, byte_count: identity.utf8.count), &index)
        }
        guard status == MarkyStatus(MARKY_STATUS_OK), !nodes[index].isDirectory else { return nil }
        var names: [String] = []
        while index != 0 {
            names.append(nodes[index].name)
            index = parents[index]
        }
        return names.reversed().joined(separator: "/")
    }

    func orderedFavorites(_ paths: [String]) -> [Favorite] {
        var seen: Set<Int> = []
        return paths.compactMap { path -> Favorite? in
            guard let index = favoriteIndex(for: path), seen.insert(index).inserted else { return nil }
            return (index, path)
        }.sorted {
            let nameOrder = nodes[$0.index].name.localizedCaseInsensitiveCompare(nodes[$1.index].name)
            if nameOrder != .orderedSame { return nameOrder == .orderedAscending }
            return $0.path.localizedCaseInsensitiveCompare($1.path) == .orderedAscending
        }
    }

    func favoriteNodes(_ indices: [Int]) -> [FileNode] {
        indices.map { nodes[$0] }
    }

    func search(_ query: String, favorites: [Favorite],
                token: OpaquePointer) throws -> (files: [FileNode], favorites: [FileNode]) {
        let matches = try nodes.map { node -> UInt8 in
            try Task.checkCancellation()
            return node.name.localizedLowercase.contains(query) ? 1 : 0
        }
        let favoriteMatches = favorites.map {
            MarkyProjectFavoriteMatch(node_index: $0.index,
                                      matches_relative_path: $0.path.localizedLowercase.contains(query) ? 1 : 0)
        }
        var result: OpaquePointer?
        let status = matches.withUnsafeBufferPointer { names in
            favoriteMatches.withUnsafeBufferPointer { favorites in
                marky_project_tree_filter(tree, MarkyProjectQuery(
                    name_matches: names.baseAddress, name_match_count: names.count,
                    favorites: favorites.baseAddress, favorite_count: favorites.count
                ), token, &result)
            }
        }
        defer { marky_project_query_result_release(result) }
        if status == MarkyStatus(MARKY_STATUS_CANCELLED) { throw CancellationError() }
        guard status == MarkyStatus(MARKY_STATUS_OK), let result else { throw ProjectScanError.unavailable }
        let view = marky_project_query_result_view(result)
        let indices = UnsafeBufferPointer(start: view.file_indices, count: view.file_count)
        var children: [Int: [FileNode]] = [:]
        for index in indices.reversed() {
            try Task.checkCancellation()
            var node = nodes[index]
            if node.isDirectory { node.children = Array((children.removeValue(forKey: index) ?? []).reversed()) }
            children[parents[index], default: []].append(node)
        }
        let favorites = UnsafeBufferPointer(start: view.favorite_indices, count: view.favorite_count)
        return (Array((children[0] ?? []).reversed()), favorites.map { nodes[$0] })
    }

    static func copyText(_ view: MarkyUtf8View) -> String {
        String(decoding: UnsafeRawBufferPointer(start: view.data, count: view.byte_count), as: UTF8.self)
    }
}
