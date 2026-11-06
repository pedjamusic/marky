import AppKit
import Darwin
import Foundation

// Compiled alongside unmodified production sources, outside the app target.
@main
struct PerformanceProbe {
    nonisolated static func now() -> Double { ProcessInfo.processInfo.systemUptime }

    @MainActor
    static func main() async throws {
        guard CommandLine.arguments.count == 3 else { throw ProbeError.invalidArguments }
        let scenario = CommandLine.arguments[1]
        let root = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
        let project = root.appendingPathComponent("project")
        let document = project.appendingPathComponent("LARGE.md")
        var extra: [String: Any] = [:]
        let start = now()
        switch scenario {
        case "prepare", "render":
            // Read/decode stays outside the semantic timer, but inside process peak memory.
            let text = try String(contentsOf: document, encoding: .utf8)
            let semanticStart = now()
            let prepared = MarkdownContentBlocks.prepare(from: text)
            guard prepared.count == 3585 else { throw ProbeError.unexpectedOutput }
            if scenario == "render" {
                let rendered = MarkdownContentBlocks.render(preparedBlocks: prepared,
                    mode: .allSystem, textSizePreset: .default, isDarkMode: false)
                guard rendered.count == prepared.count else { throw ProbeError.unexpectedOutput }
                extra["blocks"] = rendered.count
            } else {
                extra["blocks"] = prepared.count
            }
            extra["processing_ms"] = (now() - semanticStart) * 1000
        case "document":
            let doc = MarkdownDoc()
            await doc.load(from: document)
            guard doc.error == nil, !doc.isLoading, doc.blocks.count == 3585 else { throw ProbeError.unexpectedOutput }
            extra["blocks"] = doc.blocks.count
        case "scan":
            let tree = try await FileNode.loadProjectTree(at: project)
            guard counts(tree) == (5002, 601) else { throw ProbeError.unexpectedOutput }
            extra["files"] = 5002
        case "project", "replace-project":
            let model = ContentViewModel()
            model.openPickedFolder(project)
            if scenario == "replace-project" {
                try await Task.sleep(for: .milliseconds(5))
                let request = now()
                model.openPickedFolder(root.appendingPathComponent("small"))
                await model.waitForProjectLoad()
                guard model.root?.url == root.appendingPathComponent("small").canonicalFileURL,
                      model.errorMessage == nil else { throw ProbeError.unexpectedOutput }
                extra["replacement_ready_ms"] = (now() - request) * 1000
                // Let any canceled scan finish before verifying latest publication.
                try await Task.sleep(for: .milliseconds(100))
                guard model.root?.url == root.appendingPathComponent("small").canonicalFileURL else { throw ProbeError.unexpectedOutput }
                extra["settle_ms"] = 100
            } else {
                await model.waitForProjectLoad()
                guard let tree = model.root, counts(tree) == (5002, 601), model.errorMessage == nil else { throw ProbeError.unexpectedOutput }
                let searchStart = now()
                model.sidebarSearchText = "note-09"
                let searchEnd = now()
                let filtered = FileNode(url: project, name: "project", isDirectory: true, children: model.displayedNodes)
                guard counts(filtered).0 == 500 else { throw ProbeError.unexpectedOutput }
                extra["search_ms"] = (searchEnd - searchStart) * 1000
                extra["matches"] = 500
            }
            model.closeProject()
        case "cancel-document":
            let doc = MarkdownDoc()
            let task = Task { await doc.load(from: document) }
            let cancel = Task.detached {
                try await Task.sleep(for: .milliseconds(5))
                let requested = now()
                task.cancel()
                return requested
            }
            await task.value
            let finished = now()
            let requested = try await cancel.value
            extra["cancel_requested_before_completion"] = requested < finished
            extra["cancel_to_completion_ms"] = max(0, finished - requested) * 1000
            extra["published_blocks"] = doc.blocks.count
            guard doc.error == nil, !doc.isLoading else { throw ProbeError.unexpectedOutput }
        case "cancel-scan":
            let task = Task { try await FileNode.loadProjectTree(at: project) }
            try await Task.sleep(for: .milliseconds(5))
            let requested = now()
            task.cancel()
            do {
                _ = try await task.value
                throw ProbeError.completedBeforeCancellation
            } catch is CancellationError {
                extra["cancel_to_completion_ms"] = (now() - requested) * 1000
            }
        default:
            throw ProbeError.invalidArguments
        }
        let end = now()
        var memory = rusage_info_v4()
        let status = withUnsafeMutablePointer(to: &memory) {
            proc_pid_rusage(getpid(), RUSAGE_INFO_V4,
                UnsafeMutableRawPointer($0).assumingMemoryBound(to: rusage_info_t?.self))
        }
        var usage = rusage()
        guard status == 0, getrusage(RUSAGE_SELF, &usage) == 0 else { throw ProbeError.memoryUnavailable }
        extra["scenario"] = scenario
        extra["elapsed_ms"] = (end - start) * 1000
        extra["peak_footprint_bytes"] = memory.ri_lifetime_max_phys_footprint
        extra["peak_rss_bytes"] = usage.ru_maxrss
        extra["thermal_state"] = ProcessInfo.processInfo.thermalState.rawValue
        let json = try JSONSerialization.data(withJSONObject: extra, options: [.sortedKeys])
        print(String(decoding: json, as: UTF8.self))
    }

    nonisolated static func counts(_ node: FileNode) -> (Int, Int) {
        if !node.isDirectory { return (1, 0) }
        return (node.children ?? []).reduce((0, 1)) { result, child in
            let count = counts(child)
            return (result.0 + count.0, result.1 + count.1)
        }
    }

    enum ProbeError: Error {
        case invalidArguments, unexpectedOutput, completedBeforeCancellation, memoryUnavailable
    }
}
