import AppKit
import Darwin
import Vision

// External visual endpoint: do not enable/query the app's accessibility tree.
// See T02-S2-PERFORMANCE.md for the distinct XCTest failure and comparison limits.
@main
struct NativeReaderProbe {
    enum ProbeError: Error {
        case arguments, inputPermission, existingApp, existingOutput, window, geometry
        case capture, ready, row, event, timeout, termination
    }

    @MainActor
    static func main() async throws {
        guard CommandLine.arguments.count == 4 else { throw ProbeError.arguments }
        guard CGPreflightPostEventAccess() else { throw ProbeError.inputPermission }
        let appURL = URL(fileURLWithPath: CommandLine.arguments[1]).resolvingSymlinksInPath()
        let root = URL(fileURLWithPath: CommandLine.arguments[2]).resolvingSymlinksInPath()
        let output = URL(fileURLWithPath: CommandLine.arguments[3], isDirectory: true)
        guard !FileManager.default.fileExists(atPath: output.path) else { throw ProbeError.existingOutput }
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for run in 0..<6 {
            guard NSRunningApplication.runningApplications(withBundleIdentifier: "rocks.toodear.Marky").isEmpty else {
                throw ProbeError.existingApp
            }
            let config = NSWorkspace.OpenConfiguration()
            config.createsNewApplicationInstance = true
            config.environment = ["MARKY_UI_TEST_SEED": "1", "MARKY_UI_TEST_PROJECT_PATH": root.appendingPathComponent("project").path]
            config.arguments = ["-settings.appearanceMode", "light", "-settings.markdownTypographyMode", "allSystem",
                                "-settings.markdownReaderTextSizePreset", "default"]
            let app = try await NSWorkspace.shared.openApplication(at: appURL, configuration: config)
            // Also stop our exact diagnostic process if capture/OCR/setup fails.
            defer { if !app.isTerminated { app.forceTerminate() } }
            try await Task.sleep(for: .seconds(3))
            let (windowID, frame) = try window(for: app.processIdentifier)
            guard frame.width == 1252, frame.height == 833 else { throw ProbeError.geometry }
            let beforeURL = output.appendingPathComponent("run-\(run)-before.png")
            let afterURL = output.appendingPathComponent("run-\(run)-after.png")
            var before = try recognize(windowID: windowID, to: beforeURL)
            guard before.contains(where: { $0.0 == "Ready Fixture" }),
                  !before.contains(where: { $0.0 == "Large Reading Fixture" }) else { throw ProbeError.ready }
            app.activate()
            let sidebar = CGPoint(x: frame.minX + 100, y: frame.minY + 300)
            CGWarpMouseCursorPosition(sidebar)
            try await Task.sleep(for: .milliseconds(250))
            for _ in 0..<6 {
                if before.contains(where: { $0.0 == "LARGE.md" }) { break }
                guard let wheel = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1,
                                          wheel1: -10000, wheel2: 0, wheel3: 0) else { throw ProbeError.event }
                wheel.location = sidebar
                wheel.post(tap: .cghidEventTap)
                try await Task.sleep(for: .milliseconds(500))
                before = try recognize(windowID: windowID, to: beforeURL)
            }
            guard let row = before.first(where: { $0.0 == "LARGE.md" && $0.1.midX < 280 / frame.width }) else {
                throw ProbeError.row
            }
            let point = CGPoint(x: frame.minX + row.1.midX * frame.width, y: frame.minY + (1 - row.1.midY) * frame.height)
            let start = ProcessInfo.processInfo.systemUptime
            for type in [CGEventType.leftMouseDown, .leftMouseUp] {
                guard let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point,
                                          mouseButton: .left) else { throw ProbeError.event }
                event.post(tap: .cghidEventTap)
            }
            var visible = false
            var observations = 0
            var lastAbsentMS: Double = 0
            var captureStartMS: Double = 0
            repeat {
                try await Task.sleep(for: .milliseconds(250))
                captureStartMS = (ProcessInfo.processInfo.systemUptime - start) * 1000
                let text = try recognize(windowID: windowID, to: afterURL)
                observations += 1
                visible = text.contains(where: { $0.0 == "Large Reading Fixture" && $0.1.midX > 280 / frame.width })
                    && text.contains(where: { $0.0 == "Section 0000" })
                if visible { break }
                lastAbsentMS = captureStartMS
            } while ProcessInfo.processInfo.systemUptime - start < 60
            let elapsed = (ProcessInfo.processInfo.systemUptime - start) * 1000
            var driverUsage = rusage_info_v4()
            let driverStatus = withUnsafeMutablePointer(to: &driverUsage) {
                proc_pid_rusage(getpid(), RUSAGE_INFO_V4, UnsafeMutableRawPointer($0).assumingMemoryBound(to: rusage_info_t?.self))
            }
            guard driverStatus == 0 else { throw ProbeError.capture }
            let sample: [String: Any] = ["run": run, "warmup": run == 0, "process_id": app.processIdentifier,
                "visible": visible, "click_to_reader_ms": elapsed, "last_absent_capture_ms": lastAbsentMS,
                "visible_capture_started_ms": captureStartMS, "observations": observations,
                "window_width": frame.width, "window_height": frame.height,
                "thermal_state": ProcessInfo.processInfo.thermalState.rawValue,
                "driver_peak_footprint_bytes": driverUsage.ri_lifetime_max_phys_footprint]
            let data = try JSONSerialization.data(withJSONObject: sample, options: [.sortedKeys])
            FileHandle.standardOutput.write(Data(("MARKY_NATIVE_SAMPLE " + String(decoding: data, as: UTF8.self) + "\n").utf8))
            guard visible else { throw ProbeError.timeout }
            // External MemoryWatch retains the kernel high-water mark through this hold/exit.
            try await Task.sleep(for: .milliseconds(250))
            app.terminate()
            let stopStart = ProcessInfo.processInfo.systemUptime
            while !app.isTerminated, ProcessInfo.processInfo.systemUptime - stopStart < 5 {
                try await Task.sleep(for: .milliseconds(50))
            }
            guard app.isTerminated else { throw ProbeError.termination }
        }
    }

    private static func window(for pid: pid_t) throws -> (Int, CGRect) {
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]],
              let window = windows.first(where: { ($0[kCGWindowOwnerPID as String] as? Int32) == pid && ($0[kCGWindowLayer as String] as? Int) == 0 }),
              let id = window[kCGWindowNumber as String] as? Int,
              let bounds = window[kCGWindowBounds as String] as? [String: Any],
              let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary) else { throw ProbeError.window }
        return (id, frame)
    }

    private static func recognize(windowID: Int, to url: URL) throws -> [(String, CGRect)] {
        let capture = Process()
        capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        capture.arguments = ["-x", "-o", "-l", String(windowID), url.path]
        try capture.run()
        capture.waitUntilExit()
        guard capture.terminationStatus == 0 else { throw ProbeError.capture }
        return try autoreleasepool {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .fast
            request.recognitionLanguages = ["en-US"]
            request.usesLanguageCorrection = false
            try VNImageRequestHandler(url: url, options: [:]).perform([request])
            return request.results?.compactMap { result in
                result.topCandidates(1).first.map { ($0.string, result.boundingBox) }
            } ?? []
        }
    }
}
