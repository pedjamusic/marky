//
//  MarkyUITestsLaunchTests.swift
//  MarkyUITests
//
//  Created by Predrag Drljaca on 3/5/26.
//

import XCTest

final class MarkyUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        // Avoid toggling host appearance during automation runs.
        false
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launchEnvironment["MARKY_UI_TEST_SEED"] = "1"
        app.launchArguments = ["-settings.appearanceMode", "system", "-settings.markdownTypographyMode", "allSystem", "-settings.markdownReaderTextSizePreset", "default"]
        app.launch()
        defer { app.terminate() }

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
