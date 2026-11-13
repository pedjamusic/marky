import XCTest

final class MarkyUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func makeSeededApp(additionalDocuments: [String: String] = [:]) throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["MARKY_UI_TEST_SEED"] = "1"
        app.launchEnvironment["MARKY_UI_TEST_FIXTURE_ID"] = UUID().uuidString
        let documents = [
            "README.md": "# Welcome Fixture\n\nWelcome to the real reader fixture.\n\n- Nested Parent Fixture\n  - Nested Child Fixture",
            "NOTES.md": "# Notes Fixture\n\nIndependent notes content.",
            "TABLE.md": "# Table Fixture\n\n| Deliverable | Implementation Notes | Release Plan |\n| :--- | :--- | ---: |\n| First Milestone Feature with Long Wrapped Prose | Extensive architectural implementation details that wrap onto multiple lines to thoroughly verify bounded column width proposals and vertical growth | Q1 2026 |\n| Second Milestone Feature with Multi-Line Content | Additional comprehensive implementation prose wrapping onto multiple lines to ensure all consecutive rows calculate proper vertical spacing without clipping | Q2 2026 |\n| Final Verification Row | Short summary text | Q3 2026 |",
            "WIDE_TABLE.md": "# Wide Table Fixture\n\n| Col 1 | Col 2 | Col 3 | Col 4 | Col 5 | Col 6 | Col 7 | Col 8 Target |\n| :--- | :--- | :--- | :--- | :--- | :--- | :--- | ---: |\n| Cell 1 Alpha | Cell 2 Beta | Cell 3 Gamma | Cell 4 Delta | Cell 5 Epsilon | Cell 6 Zeta | Cell 7 Eta | Cell 8 Theta Target |",
            "docs/GUIDE.md": "# Guide Fixture\n\nExpanded folder guide content."
        ]
        let payload = try JSONSerialization.data(withJSONObject: documents.merging(additionalDocuments) { _, added in added })
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
        let parent = reader.staticTexts.matching(identifier: "Nested Parent Fixture").firstMatch
        let child = reader.staticTexts.matching(identifier: "Nested Child Fixture").firstMatch
        XCTAssertTrue(parent.waitForExistence(timeout: 5))
        XCTAssertTrue(child.exists)
        XCTAssertGreaterThan(child.frame.minX, parent.frame.minX + 5)
    }

    @MainActor
    func testHoverHighlightsOnlyTheLinkUnderThePointer() throws {
        let app = try makeSeededApp(additionalDocuments: [
            "LINKS.md": "# Link Fixture\n\n[**Bold** and *italic*](https://example.com)\n\n[Other link](https://example.com)\n\nPlain text nearby."
        ])
        app.launch()
        defer { app.terminate() }

        let links = app.outlines["files-outline"].staticTexts["LINKS.md"]
        XCTAssertTrue(links.waitForExistence(timeout: 5))
        app.activate()
        links.click()

        let reader = app.descendants(matching: .any)["markdown-reader"].firstMatch
        let firstLink = reader.staticTexts["Bold and italic"].firstMatch
        let otherLink = reader.staticTexts["Other link"].firstMatch
        let plainText = reader.staticTexts["Plain text nearby."].firstMatch
        XCTAssertTrue(firstLink.waitForExistence(timeout: 5))
        XCTAssertTrue(otherLink.exists)
        XCTAssertTrue(plainText.exists)

        plainText.hover()
        let firstAtRest = firstLink.screenshot().pngRepresentation
        let otherAtRest = otherLink.screenshot().pngRepresentation

        firstLink.hover()
        XCTAssertFalse(firstAtRest == firstLink.screenshot().pngRepresentation, "Hover should recolor the first link")
        XCTAssertTrue(otherAtRest == otherLink.screenshot().pngRepresentation, "The other link should stay at rest")

        otherLink.hover()
        XCTAssertTrue(firstAtRest == firstLink.screenshot().pngRepresentation, "The first link should return to rest")
        XCTAssertFalse(otherAtRest == otherLink.screenshot().pngRepresentation, "Hover should recolor the other link")

        plainText.hover()
        XCTAssertTrue(otherAtRest == otherLink.screenshot().pngRepresentation, "Moving to plain text should clear hover")
    }

    @MainActor
    func testTableGeometryAndRowWrapping() throws {
        let app = try makeSeededApp()
        app.launch()
        defer { app.terminate() }

        let tableDoc = app.outlines["files-outline"].staticTexts["TABLE.md"]
        XCTAssertTrue(tableDoc.waitForExistence(timeout: 5))
        tableDoc.click()

        let reader = app.descendants(matching: .any)["markdown-reader"].firstMatch
        XCTAssertTrue(reader.waitForExistence(timeout: 5))
        XCTAssertTrue(reader.staticTexts["Table Fixture"].waitForExistence(timeout: 5))

        let tableScrollView = reader.descendants(matching: .any)["table-scroll-view"].firstMatch
        XCTAssertTrue(tableScrollView.waitForExistence(timeout: 5))

        let header1 = reader.staticTexts.matching(identifier: "Deliverable").firstMatch
        let header2 = reader.staticTexts.matching(identifier: "Implementation Notes").firstMatch
        let header3 = reader.staticTexts.matching(identifier: "Release Plan").firstMatch
        XCTAssertTrue(header1.waitForExistence(timeout: 5))
        XCTAssertTrue(header2.exists)
        XCTAssertTrue(header3.exists)

        let row1Text = "Extensive architectural implementation details that wrap onto multiple lines to thoroughly verify bounded column width proposals and vertical growth"
        let row2Text = "Additional comprehensive implementation prose wrapping onto multiple lines to ensure all consecutive rows calculate proper vertical spacing without clipping"
        let row1Desc = reader.staticTexts.matching(NSPredicate(format: "label == %@ OR value == %@", row1Text, row1Text)).firstMatch
        let row2Desc = reader.staticTexts.matching(NSPredicate(format: "label == %@ OR value == %@", row2Text, row2Text)).firstMatch
        XCTAssertTrue(row1Desc.waitForExistence(timeout: 5))
        XCTAssertTrue(row2Desc.waitForExistence(timeout: 5))

        let row3Left = reader.staticTexts.matching(identifier: "Final Verification Row").firstMatch
        let row3Right = reader.staticTexts.matching(identifier: "Q3 2026").firstMatch
        XCTAssertTrue(row3Left.exists)
        XCTAssertTrue(row3Right.exists)

        // 1. Multi-row table viewport grows to full intrinsic height (> 150 pt)
        XCTAssertGreaterThan(tableScrollView.frame.height, 150)

        // 2. Columns are laid out side-by-side with positive spacing
        XCTAssertLessThan(header1.frame.maxX, header2.frame.minX + 5)
        XCTAssertLessThan(header2.frame.maxX, header3.frame.minX + 5)

        // 3. Column 1 aligns across rows
        XCTAssertLessThanOrEqual(abs(row3Left.frame.minX - header1.frame.minX), 12)

        // 4. Wrapped cells have multi-line height compared to single-line cells
        XCTAssertGreaterThan(row1Desc.frame.height, row3Right.frame.height + 15)
        XCTAssertGreaterThan(row2Desc.frame.height, row3Right.frame.height + 15)
        XCTAssertGreaterThanOrEqual(row1Desc.frame.height, 40)

        // 5. Sequential row ordering (each row appears below the preceding wrapped row)
        XCTAssertGreaterThanOrEqual(row2Desc.frame.minY, row1Desc.frame.maxY - 2)
        XCTAssertGreaterThanOrEqual(row3Left.frame.minY, row2Desc.frame.maxY - 2)

        // 6. Complete vertical display without bottom clipping: last row is within table scroll view bounds
        XCTAssertLessThanOrEqual(row3Left.frame.maxY, tableScrollView.frame.maxY + 2)
        XCTAssertLessThanOrEqual(row3Right.frame.maxY, tableScrollView.frame.maxY + 2)

        // 7. Stability check: table scroll view height settles deterministically and does not grow in feedback loops
        let initialHeight = tableScrollView.frame.height
        header1.click()
        let settledHeight = tableScrollView.frame.height
        XCTAssertEqual(initialHeight, settledHeight, accuracy: 1.0)

        // 8. Capture screenshot attachment for supervisor visual validation
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "TableGeometryAndRowWrapping"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testTableHorizontalScrolling() throws {
        let app = try makeSeededApp()
        app.launch()
        defer { app.terminate() }

        let tableDoc = app.outlines["files-outline"].staticTexts["WIDE_TABLE.md"]
        XCTAssertTrue(tableDoc.waitForExistence(timeout: 5))
        tableDoc.click()

        let reader = app.descendants(matching: .any)["markdown-reader"].firstMatch
        XCTAssertTrue(reader.waitForExistence(timeout: 5))
        XCTAssertTrue(reader.staticTexts["Wide Table Fixture"].waitForExistence(timeout: 5))

        let tableScrollView = reader.descendants(matching: .any)["table-scroll-view"].firstMatch
        XCTAssertTrue(tableScrollView.waitForExistence(timeout: 5))

        let col1Header = reader.staticTexts.matching(NSPredicate(format: "label == %@ OR value == %@", "Col 1", "Col 1")).firstMatch
        let targetHeader = reader.staticTexts.matching(NSPredicate(format: "label == %@ OR value == %@", "Col 8 Target", "Col 8 Target")).firstMatch
        let targetCell = reader.staticTexts.matching(NSPredicate(format: "label == %@ OR value == %@", "Cell 8 Theta Target", "Cell 8 Theta Target")).firstMatch

        XCTAssertTrue(col1Header.waitForExistence(timeout: 5))
        XCTAssertTrue(targetHeader.exists)
        XCTAssertTrue(targetCell.exists)

        // Target cell initially outside the scroll view's visible viewport
        let initialTargetX = targetCell.frame.minX
        let initialScrollViewMaxX = tableScrollView.frame.maxX
        XCTAssertGreaterThanOrEqual(initialTargetX, initialScrollViewMaxX - 5)

        // Native horizontal scroll interaction on the table scroll view with sufficient delta
        tableScrollView.scroll(byDeltaX: -800, deltaY: 0)

        // Poll using predicate expectation for settled frame with entire target cell inside viewport
        let insideViewportPredicate = NSPredicate { _, _ in
            let cellFrame = targetCell.frame
            let scrollFrame = tableScrollView.frame
            return cellFrame.minX >= scrollFrame.minX - 10 && cellFrame.maxX <= scrollFrame.maxX + 10
        }
        let settledExpectation = XCTNSPredicateExpectation(predicate: insideViewportPredicate, object: nil)
        let waiterResult = XCTWaiter().wait(for: [settledExpectation], timeout: 5.0)
        XCTAssertEqual(waiterResult, .completed)

        // Verify actual movement (X coordinate decreased)
        let scrolledTargetX = targetCell.frame.minX
        XCTAssertLessThan(scrolledTargetX, initialTargetX)

        // Capture screenshot attachment for supervisor visual validation
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "TableHorizontalScrolling"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
