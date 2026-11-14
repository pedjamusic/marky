import AppKit
import Testing
@testable import Marky

@MainActor
struct CoreMarkdownParserTests {
    @Test("Core blocks feed the native reader with its typography, markers and image metadata")
    func nativeBlocks() async throws {
        let source = """
        ## **Heading**

        Paragraph with ![image alt](inline.png) and [link](#heading).

        - Parent
          03) Child
            continuation
        - [ ] Todo
        - [x] Done

        > **Outer
        >> inner**
        >
        >>> [Deep](#heading)

        ~~~swift
        # Literal **code**
        ~~~

            indented code

        ---

        ![Local alt](<art/my image.png> "Local caption")
        ![Remote alt](HTTPS://example.org/image.png)
        """
        let mode = MarkdownTypographyMode.systemHeadingsSerifBody
        let size = MarkdownReaderTextSizePreset.slightlyBigger
        let blocks = try await renderBlocks(source, mode: mode, size: size)
        try #require(blocks.count == 9)
        #expect(blocks.map(\.id) == Array(0..<9))
        guard case .heading(let level, let heading) = blocks[0].kind,
              case .paragraph(let paragraph) = blocks[1].kind,
              case .list(let list) = blocks[2].kind,
              case .quote(let quote) = blocks[3].kind,
              case .code(let fenced) = blocks[4].kind,
              case .code(let indented) = blocks[5].kind,
              case .thematicBreak = blocks[6].kind,
              case .image(let localAlt, let localDestination, let localTitle) = blocks[7].kind,
              case .image(let remoteAlt, let remoteDestination, let remoteTitle) = blocks[8].kind
        else {
            Issue.record("Expected heading, paragraph, list, quote, two code blocks, rule and two images")
            return
        }
        let typography = MarkdownTypography(mode: mode, textSizePreset: size)
        #expect(level == 2)
        #expect(String(heading.characters) == "Heading")
        #expect(font(in: heading)?.pointSize == typography.headingFont(for: level).pointSize)
        #expect(String(paragraph.characters) == "Paragraph with image alt and link.")
        #expect(paragraph.runs.compactMap(\.link).map(\.absoluteString) == ["#heading"])
        #expect(font(in: paragraph)?.fontName == typography.bodyFont().fontName)
        #expect(list.map(\.id) == [0, 1, 2, 3])
        #expect(list.map(\.nestingLevel) == [0, 1, 0, 0])
        #expect(list.map(\.marker) == ["•", "03)", "☐", "☑"])
        #expect(list.map { String($0.body.characters) } == ["Parent", "Child\ncontinuation", "Todo", "Done"])
        #expect(String(quote.characters) == "Outer\n▎ inner\n\n▎ ▎ Deep")
        #expect(quote.runs.compactMap(\.link).map(\.absoluteString) == ["#heading"])
        let inner = try #require(quote.range(of: "▎ inner"))
        let innerFont = try #require(font(in: AttributedString(quote[inner])))
        #expect(NSFontManager.shared.traits(of: innerFont).contains(.boldFontMask))
        #expect(fenced == "# Literal **code**")
        #expect(indented == "indented code")
        #expect(localAlt == "Local alt")
        #expect(localDestination == "art/my image.png")
        #expect(localTitle == "Local caption")
        #expect(remoteAlt == "Remote alt")
        #expect(MarkdownImageView.remoteURL(from: remoteDestination)?.absoluteString == "https://example.org/image.png")
        #expect(remoteTitle == nil)
    }

    @Test("The core table renders column alignments, styled cells and padded short rows")
    func nativeTable() async throws {
        let blocks = try await renderBlocks("""
        | Leading | Center | Trailing |
        | :--- | :---: | ---: |
        | `x|y` | [**Link**](#table) | Right | Discarded |
        | Short |
        """)
        try #require(blocks.count == 1)
        guard case .table(let table) = blocks[0].kind else {
            Issue.record("Expected the native table")
            return
        }
        #expect(table.headers.map(\.alignment) == [.left, .center, .right])
        #expect(table.headers.map { String($0.content.characters) } == ["Leading", "Center", "Trailing"])
        #expect(table.rows.map(\.id) == [0, 1])
        #expect(table.rows.map { $0.cells.map(\.alignment) } == [[.left, .center, .right], [.left, .center, .right]])
        #expect(table.rows.map { $0.cells.map { String($0.content.characters) } } == [["x|y", "Link", "Right"], ["Short", "", ""]])
        let header = try #require(table.headers.first)
        let headerFont = try #require(font(in: header.content))
        #expect(NSFontManager.shared.traits(of: headerFont).contains(.boldFontMask))
        try #require(table.rows.first?.cells.count == 3)
        #expect(font(in: table.rows[0].cells[0].content)?.isFixedPitch == true)
        #expect(table.rows[0].cells[1].content.runs.first?.link?.absoluteString == "#table")
    }

