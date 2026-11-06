import Foundation
import AppKit
import Testing
@testable import Marky

@MainActor
struct MarkdownRegressionTests {
    @Test("Inline code stays literal through surrounding Unicode, links and bold")
    func literalCode() {
        let rendered = MarkdownRenderer.render(from: "🎵 [site](https://example.com) **bold** `**literal**` `[literal](https://example.com)`")
        #expect(rendered.string == "🎵 site bold **literal** [literal](https://example.com)")
        let literal = (rendered.string as NSString).range(of: "[literal]")
        #expect(rendered.attribute(.link, at: literal.location, effectiveRange: nil) == nil)
        #expect(rendered.attribute(.backgroundColor, at: literal.location, effectiveRange: nil) != nil)
    }

    @Test("Inline code pairs complete backtick runs and preserves embedded literal syntax")
    func codeDelimiterRuns() {
        let rendered = MarkdownRenderer.render(from: "Before ``code containing `tick` and **literal**`` after **bold**")
        #expect(rendered.string == "Before code containing `tick` and **literal** after bold")
        let literal = (rendered.string as NSString).range(of: "**literal**")
        #expect(rendered.attribute(.backgroundColor, at: literal.location, effectiveRange: nil) != nil)
        let unmatched = MarkdownRenderer.render(from: "Before ``unclosed `tick` after")
        #expect(unmatched.string == "Before ``unclosed tick after")
        let whitespace = MarkdownRenderer.render(from: "Before `` padded `` after")
        #expect(whitespace.string == "Before padded after")
        let newline = MarkdownRenderer.render(from: "Before ``first\nsecond`` after")
        #expect(newline.string == "Before ``first\nsecond`` after")
    }

    @Test("Link labels may contain code while literal delimiters and destinations stay protected")
    func codeInLinkLabels() {
        let rendered = MarkdownRenderer.render(from: "[Use `tick` here](https://example.com) [prose `label](https://literal.example)`")
        #expect(rendered.string == "Use tick here [prose label](https://literal.example)")
        let code = (rendered.string as NSString).range(of: "tick")
        #expect(rendered.attribute(.link, at: code.location, effectiveRange: nil) != nil)
        #expect(rendered.attribute(.backgroundColor, at: code.location, effectiveRange: nil) != nil)
        let protected = (rendered.string as NSString).range(of: "label]")
        #expect(rendered.attribute(.link, at: protected.location, effectiveRange: nil) == nil)
        let bold = MarkdownRenderer.render(from: "**before `literal` after**")
        #expect(bold.string == "before literal after")
        let boldCode = (bold.string as NSString).range(of: "literal")
        #expect(bold.attribute(.backgroundColor, at: boldCode.location, effectiveRange: nil) != nil)
    }

    @Test("Outer styles recognize punctuation inside protected code")
    func punctuationInsideStyledCode() throws {
        let bold = MarkdownRenderer.render(from: "**before `a*b` after**", mode: .systemHeadingsSerifBody)
        #expect(bold.string == "before a*b after")
        let proseFont = try #require(bold.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        #expect(NSFontManager.shared.traits(of: proseFont).contains(.boldFontMask))
        let codeRange = (bold.string as NSString).range(of: "a*b")
        let codeFont = try #require(bold.attribute(.font, at: codeRange.location, effectiveRange: nil) as? NSFont)
        #expect(codeFont.fontDescriptor.symbolicTraits.contains(.monoSpace))
        #expect(bold.attribute(.backgroundColor, at: codeRange.location, effectiveRange: nil) != nil)
        let linked = MarkdownRenderer.render(from: "[Use `array[index]`](https://example.com)")
        #expect(linked.string == "Use array[index]")
        let literalRange = (linked.string as NSString).range(of: "array[index]")
        #expect(linked.attribute(.link, at: literalRange.location, effectiveRange: nil) as? URL == URL(string: "https://example.com"))
        #expect(linked.attribute(.backgroundColor, at: literalRange.location, effectiveRange: nil) != nil)
    }

