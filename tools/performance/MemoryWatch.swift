import AppKit
import Darwin
import Foundation

// The sandboxed XCTest runner cannot inspect another process's resource usage.
// Observe the exact test executable externally; retain the kernel lifetime peak.
@main
struct MemoryWatch {
    @MainActor
    static func main() async throws {
        guard CommandLine.arguments.count == 3 else { throw WatchError.invalidArguments }
        let executable = URL(fileURLWithPath: CommandLine.arguments[1]).resolvingSymlinksInPath().path
        let stop = CommandLine.arguments[2]
        guard !FileManager.default.fileExists(atPath: stop) else { throw WatchError.stopAlreadyExists }
        var peaks: [pid_t: UInt64] = [:]
        var reads: [pid_t: Int] = [:]
        var failures: [pid_t: Int32] = [:]
        while !FileManager.default.fileExists(atPath: stop) {
            for app in NSRunningApplication.runningApplications(withBundleIdentifier: "rocks.toodear.Marky") {
                guard app.executableURL?.resolvingSymlinksInPath().path == executable else { continue }
                var usage = rusage_info_v4()
                let status = withUnsafeMutablePointer(to: &usage) {
                    proc_pid_rusage(app.processIdentifier, RUSAGE_INFO_V4,
                        UnsafeMutableRawPointer($0).assumingMemoryBound(to: rusage_info_t?.self))
                }
                if status == 0 {
                    peaks[app.processIdentifier] = max(peaks[app.processIdentifier] ?? 0, usage.ri_lifetime_max_phys_footprint)
                    reads[app.processIdentifier, default: 0] += 1
                } else {
                    // A process may disappear between enumeration and inspection.
                    failures[app.processIdentifier] = errno
                }
            }
            try await Task.sleep(for: .milliseconds(50))
        }
        let records: [[String: Any]] = peaks.keys.sorted().map {
            ["process_id": $0, "peak_footprint_bytes": peaks[$0] ?? 0,
             "successful_reads": reads[$0] ?? 0, "last_error": failures[$0] ?? 0]
        }
        let json = try JSONSerialization.data(withJSONObject: records, options: [.prettyPrinted, .sortedKeys])
        print(String(decoding: json, as: UTF8.self))
    }

    enum WatchError: Error { case invalidArguments, stopAlreadyExists }
}
