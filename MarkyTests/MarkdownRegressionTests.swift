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
        #expect(whitespace.string == "Before  padded  after")
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
