import AppKit
import XCTest
import Vision

// Opt in explicitly; the normal UI suite does not run a performance workload.
final class LargeInputPerformanceTests: XCTestCase {
    @MainActor
    private func fixturePath() throws -> String {
        guard let path = ProcessInfo.processInfo.environment["MARKY_PERFORMANCE_ROOT"] else {
            throw XCTSkip("Set TEST_RUNNER_MARKY_PERFORMANCE_ROOT to generated T02.S2 v1 fixtures.")
        }
        continueAfterFailure = false
        return path
    }

    @MainActor
    private func seededApp(path: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["MARKY_UI_TEST_SEED"] = "1"
        app.launchEnvironment["MARKY_UI_TEST_PROJECT_PATH"] = path + "/project"
        app.launchArguments = ["-settings.appearanceMode", "light",
                               "-settings.markdownTypographyMode", "allSystem",
                               "-settings.markdownReaderTextSizePreset", "default"]
        return app
    }

    @MainActor
    private func appPID() throws -> pid_t {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: "rocks.toodear.Marky")
        XCTAssertEqual(running.count, 1, "Close other Marky copies before measuring.")
        return try XCTUnwrap(running.first).processIdentifier
    }

    @MainActor
    func testFixedLargeFolder() async throws {
        let path = try fixturePath()
        var samples: [[String: Any]] = []
        for run in 0..<6 {
            let app = seededApp(path: path)
            defer { app.terminate() }
            let start = ProcessInfo.processInfo.systemUptime
            app.launch()
            let reader = app.descendants(matching: .any)["markdown-reader"].firstMatch
            XCTAssertTrue(reader.staticTexts["Ready Fixture"].waitForExistence(timeout: 60))
            let launchEnd = ProcessInfo.processInfo.systemUptime
            let frame = app.windows.firstMatch.frame
            let search = app.textFields["sidebar-search-field"]
            let searchStart = ProcessInfo.processInfo.systemUptime
            search.click()
            search.typeText("note-09")
            XCTAssertTrue(app.outlines["files-outline"].staticTexts["note-09.md"].firstMatch.waitForExistence(timeout: 60))
            let searchEnd = ProcessInfo.processInfo.systemUptime
            let sample: [String: Any] = ["run": run, "warmup": run == 0,
                "launch_to_reader_ms": (launchEnd - start) * 1000,
                "search_to_outline_ms": (searchEnd - searchStart) * 1000,
                "process_id": try appPID(),
                "window_width": frame.width, "window_height": frame.height,
                "thermal_state": ProcessInfo.processInfo.thermalState.rawValue]
            samples.append(sample)
            let encoded = try JSONSerialization.data(withJSONObject: sample, options: [.sortedKeys])
            print("MARKY_PERFORMANCE_SAMPLE " + String(decoding: encoded, as: UTF8.self))
            // Give the external kernel-memory observer a final sample before termination.
            try await Task.sleep(for: .milliseconds(250))
        }
        let data = try JSONSerialization.data(withJSONObject: samples, options: [.prettyPrinted, .sortedKeys])
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "marky-t02-s2-v1-ui-samples"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // Kept separately because this baseline currently cannot reach a measurable endpoint.
    @MainActor
    func testDenseDocumentObservation() async throws {
        guard ProcessInfo.processInfo.environment["MARKY_PERFORMANCE_DENSE"] == "1" else {
            throw XCTSkip("Set TEST_RUNNER_MARKY_PERFORMANCE_DENSE=1 for the known failing dense-document observation.")
        }
        let app = seededApp(path: try fixturePath())
        app.launch()
        defer { app.terminate() }
        let reader = app.descendants(matching: .any)["markdown-reader"].firstMatch
        XCTAssertTrue(reader.staticTexts["Ready Fixture"].waitForExistence(timeout: 60))
        let start = ProcessInfo.processInfo.systemUptime
        app.outlines["files-outline"].staticTexts["LARGE.md"].click()
        var visible = false
        var screenshot = XCUIScreen.main.screenshot()
        repeat {
            screenshot = XCUIScreen.main.screenshot()
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-US"]
            request.usesLanguageCorrection = false
            let image = try XCTUnwrap(screenshot.image.cgImage(forProposedRect: nil, context: nil, hints: nil))
            try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
            visible = request.results?.contains { $0.topCandidates(1).first?.string == "Large Reading Fixture" } == true
            if visible { break }
            try await Task.sleep(for: .milliseconds(250))
        } while ProcessInfo.processInfo.systemUptime - start < 30
        let elapsed = ProcessInfo.processInfo.systemUptime - start
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = visible ? "dense-reader-visible" : "dense-reader-timeout"
        attachment.lifetime = .keepAlways
        add(attachment)
        let observation: [String: Any] = ["visible": visible, "observation_ms": elapsed * 1000,
            "process_id": try appPID()]
        let json = try JSONSerialization.data(withJSONObject: observation, options: [.sortedKeys])
        print("MARKY_DENSE_OBSERVATION " + String(decoding: json, as: UTF8.self))
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertTrue(visible, "Dense document heading did not become visible; retain this failed observation.")
    }
}
