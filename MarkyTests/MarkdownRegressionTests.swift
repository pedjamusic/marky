import Foundation
import AppKit
import Testing
@testable import Marky

@MainActor
struct MarkdownRegressionTests {
    @Test("Inline code stays literal through surrounding Unicode, links and bold")
    func literalCode() async throws {
        let rendered = try await coreText("🎵 [site](https://example.com) **bold** `**literal**` `[literal](https://example.com)`")
        #expect(rendered.string == "🎵 site bold **literal** [literal](https://example.com)")
        let literal = (rendered.string as NSString).range(of: "[literal]")
        #expect(rendered.attribute(.link, at: literal.location, effectiveRange: nil) == nil)
        #expect(rendered.attribute(.backgroundColor, at: literal.location, effectiveRange: nil) != nil)
    }

    @Test("Inline code pairs complete backtick runs and preserves embedded literal syntax")
    func codeDelimiterRuns() async throws {
        let rendered = try await coreText("Before ``code containing `tick` and **literal**`` after **bold**")
        #expect(rendered.string == "Before code containing `tick` and **literal** after bold")
        let literal = (rendered.string as NSString).range(of: "**literal**")
        #expect(rendered.attribute(.backgroundColor, at: literal.location, effectiveRange: nil) != nil)
        let unmatched = try await coreText("Before ``unclosed `tick` after")
        #expect(unmatched.string == "Before ``unclosed tick after")
        let whitespace = try await coreText("Before `` padded `` after")
        #expect(whitespace.string == "Before padded after")
        let newline = try await coreText("Before ``first\nsecond`` after")
        #expect(newline.string == "Before first second after")
    }

    @Test("Link labels may contain code while literal delimiters and destinations stay protected")
    func codeInLinkLabels() async throws {
        let rendered = try await coreText("[Use `tick` here](https://example.com) [prose `label](https://literal.example)`")
        #expect(rendered.string == "Use tick here [prose label](https://literal.example)")
        let code = (rendered.string as NSString).range(of: "tick")
        #expect(rendered.attribute(.link, at: code.location, effectiveRange: nil) != nil)
        #expect(rendered.attribute(.backgroundColor, at: code.location, effectiveRange: nil) != nil)
        let protected = (rendered.string as NSString).range(of: "label]")
        #expect(rendered.attribute(.link, at: protected.location, effectiveRange: nil) == nil)
        let bold = try await coreText("**before `literal` after**")
        #expect(bold.string == "before literal after")
        let boldCode = (bold.string as NSString).range(of: "literal")
        #expect(bold.attribute(.backgroundColor, at: boldCode.location, effectiveRange: nil) != nil)
    }

    @Test("Outer styles recognize punctuation inside protected code")
    func punctuationInsideStyledCode() async throws {
        let bold = try await coreText("**before `a*b` after**", mode: .systemHeadingsSerifBody)
        #expect(bold.string == "before a*b after")
        let proseFont = try #require(bold.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        #expect(NSFontManager.shared.traits(of: proseFont).contains(.boldFontMask))
        let codeRange = (bold.string as NSString).range(of: "a*b")
        let codeFont = try #require(bold.attribute(.font, at: codeRange.location, effectiveRange: nil) as? NSFont)
        #expect(codeFont.fontDescriptor.symbolicTraits.contains(.monoSpace))
        #expect(bold.attribute(.backgroundColor, at: codeRange.location, effectiveRange: nil) != nil)
        let linked = try await coreText("[Use `array[index]`](https://example.com)")
        #expect(linked.string == "Use array[index]")
        let literalRange = (linked.string as NSString).range(of: "array[index]")
        #expect(linked.attribute(.link, at: literalRange.location, effectiveRange: nil) as? URL == URL(string: "https://example.com"))
        #expect(linked.attribute(.backgroundColor, at: literalRange.location, effectiveRange: nil) != nil)
    }

    @Test("Edits before fenced code cannot shift literal protection")
    func codeOffsets() async throws {
        let rendered = try await coreText("🎵 [site](https://example.com) **bold**\n```\n**literal** [literal](https://example.com)\n```\n**after**")
        #expect(rendered.string == "🎵 site bold\n**literal** [literal](https://example.com)\nafter")
        let blocks = try await CoreMarkdownParser.parse("```\n**literal** [literal](https://example.com)\n```").blocks
        #expect(blocks == [.code("**literal** [literal](https://example.com)")])
    }

    @Test("Code fences close only on matching delimiter of sufficient length")
    func fenceDelimiters() async throws {
        for delimiter in ["````", "~~~~"] {
            let inner = delimiter.first == "`" ? "```" : "~~~"
            let source = "\(delimiter)example\n\(inner)\n**literal**\n\(delimiter) trailing text\n\(delimiter)\nAfter"
            let blocks = try await CoreMarkdownParser.parse(source).blocks
            #expect(blocks.count == 2)
            if case .code(let text) = blocks.first {
                #expect(text == "\(inner)\n**literal**\n\(delimiter) trailing text")
                let rendered = try await coreText(source)
                #expect(rendered.string == text + "\nAfter")
            } else {
                Issue.record("Expected one literal outer fence")
            }
        }
        let blocks = try await CoreMarkdownParser.parse("```\nunclosed **literal**").blocks
        if case .code(let text) = blocks.first {
            #expect(text == "unclosed **literal**")
        } else {
            Issue.record("Expected unclosed fence to preserve code")
        }
    }

    @Test("Indented fence-like lines stay literal until a valid closer")
    func indentedFenceClosers() async throws {
        for indent in ["    ", "\t"] {
            let source = "~~~\n\(indent)~~~\n**literal**\n~~~\nAfter"
            let prepared = try await CoreMarkdownParser.parse(source).blocks
            #expect(prepared.count == 2)
            if case .code(let text) = prepared.first {
                #expect(text == "\(indent)~~~\n**literal**")
            } else {
                Issue.record("Expected indented fence candidate to remain code")
            }
            let visible = try await coreText(source).string
            #expect(visible == "\(indent)~~~\n**literal**\nAfter")
        }
    }

    @Test("Combined bold links preserve link traits and the selected font family")
    func combinedStyles() async throws {
        for source in ["[**linked**](https://example.com)", "**[linked](https://example.com)**"] {
            let rendered = try await coreText(source, mode: .systemHeadingsSerifBody)
            #expect(rendered.string == "linked")
            #expect(rendered.attribute(.link, at: 0, effectiveRange: nil) != nil)
            let font = try #require(rendered.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
            let regular = try #require(try await coreText("regular", mode: .systemHeadingsSerifBody).attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
            #expect(font.familyName == regular.familyName)
            #expect(NSFontManager.shared.traits(of: font).contains(.boldFontMask))
        }
    }