    @Test("Nested quote indicators follow source lines, including empty nested lines")
    func nestedQuoteSourceLines() async throws {
        let blocks = try await renderBlocks("> 音🎵&#10;text\n>>\n>>> Child")
        guard case .quote(let quote) = try #require(blocks.first).kind else {
            Issue.record("Expected the native quote")
            return
        }
        #expect(String(quote.characters) == "音🎵\ntext\n▎ \n▎ ▎ Child")
    }

    private func renderBlocks(
        _ source: String, mode: MarkdownTypographyMode = .allSystem, size: MarkdownReaderTextSizePreset = .default
    ) async throws -> [MarkdownRenderedBlock] {
        let document = try await CoreMarkdownParser.parse(source)
        return MarkdownContentBlocks.render(coreDocument: document, mode: mode, textSizePreset: size, isDarkMode: true)
    }

    private func font(in text: AttributedString) -> NSFont? {
        let attributed = NSAttributedString(text)
        guard attributed.length > 0 else { return nil }
        return attributed.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
    }

    @Test("Empty core input returns no blocks")
    func emptyInput() async throws {
        let document = try await CoreMarkdownParser.parse("")
        #expect(document.blocks.isEmpty)
    }

    @Test("The native label receives the prepared paragraph's UTF-8 bytes")
    func nativeParagraph() async throws {
        let source = "Cafe\u{301} 東京 🎵  \r\n**literal**\0after\nlast\r"
        let document = try await CoreMarkdownParser.parse(source)
        #expect(document.blocks.count == 1)
        guard case .paragraph(let paragraph) = try #require(document.blocks.first) else {
            Issue.record("Expected a paragraph")
            return
        }
        let expected = "Cafe\u{301} 東京 🎵\n**literal**\0after last\r"
        #expect(Array(paragraph.utf8) == Array(expected.utf8))

        let label = NSTextField(labelWithAttributedString: NSAttributedString(string: paragraph))
        #expect(Array(label.attributedStringValue.string.utf8) == Array(expected.utf8))
    }

    @Test("Copied core runs render native styles and link destinations at their UTF-16 ranges")
    func nativeInlineRuns() async throws {
        let runs = try await CoreMarkdownParser.parse(
            "é e\u{301} 🎵 &amp; [***𐐀*** and `x`][target] ~~old~~ end\n\n"
                + "[target]: https://example.org/a(b)"
        ).inlineRuns(inBlock: 0)
        _ = try await CoreMarkdownParser.parse(String(repeating: "another document 🎵\n", count: 2048))
        let text = MarkdownRenderer.renderInline(from: runs)
        let label = NSTextField(labelWithAttributedString: text)
        let rendered = label.attributedStringValue
        #expect(Array(rendered.string.utf8) == Array("é e\u{301} 🎵 & 𐐀 and x old end".utf8))
        try #require(rendered.length == 26)

        var range = NSRange()
        let link = rendered.attribute(
            .link, at: 11, longestEffectiveRange: &range, in: NSRange(location: 0, length: rendered.length)
        ) as? URL
        #expect(link?.absoluteString == "https://example.org/a(b)")
        #expect(range == NSRange(location: 10, length: 8))
        #expect(rendered.attribute(.link, at: 9, effectiveRange: nil) == nil)
        #expect(rendered.attribute(.link, at: 18, effectiveRange: nil) == nil)

        let fontManager = NSFontManager.shared
        let boldItalic = try #require(rendered.attribute(.font, at: 10, effectiveRange: &range) as? NSFont)
        #expect(fontManager.traits(of: boldItalic).contains([.boldFontMask, .italicFontMask]))
        #expect(range == NSRange(location: 10, length: 2))
        let code = try #require(rendered.attribute(.font, at: 17, effectiveRange: &range) as? NSFont)
        #expect(code.isFixedPitch)
        #expect(range == NSRange(location: 17, length: 1))
        #expect(rendered.attribute(.backgroundColor, at: 17, effectiveRange: nil) != nil)
        let strike = rendered.attribute(.strikethroughStyle, at: 19, effectiveRange: &range) as? Int
        #expect(strike == NSUnderlineStyle.single.rawValue)
        #expect(range == NSRange(location: 19, length: 3))
    }

    @Test("Linked code preserves the reader's code colors and link underline")
    func linkedCodeAppearance() async throws {
        let source = "[**`x`**](https://example.org)"
        let document = try await CoreMarkdownParser.parse(source)
        let rendered = MarkdownRenderer.renderInline(from: document.inlineRuns(inBlock: 0), isDarkMode: true)
        let existing = MarkdownRenderer.renderInline(from: source, isDarkMode: true)
        #expect(rendered.string == "x")
        try #require(rendered.length == 1 && existing.length == 1)
        #expect(rendered.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
                == existing.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor)
        #expect(rendered.attribute(.backgroundColor, at: 0, effectiveRange: nil) as? NSColor
                == existing.attribute(.backgroundColor, at: 0, effectiveRange: nil) as? NSColor)
        let font = try #require(rendered.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        #expect(font.isFixedPitch && NSFontManager.shared.traits(of: font).contains(.boldFontMask))
        #expect(rendered.attribute(.underlineStyle, at: 0, effectiveRange: nil) as? Int != nil)
        #expect((rendered.attribute(.link, at: 0, effectiveRange: nil) as? URL)?.absoluteString == "https://example.org")
    }

    @Test("When a core run splits a grapheme, native styling follows the run that ends it")
    func splitGraphemes() async throws {
        let cases = [
            ("a*\u{301}b*c", "a\u{301}bc", NSRange(location: 0, length: 3)),
            ("*e*\u{301} next", "e\u{301} next", nil),
            ("***x***\u{301}", "x\u{301}", nil),
            ("*👩*\u{200D}🎤**b**", "👩\u{200D}🎤b", nil),
        ]
        for (source, expected, italicRange) in cases {
            let document = try await CoreMarkdownParser.parse(source)
            let rendered = MarkdownRenderer.renderInline(from: document.inlineRuns(inBlock: 0))
            #expect(Array(rendered.string.utf8) == Array(expected.utf8))
            var italicRanges: [NSRange] = []
            rendered.enumerateAttribute(.font, in: NSRange(location: 0, length: rendered.length)) { value, range, _ in
                if let font = value as? NSFont, NSFontManager.shared.traits(of: font).contains(.italicFontMask) {
                    italicRanges.append(range)
                }
            }
            #expect(italicRanges == (italicRange.map { [$0] } ?? []), "Markdown input: \(source)")
        }
        let document = try await CoreMarkdownParser.parse(
            "[👩](https://example.org)\u{200D}🎤 a[\u{301}b](#section)c"
        )
        let rendered = MarkdownRenderer.renderInline(from: document.inlineRuns(inBlock: 0))
        #expect(rendered.string == "👩\u{200D}🎤 a\u{301}bc")
        try #require(rendered.length == 10)
        var range = NSRange()
        let link = rendered.attribute(.link, at: 6, effectiveRange: &range) as? URL
        #expect(link?.absoluteString == "#section")
        #expect(range == NSRange(location: 6, length: 3))
        #expect(rendered.attribute(.link, at: 0, effectiveRange: nil) == nil)
        #expect(rendered.attribute(.link, at: 9, effectiveRange: nil) == nil)
    }

    @Test("Native inline rendering reads the right heading, list, quote, and table regions")
    func inlineRegions() async throws {
        let document = try await CoreMarkdownParser.parse("""
        # Heading

        - First
        - Second ![**alt**](image.png)

        > One
        > Two

        | Left | Right |
        | --- | --- |
        | Text | [link](<my file.md>) |
        | Padded |
        """)
        let heading = MarkdownRenderer.renderInline(from: document.inlineRuns(inBlock: 0), headingLevel: 1)
        #expect(heading.string == "Heading")
        #expect(MarkdownRenderer.renderInline(from: document.inlineRuns(inBlock: 1)).string == "First")
        #expect(MarkdownRenderer.renderInline(from: document.inlineRuns(inBlock: 1, row: 1)).string == "Second alt")
        #expect(MarkdownRenderer.renderInline(from: document.inlineRuns(inBlock: 2)).string == "One\nTwo")
        #expect(MarkdownRenderer.renderInline(from: document.inlineRuns(inBlock: 3, column: 1)).string == "Right")
        let cell = MarkdownRenderer.renderInline(from: document.inlineRuns(inBlock: 3, row: 1, column: 1))
        #expect(cell.string == "link")
        try #require(cell.length == 4)
        #expect((cell.attribute(.link, at: 0, effectiveRange: nil) as? URL)?.absoluteString == "my%20file.md")
        #expect(MarkdownRenderer.renderInline(from: document.inlineRuns(inBlock: 3, row: 2, column: 1)).length == 0)
    }

    @Test("The adapter copies ordered prose, literal code, and an empty fence")
    func fencedCode() async throws {
        let document = try await CoreMarkdownParser.parse("Before\r\n```\r\ne\u{301} 🎵\0\r\n```\r\n~~~\n~~~\nAfter")
        #expect(document.blocks == [.paragraph("Before"), .code("e\u{301} 🎵\0"), .code(""), .paragraph("After")])
        let code = try #require(document.blocks.dropFirst().first)
        if case .code(let text) = code {
            #expect(Array(text.utf8) == Array("e\u{301} 🎵\0".utf8))
        }
    }

    @Test("An already-cancelled task receives CancellationError")
    func alreadyCancelled() async {
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await CoreMarkdownParser.parse("Cancelled paragraph")
        }
        await #expect(throws: CancellationError.self) {
            try await task.value
        }
    }

    @Test("Concurrent operations keep independent documents")
    func independentDocuments() async throws {
        let first = String(repeating: "One 🎵\0\n", count: 4096)
        let second = String(repeating: "Deux e\u{301}\n", count: 4096)
        async let firstDocument = CoreMarkdownParser.parse(first)
        async let secondDocument = CoreMarkdownParser.parse(second)
        let (left, right) = try await (firstDocument, secondDocument)

        #expect(left.blocks == [.paragraph(Array(repeating: "One 🎵\0", count: 4096).joined(separator: " "))])
        #expect(right.blocks == [.paragraph(Array(repeating: "Deux e\u{301}", count: 4096).joined(separator: " "))])
    }
}
