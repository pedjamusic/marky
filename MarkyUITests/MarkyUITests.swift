import XCTest

final class MarkyUITests: XCTestCase {
    private var fixtureURL: URL?

    override func setUpWithError() throws {
        continueAfterFailure = false
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("MarkyUITests-\(UUID().uuidString)", isDirectory: true)
            .resolvingSymlinksInPath().standardizedFileURL
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("docs"), withIntermediateDirectories: true)
        try "# Welcome Fixture\n\nWelcome to the real reader fixture.".write(to: folder.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        try "# Notes Fixture\n\nIndependent notes content.".write(to: folder.appendingPathComponent("NOTES.md"), atomically: true, encoding: .utf8)
        try "# Guide Fixture\n\nExpanded folder guide content.".write(to: folder.appendingPathComponent("docs/GUIDE.md"), atomically: true, encoding: .utf8)
        fixtureURL = folder
    }

    override func tearDownWithError() throws {
        if let fixtureURL { try FileManager.default.removeItem(at: fixtureURL) }
        fixtureURL = nil
    }

    @MainActor
    private func makeSeededApp() throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["MARKY_UI_TEST_SEED"] = "1"
        app.launchEnvironment["MARKY_UI_TEST_PROJECT_PATH"] = try XCTUnwrap(fixtureURL).path
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
        XCTAssertTrue(app.outlines["files-outline"].staticTexts["NOTES.md"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.outlines["files-outline"].staticTexts["README.md"].exists)
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
}