    @Test("Nested list items have increasing depth and a visible inset")
    func nestedListInsets() async throws {
        let typography = MarkdownTypography(mode: .allSystem)
        #expect(typography.nestedListIndent > 0)
        let blocks = try await CoreMarkdownParser.parse("- parent\n  - child\n    - grandchild").blocks
        if case .list(let items) = blocks.first {
            #expect(items.map(\.depth) == [0, 1, 2])
        } else {
            Issue.record("Expected list hierarchy")
        }
    }

    @Test("Settings changed during and after a suspended load are used without rereading")
    func settingsDuringLoad() async throws {
        let loader = SuspendedMarkdownLoader()
        let doc = MarkdownDoc { url in try await loader.load(url) }
        let task = Task { await doc.load(from: URL(fileURLWithPath: "/document")) }
        await loader.waitForRequests(1)
        doc.rerenderFromPreparedBlocks(mode: .systemHeadingsSerifBody, textSizePreset: .slightlyBigger, isDarkMode: true)
        await loader.finish(0, text: "Prose `literal`")
        await task.value
        guard case .paragraph(let text) = doc.blocks.first?.kind else {
            Issue.record("Expected loaded prose")
            return
        }
        let attributed = NSAttributedString(text)
        let typography = MarkdownTypography(mode: .systemHeadingsSerifBody, textSizePreset: .slightlyBigger)
        let font = try #require(attributed.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        #expect(font.familyName == typography.bodyFont().familyName)
        #expect(abs(font.pointSize - typography.bodyFont().pointSize) < 0.01)
        let code = (attributed.string as NSString).range(of: "literal")
        let background = try #require(attributed.attribute(.backgroundColor, at: code.location, effectiveRange: nil) as? NSColor)
        #expect(background == typography.codeBackgroundColor(isDarkMode: true))

        doc.rerenderFromPreparedBlocks(mode: .allSystem, textSizePreset: .slightlySmaller, isDarkMode: false)
        guard case .paragraph(let restyled) = doc.blocks.first?.kind else {
            Issue.record("Expected cached prose after changing settings")
            return
        }
        let restyledText = NSAttributedString(restyled)
        let restyledTypography = MarkdownTypography(mode: .allSystem, textSizePreset: .slightlySmaller)
        let restyledFont = try #require(restyledText.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        #expect(restyledText.string == attributed.string)
        #expect(restyledFont.familyName == restyledTypography.bodyFont().familyName)
        #expect(abs(restyledFont.pointSize - restyledTypography.bodyFont().pointSize) < 0.01)
        let restyledBackground = restyledText.attribute(.backgroundColor, at: code.location, effectiveRange: nil) as? NSColor
        #expect(restyledBackground == restyledTypography.codeBackgroundColor(isDarkMode: false))
        #expect(await loader.requestCount == 1)
    }

