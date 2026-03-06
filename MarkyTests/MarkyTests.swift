//
//  MarkyTests.swift
//  MarkyTests
//
//  Created by Predrag Drljaca on 3/5/26.
//

import Foundation
import Testing
@testable import Marky
#if os(macOS)
import AppKit
#endif

struct MarkyTests {

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
    @Test("markdown renderer keeps first heading flush without top paragraph spacing")
    func markdownRendererFirstHeadingHasNoLeadingParagraphSpacing() {
        let rendered = MarkdownRenderer.render(from: "# Title\n\nBody")
        #expect(rendered.string == "Title\nBody")

        let paragraph = rendered.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        #expect(paragraph != nil)
        #expect((paragraph?.paragraphSpacingBefore ?? -1) == 0)
    }

    @MainActor
    @Test("markdown renderer converts task/bullet list markers")
    func markdownRendererConvertsTaskAndBulletMarkers() {
        let rendered = MarkdownRenderer.render(from: "- [x] Done\n- [ ] Todo\n* Bullet")
        #expect(rendered.string == "☑ Done\n☐ Todo\n• Bullet")
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
    #endif

    private static func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MarkyTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(root)
    }
}