    @Test("Edits before fenced code cannot shift literal protection")
    func codeOffsets() {
        let rendered = MarkdownRenderer.render(from: "🎵 [site](https://example.com) **bold**\n```\n**literal** [literal](https://example.com)\n```\n**after**")
        #expect(rendered.string == "🎵 site bold\n**literal** [literal](https://example.com)\nafter")
        let code = (rendered.string as NSString).range(of: "**literal**")
        #expect(rendered.attribute(.backgroundColor, at: code.location, effectiveRange: nil) != nil)
    }

    @Test("Code fences close only on matching delimiter of sufficient length")
    func fenceDelimiters() {
        for delimiter in ["````", "~~~~"] {
            let inner = delimiter.first == "`" ? "```" : "~~~"
            let source = "\(delimiter)example\n\(inner)\n**literal**\n\(delimiter) trailing text\n\(delimiter)\nAfter"
            let blocks = MarkdownContentBlocks.prepare(from: source)
            #expect(blocks.count == 2)
            if case .code(let text) = blocks.first?.kind {
                #expect(text == "\(inner)\n**literal**\n\(delimiter) trailing text")
                let rendered = MarkdownRenderer.render(from: source)
                #expect(rendered.string == text + "\nAfter")
            } else {
                Issue.record("Expected one literal outer fence")
            }
        }
        let blocks = MarkdownContentBlocks.prepare(from: "```\nunclosed **literal**")
        if case .code(let text) = blocks.first?.kind {
            #expect(text == "unclosed **literal**")
        } else {
            Issue.record("Expected unclosed fence to preserve code")
        }
    }

    @Test("Indented fence-like lines stay literal until a valid closer")
    func indentedFenceClosers() {
        for indent in ["    ", "\t"] {
            let source = "~~~\n\(indent)~~~\n**literal**\n~~~\nAfter"
            let prepared = MarkdownContentBlocks.prepare(from: source)
            #expect(prepared.count == 2)
            if case .code(let text) = prepared.first?.kind {
                #expect(text == "\(indent)~~~\n**literal**")
            } else {
                Issue.record("Expected indented fence candidate to remain code")
            }
            #expect(MarkdownRenderer.render(from: source).string == "\(indent)~~~\n**literal**\nAfter")
        }
    }

    @Test("Combined bold links preserve link traits and the selected font family")
    func combinedStyles() throws {
        for source in ["[**linked**](https://example.com)", "**[linked](https://example.com)**"] {
            let rendered = MarkdownRenderer.render(from: source, mode: .systemHeadingsSerifBody)
            #expect(rendered.string == "linked")
            #expect(rendered.attribute(.link, at: 0, effectiveRange: nil) != nil)
            let font = try #require(rendered.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
            let regular = try #require(MarkdownRenderer.render(from: "regular", mode: .systemHeadingsSerifBody).attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
            #expect(font.familyName == regular.familyName)
            #expect(NSFontManager.shared.traits(of: font).contains(.boldFontMask))
        }
    }

    @Test("Nested list inset is visible while the established top-level rail stays flush")
    func nestedListInsets() {
        let typography = MarkdownTypography(mode: .allSystem)
        #expect(typography.listIndent == 0)
        #expect(typography.nestedListIndent > 0)
        let blocks = MarkdownContentBlocks.prepare(from: "- parent\n  - child\n    - grandchild")
        if case .list(let items) = blocks.first?.kind {
            #expect(items.map(\.nestingLevel) == [0, 1, 2])
        } else {
            Issue.record("Expected list hierarchy")
        }
    }

    @Test("Settings changed during a suspended load are used without rereading")
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