    @Test("An already-cancelled late call cannot invalidate an active load")
    func alreadyCancelledLateCall() async {
        let loader = SuspendedMarkdownLoader()
        let doc = MarkdownDoc { url in try await loader.load(url) }
        let active = Task { await doc.load(from: URL(fileURLWithPath: "/active")) }
        await loader.waitForRequests(1)
        let late = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            await doc.load(from: URL(fileURLWithPath: "/cancelled-old"))
        }
        await late.value
        #expect(await loader.requestCount == 1)
        #expect(doc.isLoading)
        await loader.finish(0, text: "active content")
        await active.value
        if case .paragraph(let text) = doc.blocks.first?.kind {
            #expect(String(text.characters) == "active content")
        } else {
            Issue.record("Expected active load to retain its generation")
        }
    }

    @Test("An ordinary loader failure after cancellation stays silent")
    func cancelledOrdinaryFailure() async {
        let loader = SuspendedMarkdownLoader()
        let doc = MarkdownDoc { url in try await loader.load(url) }
        let task = Task { await doc.load(from: URL(fileURLWithPath: "/cancelled")) }
        await loader.waitForRequests(1)
        task.cancel()
        await loader.fail(0)
        await task.value
        #expect(!doc.isLoading)
        #expect(doc.blocks.isEmpty)
        #expect(doc.error == nil)
    }

    @Test("Superseded and cancelled document loads cannot publish stale content")
    func documentLifetime() async {
        let loader = SuspendedMarkdownLoader()
        let doc = MarkdownDoc { url in try await loader.load(url) }
        let first = Task { await doc.load(from: URL(fileURLWithPath: "/first")) }
        await loader.waitForRequests(1)
        let second = Task { await doc.load(from: URL(fileURLWithPath: "/second")) }
        await loader.waitForRequests(2)
        await loader.finish(1, text: "latest")
        await second.value
        await loader.finish(0, text: "stale")
        await first.value
        if case .paragraph(let text) = doc.blocks.first?.kind {
            #expect(String(text.characters) == "latest")
        } else {
            Issue.record("Expected latest request")
        }
        let cancelled = Task { await doc.load(from: URL(fileURLWithPath: "/cancelled")) }
        await loader.waitForRequests(3)
        cancelled.cancel()
        await loader.finish(2, text: "cancelled")
        await cancelled.value
        #expect(doc.blocks.isEmpty)
        #expect(!doc.isLoading)
        #expect(doc.error == nil)
    }

    @Test("The reader decodes UTF-8 and UTF-16 and recovers after a file read failure")
    func documentFileLoading() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }

        let utf8 = directory.appending(path: "utf8.md")
        let utf16 = directory.appending(path: "utf16.md")
        let source = "🎵 **Café**"
        try Data(source.utf8).write(to: utf8)
        try #require(source.data(using: .utf16)).write(to: utf16)

        let doc = MarkdownDoc()
        await doc.load(from: utf8)
        guard case .paragraph(let first) = doc.blocks.first?.kind else {
            Issue.record("Expected the UTF-8 file to render")
            return
        }
        #expect(String(first.characters) == "🎵 Café")

        await doc.load(from: directory.appending(path: "missing.md"))
        #expect(doc.blocks.isEmpty)
        #expect(!doc.isLoading)
        #expect(doc.error != nil)

        await doc.load(from: utf16)
        guard case .paragraph(let recovered) = doc.blocks.first?.kind else {
            Issue.record("Expected the UTF-16 file to render after a read failure")
            return
        }
        #expect(recovered == first)
        #expect(!doc.isLoading)
        #expect(doc.error == nil)
    }

    @Test("GFM pipe tables parse headers, alignments, and body rows")
    func tableBasicAndAlignment() async throws {
        let markdown = """
        | Left | Center | Right |
        | :--- | :---: | ---: |
        | L1 | C1 | R1 |
        | L2 | C2 | R2 |
        """
        let prepared = try await CoreMarkdownParser.parse(markdown).blocks
        #expect(prepared.count == 1)
        guard case .table(let table) = prepared.first else {
            Issue.record("Expected table block")
            return
        }
        #expect(table.headers == ["Left", "Center", "Right"])
        #expect(table.alignments == [.left, .center, .right])
        #expect(table.rows.map { Array($0) } == [["L1", "C1", "R1"], ["L2", "C2", "R2"]])

        let rendered = try await coreBlocks(markdown)
        #expect(rendered.count == 1)
        guard case .table(let renderedTable) = rendered.first?.kind else {
            Issue.record("Expected rendered table")
            return
        }
        #expect(renderedTable.headers.count == 3)
        #expect(renderedTable.headers[0].alignment == .left)
        #expect(renderedTable.headers[1].alignment == .center)
        #expect(renderedTable.headers[2].alignment == .right)
        #expect(renderedTable.rows.count == 2)
    }

    @Test("GFM tables handle escaped pipes and code spans containing pipes")
    func tablePipesEscapedAndInCode() async throws {
        let markdown = """
        | Syntax | Note |
        | --- | --- |
        | Escaped \\| pipe | Works |
        | `a | b` code | Also works |
        """
        let prepared = try await CoreMarkdownParser.parse(markdown).blocks
        #expect(prepared.count == 1)
        guard case .table(let table) = prepared.first else {
            Issue.record("Expected table block")
            return
        }
        #expect(table.headers == ["Syntax", "Note"])
        #expect(table.rows.count == 2)
        #expect(table.rows[0][0].contains("\\| pipe"))
        #expect(table.rows[1][0] == "`a | b` code")
    }

    @Test("GFM tables support missing outer boundary pipes")
    func tableAbsentOuterPipes() async throws {
        let markdown = """
        Name | Age | City
        --- | :---: | ---:
        Alice | 30 | London
        Bob | 25 | Paris
        """
        let prepared = try await CoreMarkdownParser.parse(markdown).blocks
        #expect(prepared.count == 1)
        guard case .table(let table) = prepared.first else {
            Issue.record("Expected table block without outer pipes")
            return
        }
        #expect(table.headers == ["Name", "Age", "City"])
        #expect(table.alignments == [.left, .center, .right])
        #expect(table.rows.count == 2)
    }

    @Test("GFM tables normalize missing or extra row cells")
    func tableUnevenCells() async throws {
        let markdown = """
        | Col A | Col B | Col C |
        | --- | --- | --- |
        | Only A |
        | A | B | C | Extra D |
        """
        let prepared = try await CoreMarkdownParser.parse(markdown).blocks
        guard case .table(let table) = prepared.first else {
            Issue.record("Expected table block")
            return
        }
        #expect(table.headers.count == 3)
        #expect(Array(table.rows[0]) == ["Only A", "", ""])
        #expect(Array(table.rows[1]) == ["A", "B", "C"])
    }

    @Test("Malformed delimiter rows fall back gracefully to paragraphs without dropping input")
    func tableMalformedFallback() async throws {
        let markdown = """
        | Col A | Col B |
        | --- | not-a-delimiter |
        | Val A | Val B |
        """
        let prepared = try await CoreMarkdownParser.parse(markdown).blocks
        let isTable = prepared.contains { block in
            if case .table = block { return true }
            return false
        }
        #expect(!isTable)
        #expect(prepared.count == 1)
        guard case .paragraph(let text) = prepared.first else {
            Issue.record("Expected paragraph fallback preserving entire source")
            return
        }
        #expect(text == "| Col A | Col B | | --- | not-a-delimiter | | Val A | Val B |")
        let rendered = try await coreText(markdown)
        #expect(rendered.string.contains("| Col A | Col B |"))
        #expect(rendered.string.contains("| --- | not-a-delimiter |"))
        #expect(rendered.string.contains("| Val A | Val B |"))
    }

    @Test("Italic emphasis supports stars and underscores while ignoring intra-word underscores")
    func italicEmphasis() async throws {
        let star = try await coreText("Before *star italic* after")
        #expect(star.string == "Before star italic after")
        let starRange = (star.string as NSString).range(of: "star italic")
        let starFont = star.attribute(.font, at: starRange.location, effectiveRange: nil) as? NSFont
        let hasItalicTrait = starFont.map { NSFontManager.shared.traits(of: $0).contains(.italicFontMask) } ?? false
        let hasObliqueness = star.attribute(.obliqueness, at: starRange.location, effectiveRange: nil) != nil
        #expect(hasItalicTrait || hasObliqueness)

        let underscore = try await coreText("Before _underscore italic_ after")
        #expect(underscore.string == "Before underscore italic after")

        let intraWord = try await coreText("variable_name_with_underscores")
        #expect(intraWord.string == "variable_name_with_underscores")
    }

    @Test("Double underscores and double stars both render as bold")
    func boldDoubleUnderscores() async throws {
        let underscoreBold = try await coreText("__bold underscore__")
        #expect(underscoreBold.string == "bold underscore")
        let uFont = try #require(underscoreBold.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        #expect(NSFontManager.shared.traits(of: uFont).contains(.boldFontMask))

        let starBold = try await coreText("**bold star**")
        #expect(starBold.string == "bold star")
        let sFont = try #require(starBold.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        #expect(NSFontManager.shared.traits(of: sFont).contains(.boldFontMask))
    }

    @Test("Triple stars and triple underscores render as combined bold and italic")
    func boldItalicCombined() async throws {
        let triple = try await coreText("***bold and italic***", mode: .systemHeadingsSerifBody)
        #expect(triple.string == "bold and italic")
        let font = try #require(triple.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        let regular = try #require(try await coreText("regular", mode: .systemHeadingsSerifBody).attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        #expect(font.familyName == regular.familyName)
        let traits = NSFontManager.shared.traits(of: font)
        #expect(traits.contains(.boldFontMask))
        let hasItalic = traits.contains(.italicFontMask) || triple.attribute(.obliqueness, at: 0, effectiveRange: nil) != nil
        #expect(hasItalic)

        let tripleUnderscore = try await coreText("___bold and italic underscore___", mode: .systemHeadingsSerifBody)
        #expect(tripleUnderscore.string == "bold and italic underscore")
        let uFont = try #require(tripleUnderscore.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        #expect(uFont.familyName == regular.familyName)
        let uTraits = NSFontManager.shared.traits(of: uFont)
        #expect(uTraits.contains(.boldFontMask))
        let uHasItalic = uTraits.contains(.italicFontMask) || tripleUnderscore.attribute(.obliqueness, at: 0, effectiveRange: nil) != nil
        #expect(uHasItalic)
    }

    @Test("Strikethrough applies single strikethrough line attribute")
    func strikethrough() async throws {
        let rendered = try await coreText("Before ~~deleted text~~ after")
        #expect(rendered.string == "Before deleted text after")
        let strikeRange = (rendered.string as NSString).range(of: "deleted text")
        let strikeVal = try #require(rendered.attribute(.strikethroughStyle, at: strikeRange.location, effectiveRange: nil) as? Int)
        #expect(strikeVal == NSUnderlineStyle.single.rawValue)
    }

    @Test("Backslash escapes prevent formatting while removing the backslash")
    func backslashEscapes() async throws {
        let rendered = try await coreText("\\*not italic\\* \\_not italic\\_ \\[not link\\]")
        #expect(rendered.string == "*not italic* _not italic_ [not link]")
        let firstStar = (rendered.string as NSString).range(of: "*not italic*")
        #expect(rendered.attribute(.link, at: firstStar.location, effectiveRange: nil) == nil)
    }

    @Test("Autolinks render with destination link attributes")
    func autolinks() async throws {
        let rendered = try await coreText("Visit <https://example.com/docs> today")
        #expect(rendered.string == "Visit https://example.com/docs today")
        let linkRange = (rendered.string as NSString).range(of: "https://example.com/docs")
        let url = try #require(rendered.attribute(.link, at: linkRange.location, effectiveRange: nil) as? URL)
        #expect(url.absoluteString == "https://example.com/docs")
    }

    @Test("Thematic breaks parse as thematicBreak blocks")
    func thematicBreaks() async throws {
        for rule in ["---", "***", "___", "- - -", "* * * *"] {
            let prepared = try await CoreMarkdownParser.parse(rule).blocks
            #expect(prepared.count == 1)
            guard case .thematicBreak = prepared.first else {
                Issue.record("Expected thematicBreak for '\(rule)'")
                continue
            }
        }
    }

    @Test("Setext headings are recognized from underline dashes or equals")
    func setextHeadings() async throws {
        let h1Markdown = "Heading 1\n========="
        let h1Blocks = try await CoreMarkdownParser.parse(h1Markdown).blocks
        #expect(h1Blocks.count == 1)
        if case .heading(let level, let source) = h1Blocks.first {
            #expect(level == 1)
            #expect(source == "Heading 1")
        } else {
            Issue.record("Expected Setext H1")
        }

        let h2Markdown = "Heading 2\n---------"
        let h2Blocks = try await CoreMarkdownParser.parse(h2Markdown).blocks
        #expect(h2Blocks.count == 1)
        if case .heading(let level, let source) = h2Blocks.first {
            #expect(level == 2)
            #expect(source == "Heading 2")
        } else {
            Issue.record("Expected Setext H2")
        }
    }

    @Test("List item continuations append to the item body")
    func listContinuation() async throws {
        let markdown = "- First line\n  Continuation line\n- Second item"
        let blocks = try await CoreMarkdownParser.parse(markdown).blocks
        #expect(blocks.count == 1)
        if case .list(let items) = blocks.first {
            #expect(items.count == 2)
            #expect(items[0].source == "First line\nContinuation line")
            #expect(items[1].source == "Second item")
        } else {
            Issue.record("Expected list with continuation")
        }
    }

    @Test("Task lists parse unchecked and checked states")
    func taskLists() async throws {
        let markdown = "- [ ] Todo task\n- [x] Done task\n- [X] Upper done task"
        let blocks = try await CoreMarkdownParser.parse(markdown).blocks
        if case .list(let items) = blocks.first {
            #expect(items.count == 3)
            #expect(items.map(\.marker) == [.task(checked: false), .task(checked: true), .task(checked: true)])
            #expect(items[0].source == "Todo task")
            #expect(items[1].source == "Done task")
            #expect(items[2].source == "Upper done task")
        } else {
            Issue.record("Expected task list items")
        }
    }

    @Test("Standalone images parse as image blocks and inline images render cleanly")
    func imagesStandaloneAndInline() async throws {
        let standalone = "![Marky Mascot](assets/mascot.png \"Mascot\")"
        let blocks = try await CoreMarkdownParser.parse(standalone).blocks
        #expect(blocks.count == 1)
        if case .image(let alt, let url, let title) = blocks.first {
            #expect(alt == "Marky Mascot")
            #expect(url == "assets/mascot.png")
            #expect(title == "Mascot")
        } else {
            Issue.record("Expected image block")
        }

        let inline = try await coreText("See ![icon](icon.png) inline")
        #expect(inline.string == "See icon inline")
    }

    @Test("Inline cell and list text cannot be mistaken for block markers or headings")
    func inlineTextCellHeadingIsolation() async throws {
        let blocks = try await coreBlocks("| # Not A Heading |\n| --- |\n| > Not A Quote |")
        guard case .table(let table) = blocks.first?.kind else {
            Issue.record("Expected table block")
            return
        }
        #expect(table.headers.map { String($0.content.characters) } == ["# Not A Heading"])
        #expect(table.rows.flatMap(\.cells).map { String($0.content.characters) } == ["> Not A Quote"])
    }

    @Test("Nested emphasis renders accurately both ways without leftover markers")
    func nestedEmphasisBothWays() async throws {
        let boldOuter = try await coreText("**bold and *italic***")
        #expect(boldOuter.string == "bold and italic")
        let boldFont = try #require(boldOuter.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        #expect(NSFontManager.shared.traits(of: boldFont).contains(.boldFontMask))
        let italicRange = (boldOuter.string as NSString).range(of: "italic")
        let biFont = try #require(boldOuter.attribute(.font, at: italicRange.location, effectiveRange: nil) as? NSFont)
        #expect(NSFontManager.shared.traits(of: biFont).contains(.boldFontMask))

        let italicOuter = try await coreText("*italic and **bold***")
        #expect(italicOuter.string == "italic and bold")
        let boldInnerRange = (italicOuter.string as NSString).range(of: "bold")
        let ibFont = try #require(italicOuter.attribute(.font, at: boldInnerRange.location, effectiveRange: nil) as? NSFont)
        #expect(NSFontManager.shared.traits(of: ibFont).contains(.boldFontMask))
    }

    @Test("Adjacent links and balanced destination parentheses parse cleanly")
    func adjacentLinksAndBalancedDestinations() async throws {
        let adjacent = try await coreText("[one](https://one.test)[two](https://two.test)")
        #expect(adjacent.string == "onetwo")
        let oneLink = try #require(adjacent.attribute(.link, at: 0, effectiveRange: nil) as? URL)
        #expect(oneLink.absoluteString == "https://one.test")
        let twoLink = try #require(adjacent.attribute(.link, at: 3, effectiveRange: nil) as? URL)
        #expect(twoLink.absoluteString == "https://two.test")

        let balanced = try await coreText("[Wiki](https://en.wikipedia.org/wiki/File_(format))")
        #expect(balanced.string == "Wiki")
        let wikiLink = try #require(balanced.attribute(.link, at: 0, effectiveRange: nil) as? URL)
        #expect(wikiLink.absoluteString == "https://en.wikipedia.org/wiki/File_(format)")
    }

    @Test("HTML entities and email autolinks decode and link natively")
    func htmlEntitiesAndEmailAutolinks() async throws {
        let entities = try await coreText("&copy; 2026 Marky &amp; Co. &lt;tag&gt; &#65;")
        #expect(entities.string == "© 2026 Marky & Co. <tag> A")

        let email = try await coreText("Contact <mailto:user@example.com>")
        #expect(email.string == "Contact mailto:user@example.com")
        let linkRange = (email.string as NSString).range(of: "mailto:user@example.com")
        let mailtoURL = try #require(email.attribute(.link, at: linkRange.location, effectiveRange: nil) as? URL)
        #expect(mailtoURL.absoluteString == "mailto:user@example.com")
    }

    @Test("Table recognition requires unescaped pipes and exact column match; Title followed by underlines becomes Setext")
    func tableExactHeaderDelimiterMatch() async throws {
        let setextH2 = "Title\n---"
        let h2Blocks = try await CoreMarkdownParser.parse(setextH2).blocks
        #expect(h2Blocks.count == 1)
        if case .heading(let level, let source) = h2Blocks.first {
            #expect(level == 2)
            #expect(source == "Title")
        } else {
            Issue.record("Expected Setext H2 for Title followed by ---")
        }

        let setextH1 = "Title\n==="
        let h1Blocks = try await CoreMarkdownParser.parse(setextH1).blocks
        #expect(h1Blocks.count == 1)
        if case .heading(let level, let source) = h1Blocks.first {
            #expect(level == 1)
            #expect(source == "Title")
        } else {
            Issue.record("Expected Setext H1 for Title followed by ===")
        }

        let mismatched = "| A | B | C |\n| --- | --- |\n| 1 | 2 |"
        let mismatchedBlocks = try await CoreMarkdownParser.parse(mismatched).blocks
        let isTable = mismatchedBlocks.contains { block in
            if case .table = block { return true }
            return false
        }
        #expect(!isTable)

        let valid = "| A | B |\n| :--- | ---: |\n| 1 | 2 |"
        let validBlocks = try await CoreMarkdownParser.parse(valid).blocks
        #expect(validBlocks.count == 1)
        if case .table(let table) = validBlocks.first {
            #expect(table.headers == ["A", "B"])
            #expect(table.alignments == [.left, .right])
        } else {
            Issue.record("Expected valid table for exact column match")
        }
    }

    @Test("Headings renderInline applies heading font size and tracking")
    func headingInlineFontAndTracking() async throws {
        let typography = MarkdownTypography(mode: .allSystem)
        let headingText = "Main Title"
        let rendered = try await coreText("# " + headingText)
        let font = try #require(rendered.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        let expectedFont = typography.headingFont(for: 1)
        #expect(abs(font.pointSize - expectedFont.pointSize) < 0.01)
        let kern = try #require(rendered.attribute(.kern, at: 0, effectiveRange: nil) as? CGFloat)
        #expect(abs(kern - typography.headingTracking) < 0.01)
    }

    @Test("Table headers render with bold font traits on the typography font family")
    func tableHeaderAttributedBoldTrait() async throws {
        let rendered = try await coreText("| Column Header |\n| --- |", mode: .systemHeadingsSerifBody)
        let font = try #require(rendered.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        #expect(NSFontManager.shared.traits(of: font).contains(.boldFontMask))
    }

    @Test("Indented code blocks are recognized from 4 leading spaces")
    func indentedCodeBlocks() async throws {
        let markdown = "Intro\n\n    let value = 42\n    print(value)\n\nAfter"
        let blocks = try await CoreMarkdownParser.parse(markdown).blocks
        #expect(blocks.count == 3)
        if case .code(let code) = blocks[1] {
            #expect(code == "let value = 42\nprint(value)")
        } else {
            Issue.record("Expected indented code block")
        }
    }

    @Test("Reference links resolve from document context definitions")
    func referenceLinksWithContext() async throws {
        let markdown = "[Learn Swift][swift]\n\n[swift]: https://swift.org"
        let blocks = try await CoreMarkdownParser.parse(markdown).blocks
        #expect(blocks.count == 1)
        let rendered = try await coreBlocks(markdown)
        guard case .paragraph(let text) = rendered.first?.kind else {
            Issue.record("Expected paragraph block")
            return
        }
        let attributed = NSAttributedString(text)
        #expect(attributed.string == "Learn Swift")
        let link = try #require(attributed.attribute(.link, at: 0, effectiveRange: nil) as? URL)
        #expect(link.absoluteString == "https://swift.org")
    }

    @Test("Reference links resolve across fences while code and escaped brackets remain literal")
    func referenceLinksAcrossFencesAndCodeIsolation() async throws {
        let markdown = """
        [go][ref]

        ```swift
        let codeRef = "[go][ref]"
        ```

        Here is `[go][ref]` in code span and \\[go\\]\\[ref\\] escaped.

        [ref]: https://example.com/target
        """
        let rendered = try await coreText(markdown)
        let str = rendered.string
        let nsStr = str as NSString

        // 1. [go][ref] before fence resolved
        let rawFirstGo = nsStr.range(of: "go")
        let firstGoRange = try #require(rawFirstGo.location != NSNotFound ? rawFirstGo : nil)
        let link = try #require(rendered.attribute(.link, at: firstGoRange.location, effectiveRange: nil) as? URL)
        #expect(link.absoluteString == "https://example.com/target")
        #expect(rendered.attribute(.backgroundColor, at: firstGoRange.location, effectiveRange: nil) == nil)

        // 2. Fenced occurrence first: remains literal
        let rawFencedSubstring = nsStr.range(of: "let codeRef = \"[go][ref]\"")
        let fencedSubstringRange = try #require(rawFencedSubstring.location != NSNotFound ? rawFencedSubstring : nil)
        let rawFencedRef = nsStr.range(of: "[go][ref]", options: [], range: fencedSubstringRange)
        let requiredFenced = try #require(rawFencedRef.location != NSNotFound ? rawFencedRef : nil)
        #expect(rendered.attribute(.link, at: requiredFenced.location, effectiveRange: nil) == nil)

        // 3. Inline occurrence search AFTER fenced substring
        let searchAfterFence = NSRange(
            location: fencedSubstringRange.location + fencedSubstringRange.length,
            length: nsStr.length - (fencedSubstringRange.location + fencedSubstringRange.length)
        )
        let inlineCodeRange = nsStr.range(of: "[go][ref]", options: [], range: searchAfterFence)
        let requiredInline = try #require(inlineCodeRange.location != NSNotFound ? inlineCodeRange : nil)
        #expect(rendered.attribute(.link, at: requiredInline.location, effectiveRange: nil) == nil)
        #expect(rendered.attribute(.backgroundColor, at: requiredInline.location, effectiveRange: nil) != nil)

        // 4. Escaped occurrence search AFTER inline occurrence
        let searchAfterInline = NSRange(
            location: requiredInline.location + requiredInline.length,
            length: nsStr.length - (requiredInline.location + requiredInline.length)
        )
        let escapedRange = nsStr.range(of: "[go][ref]", options: [], range: searchAfterInline)
        let requiredEscaped = try #require(escapedRange.location != NSNotFound ? escapedRange : nil)
        #expect(rendered.attribute(.link, at: requiredEscaped.location, effectiveRange: nil) == nil)
        #expect(rendered.attribute(.backgroundColor, at: requiredEscaped.location, effectiveRange: nil) == nil)
    }

    @Test("Four-space indented reference definition is preserved as literal code")
    func indentedReferenceDefinitionPreservedAsCode() async throws {
        let markdown = """
        Intro paragraph

            [ref]: https://example.com

        After paragraph
        """
        let blocks = try await CoreMarkdownParser.parse(markdown).blocks
        #expect(blocks.count == 3)
        if case .code(let code) = blocks[1] {
            #expect(code == "[ref]: https://example.com")
        } else {
            Issue.record("Expected indented code block containing definition syntax")
        }
    }

    @Test("Nested blockquotes render stacked quote bars")
    func nestedBlockquotesRendering() async throws {
        let blocks = try await coreBlocks("> Outer\n> > Inner")
        #expect(blocks.count == 1)
        guard case .quote(let text) = blocks.first?.kind else {
            Issue.record("Expected quote block")
            return
        }
        // The view draws the outer bar; the text carries one indicator per further level.
        #expect(String(text.characters) == "Outer\n▎ Inner")
    }

    @Test("Same-label links with different or identical URLs process in source order without styling collisions")
    func sameLabelLinksWithDifferentAndSameURLs() async throws {
        let diffMarkdown = "[same](https://a.test) [**same**](https://b.test)"
        let diffRendered = try await coreText(diffMarkdown)
        #expect(diffRendered.string == "same same")

        let firstSameRange = NSRange(location: 0, length: 4)
        let firstLink = try #require(diffRendered.attribute(.link, at: firstSameRange.location, effectiveRange: nil) as? URL)
        #expect(firstLink.absoluteString == "https://a.test")
        let firstFont = try #require(diffRendered.attribute(.font, at: firstSameRange.location, effectiveRange: nil) as? NSFont)
        #expect(!NSFontManager.shared.traits(of: firstFont).contains(.boldFontMask))

        let secondSameRange = NSRange(location: 5, length: 4)
        let secondLink = try #require(diffRendered.attribute(.link, at: secondSameRange.location, effectiveRange: nil) as? URL)
        #expect(secondLink.absoluteString == "https://b.test")
        let secondFont = try #require(diffRendered.attribute(.font, at: secondSameRange.location, effectiveRange: nil) as? NSFont)
        #expect(NSFontManager.shared.traits(of: secondFont).contains(.boldFontMask))

        let sameMarkdown = "[target](https://same.test) [**target**](https://same.test)"
        let sameRendered = try await coreText(sameMarkdown)
        #expect(sameRendered.string == "target target")
        let secondTargetRange = NSRange(location: 7, length: 6)
        let secondTargetFont = try #require(sameRendered.attribute(.font, at: secondTargetRange.location, effectiveRange: nil) as? NSFont)
        #expect(NSFontManager.shared.traits(of: secondTargetFont).contains(.boldFontMask))
    }

    @Test("Outer bold with inner italic inside link preserves both traits")
    func outerBoldWithInnerItalicInLink() async throws {
        let markdown = "**[linked *italic* here](https://example.com)**"
        let rendered = try await coreText(markdown)
        #expect(rendered.string == "linked italic here")

        let linkedRange = (rendered.string as NSString).range(of: "linked")
        let linkedFont = try #require(rendered.attribute(.font, at: linkedRange.location, effectiveRange: nil) as? NSFont)
        #expect(NSFontManager.shared.traits(of: linkedFont).contains(.boldFontMask))
        #expect(rendered.attribute(.link, at: linkedRange.location, effectiveRange: nil) != nil)

        let italicRange = (rendered.string as NSString).range(of: "italic")
        let italicFont = try #require(rendered.attribute(.font, at: italicRange.location, effectiveRange: nil) as? NSFont)
        let italicTraits = NSFontManager.shared.traits(of: italicFont)
        #expect(italicTraits.contains(.boldFontMask))
        let hasItalic = italicTraits.contains(.italicFontMask) || rendered.attribute(.obliqueness, at: italicRange.location, effectiveRange: nil) != nil
        #expect(hasItalic)
    }

    @Test("Local image path resolution handles relative parent traversal and distinguishes remote URLs")
    func localImagePathResolutionAndAccessibility() {
        let docURL = URL(fileURLWithPath: "/Users/test/Project/docs/GUIDE.md")

        let sibling = MarkdownImageView.resolveLocalFileURL(for: "screenshot.png", relativeTo: docURL)
        #expect(sibling?.path == "/Users/test/Project/docs/screenshot.png")

        let percentEncoded = MarkdownImageView.resolveLocalFileURL(for: "image%20name.png", relativeTo: docURL)
        #expect(percentEncoded?.path == "/Users/test/Project/docs/image name.png")

        let rawSpaces = MarkdownImageView.resolveLocalFileURL(for: "image name.png", relativeTo: docURL)
        #expect(rawSpaces?.path == "/Users/test/Project/docs/image name.png")

        let parentTraversal = MarkdownImageView.resolveLocalFileURL(for: "../assets/my%20icon.png", relativeTo: docURL)
        #expect(parentTraversal?.path == "/Users/test/Project/assets/my icon.png")

        let fileURL = MarkdownImageView.resolveLocalFileURL(for: "file:///Users/test/Project/assets/icon.png", relativeTo: docURL)
        #expect(fileURL?.path == "/Users/test/Project/assets/icon.png")

        let remote = MarkdownImageView.resolveLocalFileURL(for: "https://example.com/mascot.png", relativeTo: docURL)
        #expect(remote == nil)

        let ftpScheme = MarkdownImageView.resolveLocalFileURL(for: "ftp://example.com/mascot.png", relativeTo: docURL)
        #expect(ftpScheme == nil)

        let dataScheme = MarkdownImageView.resolveLocalFileURL(for: "data:image/png;base64,AAAA", relativeTo: docURL)
        #expect(dataScheme == nil)
    }

    @Test("Table geometry tokens enforce sensible cell min and max bounds")
    func tableGeometryTokens() {
        #expect(MarkyTheme.tableCellMinWidth >= 60)
        #expect(MarkyTheme.tableCellMaxWidth <= 450)
        #expect(MarkyTheme.tableCellMinWidth < MarkyTheme.tableCellMaxWidth)
    }

    @Test("Reference label normalization collapses internal whitespace and case-folds consistently, keeping first definition")
    func referenceLabelNormalization() async throws {
        let markdown = """
        [Test Label][a  b] and [Shortcut][a b] and [Uppercase][A   B]

        [a b]: https://example.com/first
        [a  b]: https://example.com/second
        """
        let rendered = try await coreText(markdown)
        #expect(rendered.string == "Test Label and Shortcut and Uppercase")
        for label in ["Test Label", "Shortcut", "Uppercase"] {
            let range = (rendered.string as NSString).range(of: label)
            try #require(range.location != NSNotFound)
            let link = rendered.attribute(.link, at: range.location, effectiveRange: nil) as? URL
            #expect(link?.absoluteString == "https://example.com/first", "\(label)")
        }
    }

    @Test("Invalid reference destinations remain in source text and are not removed")
    func invalidReferenceDestinationPreserved() async throws {
        let markdown = """
        Intro paragraph

        [bad1]: http://[bad
        [bad2]: <http://[bad>

        After paragraph
        """
        let rendered = try await coreText(markdown)
        #expect(rendered.string.contains("[bad1]: http://[bad"))
        #expect(rendered.string.contains("[bad2]: http://[bad"))
    }

    @Test("Table bodies accept pipe-free short rows and terminate on real block boundaries")
    func tableShortRowsAndQuotedPipes() async throws {
        let shortRowMarkdown = """
        | Header 1 | Header 2 | Header 3 |
        | :--- | :---: | ---: |
        | C1 | C2 | C3 |
        Single Cell Only

        Following paragraph after blank line.
        """
        let preparedShort = try await CoreMarkdownParser.parse(shortRowMarkdown).blocks
        #expect(preparedShort.count == 2)
        if case .table(let table) = preparedShort[0] {
            #expect(table.headers.count == 3)
            #expect(table.rows.map { Array($0) } == [["C1", "C2", "C3"], ["Single Cell Only", "", ""]])
        } else {
            Issue.record("Expected table block with padded short row")
        }
        if case .paragraph(let text) = preparedShort[1] {
            #expect(text.contains("Following paragraph"))
        } else {
            Issue.record("Expected following paragraph preserved")
        }

        let quoteMarkdown = """
        | Col A | Col B |
        | --- | --- |
        | Val A | Val B |
        > Quoted block | with | pipes
        """
        let preparedQuote = try await CoreMarkdownParser.parse(quoteMarkdown).blocks
        #expect(preparedQuote.count == 2)
        if case .table(let table) = preparedQuote[0] {
            #expect(table.headers == ["Col A", "Col B"])
            #expect(table.rows.map { Array($0) } == [["Val A", "Val B"]])
        } else {
            Issue.record("Expected table to terminate before quote")
        }
        if case .quote(let lines) = preparedQuote[1] {
            #expect(lines.map(\.source) == ["Quoted block | with | pipes"])
        } else {
            Issue.record("Expected quote block containing pipes")
        }
    }

    @Test("Table splitting and pipe recognition share backtick matching semantics",
          arguments: [
            ("`literal tick | second cell", ["`literal tick", "second cell"]),
            ("`a | b` | second cell", ["`a | b`", "second cell"]),
            ("``nested `tick` | inner`` | outer cell", ["``nested `tick` | inner``", "outer cell"])
          ])
    func tableCodeSpanBackticks(row: String, cells: [String]) async throws {
        let blocks = try await CoreMarkdownParser.parse("A | B\n--- | ---\n" + row).blocks
        guard case .table(let table) = blocks.first else {
            Issue.record("Expected table block")
            return
        }
        #expect(table.rows.map { Array($0) } == [cells])
    }

    @Test("Pipes inside code or behind a backslash do not make a header row",
          arguments: ["`pipe | inside code`", "``double `tick` | code``", "escaped \\| pipe only"])
    func protectedPipesAreNotTables(header: String) async throws {
        let blocks = try await CoreMarkdownParser.parse(header + "\n---").blocks
        #expect(!blocks.contains { if case .table = $0 { true } else { false } })
    }

    @Test("Standalone images accept angle-bracket destinations with spaces and reject unbracketed spaces")
    func standaloneImageAngleBracketSpaces() async throws {
        let titled = try await CoreMarkdownParser.parse("![Alt text](<my photo.png> \"Image Title\")").blocks
        #expect(titled == [.image(alt: "Alt text", destination: "my photo.png", title: "Image Title")])
        let untitled = try await CoreMarkdownParser.parse("![Alt text](<path/with spaces/image.jpg>)").blocks
        #expect(untitled == [.image(alt: "Alt text", destination: "path/with spaces/image.jpg", title: nil)])
        for source in ["![Alt text](my photo.png)", "![Alt text](my photo.png \"Title\")"] {
            let blocks = try await CoreMarkdownParser.parse(source).blocks
            #expect(!blocks.contains { if case .image = $0 { true } else { false } }, "\(source)")
        }
    }

    @Test("Explicit undefined reference links remain untouched and destination parentheses serialize safely")
    func explicitUndefinedReferenceLinks() async throws {
        let markdown = """
        [foo][missing] and [unknown][foo] and [foo][] and [parens][dest_parens]

        [foo]: https://example.com/foo
        [dest_parens]: https://example.com/a)b
        """
        let rendered = try await coreText(markdown)
        let str = rendered.string
        let nsStr = str as NSString

        // 1. [foo][missing] where 'foo' is defined but 'missing' is undefined: remains literal untouched text, not linked
        #expect(str.contains("[foo][missing]"))
        let rawFooMissing = nsStr.range(of: "[foo][missing]")
        let fooMissingRange = try #require(rawFooMissing.location != NSNotFound ? rawFooMissing : nil)
        #expect(rendered.attribute(.link, at: fooMissingRange.location, effectiveRange: nil) == nil)

        // 2. [unknown][foo] where 'foo' is defined is a valid full reference: renders label 'unknown' linked to foo URL
        let rawUnknown = nsStr.range(of: "unknown")
        let unknownRange = try #require(rawUnknown.location != NSNotFound ? rawUnknown : nil)
        let unknownLink = try #require(rendered.attribute(.link, at: unknownRange.location, effectiveRange: nil) as? URL)
        #expect(unknownLink.absoluteString == "https://example.com/foo")

        // 3. [foo][] with defined foo expands
        let searchAfterUnknown = NSRange(
            location: unknownRange.location + unknownRange.length,
            length: nsStr.length - (unknownRange.location + unknownRange.length)
        )
        let rawFoo = nsStr.range(of: "foo", options: [], range: searchAfterUnknown)
        let fooRange = try #require(rawFoo.location != NSNotFound ? rawFoo : nil)
        let fooLink = try #require(rendered.attribute(.link, at: fooRange.location, effectiveRange: nil) as? URL)
        #expect(fooLink.absoluteString == "https://example.com/foo")

        // 4. [dest_parens] with UNMATCHED close parenthesis in destination expands with angle brackets and no trailing content
        let rawParens = nsStr.range(of: "parens")
        let parensRange = try #require(rawParens.location != NSNotFound ? rawParens : nil)
        let parensLink = try #require(rendered.attribute(.link, at: parensRange.location, effectiveRange: nil) as? URL)
        #expect(parensLink.absoluteString == "https://example.com/a)b")
        #expect(!str.contains(")b"))
    }

    @Test("Remote URL scheme normalization validates case-insensitive HTTPS before dispatch")
    func remoteURLSchemeNormalization() {
        let upperHTTPS = MarkdownImageView.remoteURL(from: "HTTPS://example.com/mascot.png")
        #expect(upperHTTPS?.scheme == "https")
        #expect(upperHTTPS?.absoluteString == "https://example.com/mascot.png")

        let mixedHTTP = MarkdownImageView.remoteURL(from: "hTtP://example.com/banner.jpg")
        #expect(mixedHTTP?.scheme == "http")
        #expect(mixedHTTP?.absoluteString == "http://example.com/banner.jpg")

        #expect(MarkdownImageView.remoteURL(from: "file:///Users/test/photo.png") == nil)
        #expect(MarkdownImageView.remoteURL(from: "ftp://example.com/file.png") == nil)
        #expect(MarkdownImageView.remoteURL(from: "javascript:alert(1)") == nil)
        #expect(MarkdownImageView.remoteURL(from: "not a url") == nil)
    }

    @Test("Local image loader manages security-scoped resource access and balances stopAccessing")
    func localImageLoaderAccess() async throws {
        final class MockResourceAccess: ProjectResourceAccessing {
            var startCount = 0
            var stopCount = 0

            func startAccessing(_ url: URL) -> Bool {
                startCount += 1
                return true
            }

            func stopAccessing(_ url: URL) {
                stopCount += 1
            }
        }

        let mock = MockResourceAccess()
        let tempDir = FileManager.default.temporaryDirectory
        let nonExistentURL = tempDir.appendingPathComponent("non_existent_\(UUID().uuidString).png")

        // 1. Failure: Missing file throws typed error and balances stopAccessing
        await #expect(throws: LocalImageLoadError.self) {
            try await LocalImageLoader.loadImage(at: nonExistentURL, under: tempDir, resourceAccess: mock)
        }
        #expect(mock.startCount == 1)
        #expect(mock.stopCount == 1)

        // 2. Success: Valid image loads and balances stopAccessing
        let validURL = tempDir.appendingPathComponent("valid_test_\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: validURL) }
        let rep = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .calibratedRGB, bytesPerRow: 8, bitsPerPixel: 32))
        let pngData = try #require(rep.representation(using: .png, properties: [:]))
        try pngData.write(to: validURL)
        let loaded = try await LocalImageLoader.loadImage(at: validURL, under: tempDir, resourceAccess: mock)
        #expect(loaded.size.width > 0)
        #expect(mock.startCount == 2)
        #expect(mock.stopCount == 2)

        // 3. Cancellation: Cancelled task asserts CancellationError and balances start/stop
        let cancelMock = MockResourceAccess()
        let cancelTask = Task { @MainActor in
            withUnsafeCurrentTask { $0?.cancel() }
            return try await LocalImageLoader.loadImage(at: nonExistentURL, under: tempDir, resourceAccess: cancelMock)
        }
        do {
            _ = try await cancelTask.value
            Issue.record("Expected cancellation error to be thrown")
        } catch is CancellationError {
            // Expected CancellationError
        } catch {
            Issue.record("Expected CancellationError but got \(error)")
        }
        #expect(cancelMock.startCount == 1)
        #expect(cancelMock.stopCount == 1)
    }
}

private actor SuspendedMarkdownLoader {
    private var pending: [CheckedContinuation<String, Error>] = []
    private var waiter: (count: Int, continuation: CheckedContinuation<Void, Never>)?
    var requestCount: Int { pending.count }

    func load(_ url: URL) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            pending.append(continuation)
            if let waiter, pending.count >= waiter.count {
                self.waiter = nil
                waiter.continuation.resume()
            }
        }
    }

    func waitForRequests(_ count: Int) async {
        guard pending.count < count else { return }
        await withCheckedContinuation { waiter = (count, $0) }
    }

    func fail(_ index: Int) {
        pending[index].resume(throwing: CocoaError(.fileReadNoSuchFile))
    }

    func finish(_ index: Int, text: String) {
        pending[index].resume(returning: text)
    }
}
