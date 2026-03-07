//
//  MarkyTests.swift
//  MarkyTests
//
//  Created by Predrag Drljaca on 3/5/26.
//

import Foundation
import Testing
import SwiftUI
@testable import Marky
#if os(macOS)
import AppKit
#endif

struct MarkyTests {
    private final class ThrowingProjectSessionService: ProjectSessionServicing {
        let saveError: Error?
        let restoreError: Error?

        init(saveError: Error? = nil, restoreError: Error? = nil) {
            self.saveError = saveError
            self.restoreError = restoreError
        }

        func saveBookmark(for url: URL) throws {
            if let saveError { throw saveError }
        }

        func restoreBookmarkedURL() throws -> RestoredProjectBookmark? {
            if let restoreError { throw restoreError }
            return nil
        }

        func clearBookmark() {}
    }

    @Test("buildProjectTree keeps markdown files and directories that contain them")
    func buildProjectTreeFiltersNonMarkdownFiles() throws {
        try Self.withTemporaryDirectory { root in
            let docs = root.appendingPathComponent("docs", isDirectory: true)
            let nested = docs.appendingPathComponent("nested", isDirectory: true)
            let images = root.appendingPathComponent("images", isDirectory: true)
            try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: images, withIntermediateDirectories: true)

            try "# Guide".write(to: docs.appendingPathComponent("guide.md"), atomically: true, encoding: .utf8)
            try "plain text".write(to: docs.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)
            try "Nested markdown".write(to: nested.appendingPathComponent("nested.markdown"), atomically: true, encoding: .utf8)
            try "not markdown".write(to: images.appendingPathComponent("photo.png"), atomically: true, encoding: .utf8)

            let tree = FileNode.buildProjectTree(at: root)
            let rootChildren = tree.children ?? []

            let docsNode = rootChildren.first(where: { $0.name == "docs" && $0.isDirectory })
            #expect(docsNode != nil)
            #expect(rootChildren.contains(where: { $0.name == "images" }) == false)
            #expect(docsNode?.children?.contains(where: { $0.name == "guide.md" && !$0.isDirectory }) == true)
            #expect(docsNode?.children?.contains(where: { $0.name == "notes.txt" }) == false)
            #expect(docsNode?.children?.contains(where: { $0.name == "nested" && $0.isDirectory }) == true)
        }
    }

    @MainActor
    @Test("restoreBookmarkIfNeeded maps typed bookmark resolution failures to user-safe message")
    func restoreBookmarkIfNeededMapsBookmarkResolutionFailure() {
        let service = ThrowingProjectSessionService(restoreError: ProjectSessionError.bookmarkResolutionFailed)
        let viewModel = ContentViewModel(projectSessionService: service)

        viewModel.restoreBookmarkIfNeeded()

        #expect(viewModel.errorMessage == "Couldn't restore the last opened project.")
    }

    @MainActor
    @Test("openPickedFolder maps typed bookmark encoding failures to user-safe message")
    func openPickedFolderMapsBookmarkEncodingFailure() throws {
        let service = ThrowingProjectSessionService(saveError: ProjectSessionError.bookmarkEncodingFailed)
        let viewModel = ContentViewModel(projectSessionService: service)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("A3-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        viewModel.openPickedFolder(folder)

        #expect(viewModel.errorMessage == "Couldn't save project access. You may need to reopen this location next time.")
    }

    @MainActor
    @Test("handleFileImporterResult routes picked URL by mode and clears import mode")
    func handleFileImporterResultRoutesAndClearsMode() throws {
        let service = ThrowingProjectSessionService()
        let viewModel = ContentViewModel(projectSessionService: service)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("A4-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        viewModel.importMode = .folder
        viewModel.handleFileImporterResult(.success([folder]))

        #expect(viewModel.importMode == nil)
        #expect(viewModel.root?.url == folder)
        #expect(viewModel.selectedURL == nil)
    }

    @MainActor
    @Test("handleFileImporterResult maps failures and clears import mode")
    func handleFileImporterResultMapsFailureAndClearsMode() {
        enum ImportFailure: Error { case failed }

        let service = ThrowingProjectSessionService()
        let viewModel = ContentViewModel(projectSessionService: service)
        viewModel.importMode = .file

        viewModel.handleFileImporterResult(.failure(ImportFailure.failed))

        #expect(viewModel.importMode == nil)
        #expect(viewModel.errorMessage?.contains("Couldn't import the selected item.") == true)
    }

    @Test("appearance mode maps to expected color scheme override")
    func appearanceModeMapsToColorScheme() {
        #expect(AppAppearanceMode.system.colorScheme == nil)
        #expect(AppAppearanceMode.light.colorScheme == .light)
        #expect(AppAppearanceMode.dark.colorScheme == .dark)
    }

    @MainActor
    @Test("selectNode toggles folder expansion and collapseAll clears expanded folders")
    func selectNodeTogglesFolderExpansion() {
        let service = ThrowingProjectSessionService()
        let viewModel = ContentViewModel(projectSessionService: service)
        let folderURL = URL(fileURLWithPath: "/tmp/a5-folder", isDirectory: true)
        let folder = FileNode(url: folderURL, name: "a5-folder", isDirectory: true, children: [])

        #expect(viewModel.expandedFolderURLs.contains(folderURL) == false)
        viewModel.selectNode(folder)
        #expect(viewModel.expandedFolderURLs.contains(folderURL) == true)
        viewModel.selectNode(folder)
        #expect(viewModel.expandedFolderURLs.contains(folderURL) == false)

        viewModel.selectNode(folder)
        #expect(viewModel.expandedFolderURLs.contains(folderURL) == true)
        viewModel.collapseAllSidebarFolders()
        #expect(viewModel.expandedFolderURLs.isEmpty)
    }

    @Test("buildProjectTree skips symbolic-link directories to prevent recursive cycles")
    func buildProjectTreeSkipsDirectorySymlinks() throws {
        try Self.withTemporaryDirectory { root in
            let notes = root.appendingPathComponent("notes", isDirectory: true)
            try FileManager.default.createDirectory(at: notes, withIntermediateDirectories: true)

            try "- item".write(to: notes.appendingPathComponent("todo.md"), atomically: true, encoding: .utf8)

            let loop = notes.appendingPathComponent("loop", isDirectory: true)
            try FileManager.default.createSymbolicLink(atPath: loop.path, withDestinationPath: root.path)

            let tree = FileNode.buildProjectTree(at: root)
            let notesNode = tree.children?.first(where: { $0.name == "notes" && $0.isDirectory })

            #expect(notesNode != nil)
            #expect(notesNode?.children?.contains(where: { $0.name == "todo.md" && !$0.isDirectory }) == true)
            #expect(notesNode?.children?.contains(where: { $0.name == "loop" }) == false)
        }
    }

    #if os(macOS)
    @MainActor
    @Test("markdown renderer preserves paragraph breaks and keeps first heading flush")
    func markdownRendererPreservesParagraphBreaksAndKeepsFirstHeadingFlush() {
        let rendered = MarkdownRenderer.render(from: "# Title\n\nBody")
        #expect(rendered.string == "Title\n\nBody")

        let paragraph = rendered.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        #expect(paragraph != nil)
        #expect((paragraph?.paragraphSpacingBefore ?? -1) == 0)
    }

    @MainActor
    @Test("markdown renderer converts task/bullet list markers")
    func markdownRendererConvertsTaskAndBulletMarkers() {
        let rendered = MarkdownRenderer.render(from: "- [x] Done\n- [ ] Todo\n* Bullet\n• Existing")
        #expect(rendered.string == "☑ Done\n☐ Todo\n• Bullet\n• Existing")
    }

    @MainActor
    @Test("markdown renderer applies inline link and code transformations")
    func markdownRendererTransformsInlineElements() {
        let rendered = MarkdownRenderer.render(from: "A **bold** and `code` [site](https://example.com)")
        #expect(rendered.string == "A bold and code site")

        let nsString = rendered.string as NSString
        let siteRange = nsString.range(of: "site")
        let codeRange = nsString.range(of: "code")
        #expect(siteRange.location != NSNotFound)
        #expect(codeRange.location != NSNotFound)

        let linkValue = rendered.attribute(.link, at: siteRange.location, effectiveRange: nil)
        let linkURL = (linkValue as? URL) ?? (linkValue as? NSURL).flatMap { $0 as URL }
        #expect(linkURL?.absoluteString == "https://example.com")

        let codeBackground = rendered.attribute(.backgroundColor, at: codeRange.location, effectiveRange: nil)
        #expect(codeBackground != nil)
    }

    @MainActor
    @Test("markdown typography modes remain explicit and complete")
    func markdownTypographyModesAreComplete() {
        #expect(MarkdownTypographyMode.allCases.count == 3)
        #expect(MarkdownTypographyMode.allCases.contains(.allSystem))
        #expect(MarkdownTypographyMode.allCases.contains(.serifHeadingsSystemBody))
        #expect(MarkdownTypographyMode.allCases.contains(.systemHeadingsSerifBody))
    }

    @MainActor
    @Test("markdown reader text size presets remain explicit and complete")
    func markdownReaderTextSizePresetsAreComplete() {
        #expect(MarkdownReaderTextSizePreset.allCases.count == 3)
        #expect(MarkdownReaderTextSizePreset.allCases.contains(.slightlySmaller))
        #expect(MarkdownReaderTextSizePreset.allCases.contains(.default))
        #expect(MarkdownReaderTextSizePreset.allCases.contains(.slightlyBigger))
    }

    @MainActor
    @Test("serif body mode increases body point size")
    func markdownTypographySerifBodyModeIncreasesBodyPointSize() {
        let systemRendered = MarkdownRenderer.render(from: "Body", mode: .allSystem)
        let serifBodyRendered = MarkdownRenderer.render(from: "Body", mode: .systemHeadingsSerifBody)

        let systemFont = systemRendered.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        let serifBodyFont = serifBodyRendered.attribute(.font, at: 0, effectiveRange: nil) as? NSFont

        #expect(systemFont != nil)
        #expect(serifBodyFont != nil)
        #expect((serifBodyFont?.pointSize ?? 0) > (systemFont?.pointSize ?? 0))
    }

    @MainActor
    @Test("markdown heading scale keeps descending hierarchy")
    func markdownHeadingScaleIsDescending() {
        let rendered = MarkdownRenderer.render(from: "# H1\n## H2\n### H3", mode: .allSystem)
        let text = rendered.string as NSString
        let h1Range = text.range(of: "H1")
        let h2Range = text.range(of: "H2")
        let h3Range = text.range(of: "H3")

        #expect(h1Range.location != NSNotFound)
        #expect(h2Range.location != NSNotFound)
        #expect(h3Range.location != NSNotFound)

        let h1Font = rendered.attribute(.font, at: h1Range.location, effectiveRange: nil) as? NSFont
        let h2Font = rendered.attribute(.font, at: h2Range.location, effectiveRange: nil) as? NSFont
        let h3Font = rendered.attribute(.font, at: h3Range.location, effectiveRange: nil) as? NSFont

        #expect(h1Font != nil)
        #expect(h2Font != nil)
        #expect(h3Font != nil)
        #expect((h1Font?.pointSize ?? 0) > (h2Font?.pointSize ?? 0))
        #expect((h2Font?.pointSize ?? 0) > (h3Font?.pointSize ?? 0))
    }

    @MainActor
    @Test("reader text size presets scale body typography up and down subtly")
    func markdownReaderTextSizePresetsScaleBodyTypography() {
        let smallerRendered = MarkdownRenderer.render(
            from: "Body",
            mode: .allSystem,
            textSizePreset: .slightlySmaller
        )
        let defaultRendered = MarkdownRenderer.render(
            from: "Body",
            mode: .allSystem,
            textSizePreset: .default
        )
        let biggerRendered = MarkdownRenderer.render(
            from: "Body",
            mode: .allSystem,
            textSizePreset: .slightlyBigger
        )

        let smallerFont = smallerRendered.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        let defaultFont = defaultRendered.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        let biggerFont = biggerRendered.attribute(.font, at: 0, effectiveRange: nil) as? NSFont

        #expect(smallerFont != nil)
        #expect(defaultFont != nil)
        #expect(biggerFont != nil)
        #expect((smallerFont?.pointSize ?? 0) < (defaultFont?.pointSize ?? 0))
        #expect((defaultFont?.pointSize ?? 0) < (biggerFont?.pointSize ?? 0))
        #expect(abs((defaultFont?.pointSize ?? 0) - 16) < 0.01)
    }

    @MainActor
    @Test("markdown renderer handles fenced code blocks as literal monospaced content")
    func markdownRendererHandlesFencedCodeBlocks() {
        let rendered = MarkdownRenderer.render(from: "```swift\nlet x = **1**\n```")
        #expect(rendered.string == "let x = **1**")

        let font = rendered.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        let background = rendered.attribute(.backgroundColor, at: 0, effectiveRange: nil)
        #expect(font != nil)
        #expect(background != nil)
        #expect((font?.fontName.contains("Mono") ?? false) || (font?.fontName.contains("Menlo") ?? false))
    }

    @Test("markdown content blocks split prose and fenced code without parsing code markup")
    func markdownContentBlocksSplitFencedCode() {
        let blocks = MarkdownContentBlocks.parse(from: "Before\n\n```swift\nlet x = **1**\n```\n\nAfter")
        #expect(blocks.count == 3)

        if case .markdown(let before) = blocks[0] {
            #expect(before == "Before")
        } else {
            Issue.record("Expected markdown block before code fence")
        }

        if case .code(let code) = blocks[1] {
            #expect(code == "let x = **1**")
        } else {
            Issue.record("Expected code block between markdown blocks")
        }

        if case .markdown(let after) = blocks[2] {
            #expect(after == "After")
        } else {
            Issue.record("Expected markdown block after code fence")
        }
    }

    @MainActor
    @Test("markdown content blocks split prose into heading paragraph list and quote blocks")
    func markdownContentBlocksSplitProseRhythmBlocks() {
        let blocks = MarkdownContentBlocks.render(
            from: "# Title\nBody line 1\nBody line 2\n\n1. one\n   - nested\n2. two\n\n> quoted",
            mode: .allSystem,
            isDarkMode: false
        )

        #expect(blocks.count == 4)

        if case .heading(let level, _) = blocks[0].kind {
            #expect(level == 1)
        } else {
            Issue.record("Expected heading block first")
        }

        if case .paragraph(let text) = blocks[1].kind {
            #expect(String(text.characters) == "Body line 1 Body line 2")
        } else {
            Issue.record("Expected paragraph block second")
        }

        if case .list(let items) = blocks[2].kind {
            #expect(items.count == 3)
            #expect(items[0].marker == "1.")
            #expect(items[1].marker == "•")
            #expect(items[1].nestingLevel > items[0].nestingLevel)
            #expect(items[2].marker == "2.")
        } else {
            Issue.record("Expected list block third")
        }

        if case .quote = blocks[3].kind {
        } else {
            Issue.record("Expected quote block fourth")
        }
    }
    #endif

    private static func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MarkyTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(root)
    }
}
