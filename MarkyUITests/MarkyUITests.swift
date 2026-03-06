//
//  MarkyUITests.swift
//  MarkyUITests
//
//  Created by Predrag Drljaca on 3/5/26.
//

import XCTest

final class MarkyUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    private func makeSeededApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["MARKY_UI_TEST_SEED"] = "1"
        return app
    }

    @MainActor
    func testSidebarSeedSearchAndSelectFlow() throws {
        let app = makeSeededApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["README.md"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["MEMORY.md"].exists)

        let search = app.textFields["sidebar-search-field"]
        XCTAssertTrue(search.exists)
        search.click()
        search.typeText("README")

        XCTAssertTrue(app.staticTexts["README.md"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["MEMORY.md"].exists)

        app.staticTexts["README.md"].click()
        XCTAssertTrue(app.staticTexts["README.md"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testCollapseButtonUpdatesStateToken() throws {
        let app = makeSeededApp()
        app.launch()

        let button = app.buttons["collapse-folders-button"]
        XCTAssertTrue(button.waitForExistence(timeout: 2))

        let before = button.value as? String
        button.click()
        let after = button.value as? String
        XCTAssertNotNil(before)
        XCTAssertNotNil(after)
        XCTAssertNotEqual(before, after)
    }

    @MainActor
    func testFolderRowTapExpandsChildren() throws {
        let app = makeSeededApp()
        app.launch()

        let docsRow = app.staticTexts["docs"]
        XCTAssertTrue(docsRow.waitForExistence(timeout: 2))

        let guide = app.staticTexts["GUIDE.md"]
        XCTAssertFalse(guide.exists)

        docsRow.click()
        XCTAssertTrue(guide.waitForExistence(timeout: 2))
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