    @Test("GFM pipe tables parse headers, alignments, and body rows")
    func tableBasicAndAlignment() {
        let markdown = """
        | Left | Center | Right |
        | :--- | :---: | ---: |
        | L1 | C1 | R1 |
        | L2 | C2 | R2 |
        """
        let prepared = MarkdownContentBlocks.prepare(from: markdown)
        #expect(prepared.count == 1)
        guard case .table(let headers, let alignments, let rows) = prepared.first?.kind else {
            Issue.record("Expected table block")
            return
        }
        #expect(headers == ["Left", "Center", "Right"])
        #expect(alignments == [.left, .center, .right])
        #expect(rows.count == 2)
        #expect(rows[0] == ["L1", "C1", "R1"])
        #expect(rows[1] == ["L2", "C2", "R2"])

        let rendered = MarkdownContentBlocks.render(
            preparedBlocks: prepared,
            mode: .allSystem,
            textSizePreset: .default,
            isDarkMode: false
        )
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
    func tablePipesEscapedAndInCode() {
        let markdown = """
        | Syntax | Note |
        | --- | --- |
        | Escaped \\| pipe | Works |
        | `a | b` code | Also works |
        """
        let prepared = MarkdownContentBlocks.prepare(from: markdown)
        #expect(prepared.count == 1)
        guard case .table(let headers, _, let rows) = prepared.first?.kind else {
            Issue.record("Expected table block")
            return
        }
        #expect(headers == ["Syntax", "Note"])
        #expect(rows.count == 2)
        #expect(rows[0][0].contains("\\| pipe"))
        #expect(rows[1][0] == "`a | b` code")
    }

    @Test("GFM tables support missing outer boundary pipes")
    func tableAbsentOuterPipes() {
        let markdown = """
        Name | Age | City
        --- | :---: | ---:
        Alice | 30 | London
        Bob | 25 | Paris
        """
        let prepared = MarkdownContentBlocks.prepare(from: markdown)
        #expect(prepared.count == 1)
        guard case .table(let headers, let alignments, let rows) = prepared.first?.kind else {
            Issue.record("Expected table block without outer pipes")
            return
        }
        #expect(headers == ["Name", "Age", "City"])
        #expect(alignments == [.left, .center, .right])
        #expect(rows.count == 2)
    }

    @Test("GFM tables normalize missing or extra row cells")
    func tableUnevenCells() {
        let markdown = """
        | Col A | Col B | Col C |
        | --- | --- | --- |
        | Only A |
        | A | B | C | Extra D |
        """
        let prepared = MarkdownContentBlocks.prepare(from: markdown)
        guard case .table(let headers, _, let rows) = prepared.first?.kind else {
            Issue.record("Expected table block")
            return
        }
        #expect(headers.count == 3)
        #expect(rows[0] == ["Only A", "", ""])
        #expect(rows[1] == ["A", "B", "C"])
    }

    @Test("Malformed delimiter rows fall back gracefully to paragraphs without dropping input")
    func tableMalformedFallback() {
        let markdown = """
        | Col A | Col B |
        | --- | not-a-delimiter |
        | Val A | Val B |
        """
        let prepared = MarkdownContentBlocks.prepare(from: markdown)
        let isTable = prepared.contains { block in
            if case .table = block.kind { return true }
            return false
        }
        #expect(!isTable)
        #expect(!prepared.isEmpty)
    }

    @Test("Italic emphasis supports stars and underscores while ignoring intra-word underscores")
    func italicEmphasis() {
        let star = MarkdownRenderer.render(from: "Before *star italic* after")
        #expect(star.string == "Before star italic after")
        let starRange = (star.string as NSString).range(of: "star italic")
        let starFont = star.attribute(.font, at: starRange.location, effectiveRange: nil) as? NSFont
        let hasItalicTrait = starFont.map { NSFontManager.shared.traits(of: $0).contains(.italicFontMask) } ?? false
        let hasObliqueness = star.attribute(.obliqueness, at: starRange.location, effectiveRange: nil) != nil
        #expect(hasItalicTrait || hasObliqueness)

        let underscore = MarkdownRenderer.render(from: "Before _underscore italic_ after")
        #expect(underscore.string == "Before underscore italic after")

        let intraWord = MarkdownRenderer.render(from: "variable_name_with_underscores")
        #expect(intraWord.string == "variable_name_with_underscores")
    }

    @Test("Double underscores and double stars both render as bold")
    func boldDoubleUnderscores() throws {
        let underscoreBold = MarkdownRenderer.render(from: "__bold underscore__")
        #expect(underscoreBold.string == "bold underscore")
        let uFont = try #require(underscoreBold.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        #expect(NSFontManager.shared.traits(of: uFont).contains(.boldFontMask))

        let starBold = MarkdownRenderer.render(from: "**bold star**")
        #expect(starBold.string == "bold star")
        let sFont = try #require(starBold.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        #expect(NSFontManager.shared.traits(of: sFont).contains(.boldFontMask))
    }

    @Test("Triple stars and triple underscores render as combined bold and italic")
    func boldItalicCombined() throws {
        let triple = MarkdownRenderer.render(from: "***bold and italic***")
        #expect(triple.string == "bold and italic")
        let font = try #require(triple.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        #expect(NSFontManager.shared.traits(of: font).contains(.boldFontMask))

        let tripleUnderscore = MarkdownRenderer.render(from: "___bold and italic underscore___")
        #expect(tripleUnderscore.string == "bold and italic underscore")
    }

    @Test("Strikethrough applies single strikethrough line attribute")
    func strikethrough() throws {
        let rendered = MarkdownRenderer.render(from: "Before ~~deleted text~~ after")
        #expect(rendered.string == "Before deleted text after")
        let strikeRange = (rendered.string as NSString).range(of: "deleted text")
        let strikeVal = try #require(rendered.attribute(.strikethroughStyle, at: strikeRange.location, effectiveRange: nil) as? Int)
        #expect(strikeVal == NSUnderlineStyle.single.rawValue)
    }

    @Test("Backslash escapes prevent formatting while removing the backslash")
    func backslashEscapes() {
        let rendered = MarkdownRenderer.render(from: "\\*not italic\\* \\_not italic\\_ \\[not link\\]")
        #expect(rendered.string == "*not italic* _not italic_ [not link]")
        let firstStar = (rendered.string as NSString).range(of: "*not italic*")
        #expect(rendered.attribute(.link, at: firstStar.location, effectiveRange: nil) == nil)
    }

    @Test("Autolinks render with destination link attributes")
    func autolinks() throws {
        let rendered = MarkdownRenderer.render(from: "Visit <https://example.com/docs> today")
        #expect(rendered.string == "Visit https://example.com/docs today")
        let linkRange = (rendered.string as NSString).range(of: "https://example.com/docs")
        let url = try #require(rendered.attribute(.link, at: linkRange.location, effectiveRange: nil) as? URL)
        #expect(url.absoluteString == "https://example.com/docs")
    }

    @Test("Thematic breaks parse as thematicBreak blocks")
    func thematicBreaks() {
        for rule in ["---", "***", "___", "- - -", "* * * *"] {
            let prepared = MarkdownContentBlocks.prepare(from: rule)
            #expect(prepared.count == 1)
            guard case .thematicBreak = prepared.first?.kind else {
                Issue.record("Expected thematicBreak for '\(rule)'")
                continue
            }
        }
    }

    @Test("Setext headings are recognized from underline dashes or equals")
    func setextHeadings() {
        let h1Markdown = "Heading 1\n========="
        let h1Blocks = MarkdownContentBlocks.prepare(from: h1Markdown)
        #expect(h1Blocks.count == 1)
        if case .heading(let level, let source) = h1Blocks.first?.kind {
            #expect(level == 1)
            #expect(source == "Heading 1")
        } else {
            Issue.record("Expected Setext H1")
        }

        let h2Markdown = "Heading 2\n---------"
        let h2Blocks = MarkdownContentBlocks.prepare(from: h2Markdown)
        #expect(h2Blocks.count == 1)
        if case .heading(let level, let source) = h2Blocks.first?.kind {
            #expect(level == 2)
            #expect(source == "Heading 2")
        } else {
            Issue.record("Expected Setext H2")
        }
    }

    @Test("List item continuations append to the item body")
    func listContinuation() {
        let markdown = "- First line\n  Continuation line\n- Second item"
        let blocks = MarkdownContentBlocks.prepare(from: markdown)
        #expect(blocks.count == 1)
        if case .list(let items) = blocks.first?.kind {
            #expect(items.count == 2)
            #expect(items[0].body == "First line\nContinuation line")
            #expect(items[1].body == "Second item")
        } else {
            Issue.record("Expected list with continuation")
        }
    }

    @Test("Task lists parse unchecked and checked states")
    func taskLists() {
        let markdown = "- [ ] Todo task\n- [x] Done task\n- [X] Upper done task"
        let blocks = MarkdownContentBlocks.prepare(from: markdown)
        if case .list(let items) = blocks.first?.kind {
            #expect(items.count == 3)
            #expect(items[0].marker == "☐")
            #expect(items[0].body == "Todo task")
            #expect(items[1].marker == "☑")
            #expect(items[1].body == "Done task")
            #expect(items[2].marker == "☑")
            #expect(items[2].body == "Upper done task")
        } else {
            Issue.record("Expected task list items")
        }
    }

    @Test("Standalone images parse as image blocks and inline images render cleanly")
    func imagesStandaloneAndInline() {
        let standalone = "![Marky Mascot](assets/mascot.png \"Mascot\")"
        let blocks = MarkdownContentBlocks.prepare(from: standalone)
        #expect(blocks.count == 1)
        if case .image(let alt, let url, let title) = blocks.first?.kind {
            #expect(alt == "Marky Mascot")
            #expect(url == "assets/mascot.png")
            #expect(title == "Mascot")
        } else {
            Issue.record("Expected image block")
        }

        let inline = MarkdownRenderer.render(from: "See ![icon](icon.png) inline")
        #expect(inline.string == "See icon inline")
    }

    @Test("Inline cell and list text cannot be mistaken for block markers or headings")
    func inlineTextCellHeadingIsolation() {
        let cellText = "# Not A Heading"
        let rendered = MarkdownRenderer.renderInline(from: cellText)
        #expect(rendered.string == "# Not A Heading")

        let quoteInCell = "> Not A Quote"
        let renderedQuote = MarkdownRenderer.renderInline(from: quoteInCell)
        #expect(renderedQuote.string == "> Not A Quote")
    }

    @Test("Nested emphasis renders accurately both ways without leftover markers")
    func nestedEmphasisBothWays() throws {
        let boldOuter = MarkdownRenderer.renderInline(from: "**bold and *italic***")
        #expect(boldOuter.string == "bold and italic")
        let boldFont = try #require(boldOuter.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        #expect(NSFontManager.shared.traits(of: boldFont).contains(.boldFontMask))
        let italicRange = (boldOuter.string as NSString).range(of: "italic")
        let biFont = try #require(boldOuter.attribute(.font, at: italicRange.location, effectiveRange: nil) as? NSFont)
        #expect(NSFontManager.shared.traits(of: biFont).contains(.boldFontMask))

        let italicOuter = MarkdownRenderer.renderInline(from: "*italic and **bold***")
        #expect(italicOuter.string == "italic and bold")
        let boldInnerRange = (italicOuter.string as NSString).range(of: "bold")
        let ibFont = try #require(italicOuter.attribute(.font, at: boldInnerRange.location, effectiveRange: nil) as? NSFont)
        #expect(NSFontManager.shared.traits(of: ibFont).contains(.boldFontMask))
    }

    @Test("Adjacent links and balanced destination parentheses parse cleanly")
    func adjacentLinksAndBalancedDestinations() throws {
        let adjacent = MarkdownRenderer.renderInline(from: "[one](https://one.test)[two](https://two.test)")
        #expect(adjacent.string == "onetwo")
        let oneLink = try #require(adjacent.attribute(.link, at: 0, effectiveRange: nil) as? URL)
        #expect(oneLink.absoluteString == "https://one.test")
        let twoLink = try #require(adjacent.attribute(.link, at: 3, effectiveRange: nil) as? URL)
        #expect(twoLink.absoluteString == "https://two.test")

        let balanced = MarkdownRenderer.renderInline(from: "[Wiki](https://en.wikipedia.org/wiki/File_(format))")
        #expect(balanced.string == "Wiki")
        let wikiLink = try #require(balanced.attribute(.link, at: 0, effectiveRange: nil) as? URL)
        #expect(wikiLink.absoluteString == "https://en.wikipedia.org/wiki/File_(format)")
    }

    @Test("HTML entities and email autolinks decode and link natively")
    func htmlEntitiesAndEmailAutolinks() throws {
        let entities = MarkdownRenderer.renderInline(from: "&copy; 2026 Marky &amp; Co. &lt;tag&gt; &#65;")
        #expect(entities.string == "© 2026 Marky & Co. <tag> A")

        let email = MarkdownRenderer.renderInline(from: "Contact <mailto:user@example.com>")
        #expect(email.string == "Contact mailto:user@example.com")
        let linkRange = (email.string as NSString).range(of: "mailto:user@example.com")
        let mailtoURL = try #require(email.attribute(.link, at: linkRange.location, effectiveRange: nil) as? URL)
        #expect(mailtoURL.absoluteString == "mailto:user@example.com")
    }

    @Test("Table recognition requires unescaped pipes and exact column match; Title followed by underlines becomes Setext")
    func tableExactHeaderDelimiterMatch() {
        let setextH2 = "Title\n---"
        let h2Blocks = MarkdownContentBlocks.prepare(from: setextH2)
        #expect(h2Blocks.count == 1)
        if case .heading(let level, let source) = h2Blocks.first?.kind {
            #expect(level == 2)
            #expect(source == "Title")
        } else {
            Issue.record("Expected Setext H2 for Title followed by ---")
        }

        let setextH1 = "Title\n==="
        let h1Blocks = MarkdownContentBlocks.prepare(from: setextH1)
        #expect(h1Blocks.count == 1)
        if case .heading(let level, let source) = h1Blocks.first?.kind {
            #expect(level == 1)
            #expect(source == "Title")
        } else {
            Issue.record("Expected Setext H1 for Title followed by ===")
        }

        let mismatched = "| A | B | C |\n| --- | --- |\n| 1 | 2 |"
        let mismatchedBlocks = MarkdownContentBlocks.prepare(from: mismatched)
        let isTable = mismatchedBlocks.contains { block in
            if case .table = block.kind { return true }
            return false
        }
        #expect(!isTable)

        let valid = "| A | B |\n| :--- | ---: |\n| 1 | 2 |"
        let validBlocks = MarkdownContentBlocks.prepare(from: valid)
        #expect(validBlocks.count == 1)
        if case .table(let headers, let alignments, _) = validBlocks.first?.kind {
            #expect(headers == ["A", "B"])
            #expect(alignments == [.left, .right])
        } else {
            Issue.record("Expected valid table for exact column match")
        }
    }

    @Test("Headings renderInline applies heading font size and tracking")
    func headingInlineFontAndTracking() throws {
        let typography = MarkdownTypography(mode: .allSystem)
        let headingText = "Main Title"
        let rendered = MarkdownRenderer.renderInline(from: headingText, headingLevel: 1)
        let font = try #require(rendered.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        let expectedFont = typography.headingFont(for: 1)
        #expect(abs(font.pointSize - expectedFont.pointSize) < 0.01)
        let kern = try #require(rendered.attribute(.kern, at: 0, effectiveRange: nil) as? CGFloat)
        #expect(abs(kern - typography.headingTracking) < 0.01)
    }

    @Test("Table headers render with bold font traits on the typography font family")
    func tableHeaderAttributedBoldTrait() throws {
        let rendered = MarkdownRenderer.renderInline(from: "Column Header", mode: .systemHeadingsSerifBody, isTableHeader: true)
        let font = try #require(rendered.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        #expect(NSFontManager.shared.traits(of: font).contains(.boldFontMask))
    }

    @Test("Indented code blocks are recognized from 4 leading spaces")
    func indentedCodeBlocks() {
        let markdown = "Intro\n\n    let value = 42\n    print(value)\n\nAfter"
        let blocks = MarkdownContentBlocks.prepare(from: markdown)
        #expect(blocks.count == 3)
        if case .code(let code) = blocks[1].kind {
            #expect(code == "let value = 42\nprint(value)")
        } else {
            Issue.record("Expected indented code block")
        }
    }

    @Test("Reference links resolve from document context definitions")
    func referenceLinksWithContext() throws {
        let markdown = "[Learn Swift][swift]\n\n[swift]: https://swift.org"
        let blocks = MarkdownContentBlocks.prepare(from: markdown)
        #expect(blocks.count == 1)
        let rendered = MarkdownContentBlocks.render(preparedBlocks: blocks, mode: .allSystem, isDarkMode: false)
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
    func referenceLinksAcrossFencesAndCodeIsolation() throws {
        let markdown = """
        [go][ref]

        ```swift
        let codeRef = "[go][ref]"
        ```

        Here is `[go][ref]` in code span and \\[go\\][ref] escaped.

        [ref]: https://example.com/target
        """
        let rendered = MarkdownRenderer.render(from: markdown)
        let str = rendered.string

        // 1. [go][ref] before fence resolved
        let firstGoRange = (str as NSString).range(of: "go")
        #expect(firstGoRange.location != NSNotFound)
        let link = try #require(rendered.attribute(.link, at: firstGoRange.location, effectiveRange: nil) as? URL)
        #expect(link.absoluteString == "https://example.com/target")

        // 2. Fenced code remains literal
        #expect(str.contains("let codeRef = \"[go][ref]\""))

        // 3. Inline code span remains literal and has code background, no link
        let inlineCodeRange = (str as NSString).range(of: "[go][ref]")
        #expect(inlineCodeRange.location != NSNotFound)
        #expect(rendered.attribute(.link, at: inlineCodeRange.location, effectiveRange: nil) == nil)
        #expect(rendered.attribute(.backgroundColor, at: inlineCodeRange.location, effectiveRange: nil) != nil)

        // 4. Escaped brackets remain literal, no link
        let escapedRange = (str as NSString).range(of: "[go][ref]", options: [], range: NSRange(location: inlineCodeRange.location + inlineCodeRange.length, length: str.count - (inlineCodeRange.location + inlineCodeRange.length)))
        if escapedRange.location != NSNotFound {
            #expect(rendered.attribute(.link, at: escapedRange.location, effectiveRange: nil) == nil)
        }
    }

    @Test("Four-space indented reference definition is preserved as literal code")
    func indentedReferenceDefinitionPreservedAsCode() {
        let markdown = """
        Intro paragraph

            [ref]: https://example.com

        After paragraph
        """
        let blocks = MarkdownContentBlocks.prepare(from: markdown)
        #expect(blocks.count == 3)
        if case .code(let code) = blocks[1].kind {
            #expect(code == "[ref]: https://example.com")
        } else {
            Issue.record("Expected indented code block containing definition syntax")
        }
    }

    @Test("Nested blockquotes render stacked quote bars")
    func nestedBlockquotesRendering() {
        let markdown = "> Outer\n> > Inner"
        let rendered = MarkdownRenderer.render(from: markdown)
        #expect(rendered.string.contains("▎ Outer"))
        #expect(rendered.string.contains("▎ ▎ Inner"))

        let prepared = MarkdownContentBlocks.prepare(from: markdown)
        #expect(prepared.count == 1)
        let blocks = MarkdownContentBlocks.render(preparedBlocks: prepared, mode: .allSystem, isDarkMode: false)
        guard case .quote(let text) = blocks.first?.kind else {
            Issue.record("Expected quote block")
            return
        }
        #expect(String(text.characters).contains("Outer"))
        #expect(String(text.characters).contains("▎ Inner"))
    }

    @Test("Same-label links with different or identical URLs process in source order without styling collisions")
    func sameLabelLinksWithDifferentAndSameURLs() throws {
        let diffMarkdown = "[same](https://a.test) [**same**](https://b.test)"
        let diffRendered = MarkdownRenderer.render(from: diffMarkdown)
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
        let sameRendered = MarkdownRenderer.render(from: sameMarkdown)
        #expect(sameRendered.string == "target target")
        let secondTargetRange = NSRange(location: 7, length: 6)
        let secondTargetFont = try #require(sameRendered.attribute(.font, at: secondTargetRange.location, effectiveRange: nil) as? NSFont)
        #expect(NSFontManager.shared.traits(of: secondTargetFont).contains(.boldFontMask))
    }

    @Test("Outer bold with inner italic inside link preserves both traits")
    func outerBoldWithInnerItalicInLink() throws {
        let markdown = "**[linked *italic* here](https://example.com)**"
        let rendered = MarkdownRenderer.render(from: markdown)
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
}

private actor SuspendedMarkdownLoader {
    private var pending: [CheckedContinuation<[MarkdownPreparedBlock], Error>] = []
    private var waiter: (count: Int, continuation: CheckedContinuation<Void, Never>)?
    var requestCount: Int { pending.count }

    func load(_ url: URL) async throws -> [MarkdownPreparedBlock] {
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
        pending[index].resume(returning: MarkdownContentBlocks.prepare(from: text))
    }
}
