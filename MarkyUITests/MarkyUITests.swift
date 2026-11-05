import XCTest

final class MarkyUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func makeSeededApp() throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["MARKY_UI_TEST_SEED"] = "1"
        app.launchEnvironment["MARKY_UI_TEST_FIXTURE_ID"] = UUID().uuidString
        let documents = [
            "README.md": "# Welcome Fixture\n\nWelcome to the real reader fixture.\n\n- Nested Parent Fixture\n  - Nested Child Fixture",
            "NOTES.md": "# Notes Fixture\n\nIndependent notes content.",
            "docs/GUIDE.md": "# Guide Fixture\n\nExpanded folder guide content."
        ]
        let payload = try JSONSerialization.data(withJSONObject: documents)
        app.launchEnvironment["MARKY_UI_TEST_FIXTURE_JSON"] = try XCTUnwrap(String(data: payload, encoding: .utf8))
        app.launchArguments = [
            "-settings.appearanceMode", "system",
            "-settings.markdownTypographyMode", "allSystem",
            "-settings.markdownReaderTextSizePreset", "default"
        ]
        return app
    }

    @MainActor
    func testSidebarSearchAndSelectionDisplaysDocument() throws {
        let app = try makeSeededApp()
        app.launch()
        defer { app.terminate() }
        XCTAssertTrue(app.outlines["files-outline"].staticTexts["README.md"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.outlines["files-outline"].staticTexts["NOTES.md"].exists)

        let search = app.textFields["sidebar-search-field"]
        XCTAssertTrue(search.exists)
        search.click()
        search.typeText("NOTES")
        XCTAssertTrue(app.outlines["files-outline"].staticTexts["README.md"].waitForNonExistence(timeout: 2))
        XCTAssertTrue(app.outlines["files-outline"].staticTexts["NOTES.md"].exists)
        app.outlines["files-outline"].staticTexts["NOTES.md"].click()

        let reader = app.descendants(matching: .any)["markdown-reader"].firstMatch
        XCTAssertTrue(reader.waitForExistence(timeout: 5))
        XCTAssertTrue(reader.staticTexts["Notes Fixture"].waitForExistence(timeout: 5))
        XCTAssertTrue(reader.staticTexts["Independent notes content."].exists)
        XCTAssertFalse(reader.staticTexts["Welcome Fixture"].exists)
    }

    @MainActor
    func testCollapseFoldersHidesPreviouslyExpandedChildren() throws {
        let app = try makeSeededApp()
        app.launch()
        defer { app.terminate() }
        let docs = app.outlines["files-outline"].staticTexts["docs"]
        XCTAssertTrue(docs.waitForExistence(timeout: 5))
        XCTAssertFalse(app.outlines["files-outline"].staticTexts["GUIDE.md"].exists)
        docs.click()
        XCTAssertTrue(app.outlines["files-outline"].staticTexts["GUIDE.md"].waitForExistence(timeout: 2))
        app.buttons["collapse-folders-button"].click()
        let guide = app.outlines["files-outline"].staticTexts["GUIDE.md"]
        XCTAssertTrue(guide.waitForNonExistence(timeout: 2))
        docs.click()
        XCTAssertTrue(guide.waitForExistence(timeout: 2))
    }

    @MainActor
    func testFolderRowTapTogglesChildren() throws {
        let app = try makeSeededApp()
        app.launch()
        defer { app.terminate() }
        let docs = app.outlines["files-outline"].staticTexts["docs"]
        XCTAssertTrue(docs.waitForExistence(timeout: 5))
        XCTAssertFalse(app.outlines["files-outline"].staticTexts["GUIDE.md"].exists)
        let folderRow = app.outlines["files-outline"].outlineRows.containing(.staticText, identifier: "docs").firstMatch
        XCTAssertEqual(folderRow.disclosureTriangles.count, 1)
        docs.click()
        XCTAssertTrue(app.outlines["files-outline"].staticTexts["GUIDE.md"].waitForExistence(timeout: 2))
        folderRow.disclosureTriangles.firstMatch.click()
        XCTAssertTrue(app.outlines["files-outline"].staticTexts["GUIDE.md"].waitForNonExistence(timeout: 2))
    }
    @MainActor
    func testFolderKeyboardNavigationKeepsDisplayedDocument() throws {
        let app = try makeSeededApp()
        app.launch()
        defer { app.terminate() }
        let outline = app.outlines["files-outline"]
        let docs = outline.staticTexts["docs"]
        XCTAssertTrue(docs.waitForExistence(timeout: 5))
        docs.click()
        XCTAssertTrue(outline.staticTexts["GUIDE.md"].waitForExistence(timeout: 2))
        app.typeKey(.leftArrow, modifierFlags: [])
        XCTAssertTrue(outline.staticTexts["GUIDE.md"].waitForNonExistence(timeout: 2))
        app.typeKey(.rightArrow, modifierFlags: [])
        XCTAssertTrue(outline.staticTexts["GUIDE.md"].waitForExistence(timeout: 2))
        let reader = app.descendants(matching: .any)["markdown-reader"].firstMatch
        XCTAssertTrue(reader.staticTexts["Welcome Fixture"].exists)
    }

    @MainActor
    func testNestedListChildIsVisiblyIndented() throws {
        let app = try makeSeededApp()
        app.launch()
        defer { app.terminate() }
        let reader = app.descendants(matching: .any)["markdown-reader"].firstMatch
        let parent = reader.staticTexts["Nested Parent Fixture"]
        let child = reader.staticTexts["Nested Child Fixture"]
        XCTAssertTrue(parent.waitForExistence(timeout: 5))
        XCTAssertTrue(child.exists)
        XCTAssertGreaterThan(child.frame.minX, parent.frame.minX + 5)
    }

}
