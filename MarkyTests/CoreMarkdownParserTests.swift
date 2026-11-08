import AppKit
import Testing
@testable import Marky

@MainActor
struct CoreMarkdownParserTests {
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
