import AppKit
import Testing
@testable import Marky

@MainActor
struct CoreMarkdownParserTests {
    @Test("Empty core input returns no paragraphs")
    func emptyInput() async throws {
        let document = try await CoreMarkdownParser.parse("")
        #expect(document.paragraphs.isEmpty)
    }

    @Test("The native label receives the paragraph's exact UTF-8 bytes")
    func nativeParagraph() async throws {
        let source = "# Cafe\u{301} 東京 🎵\r\n**literal**\0after\nlast\r"
        let document = try await CoreMarkdownParser.parse(source)
        #expect(document.paragraphs.count == 1)
        let paragraph = try #require(document.paragraphs.first)
        #expect(Array(paragraph.utf8) == Array(source.utf8))

        let label = NSTextField(labelWithAttributedString: NSAttributedString(string: paragraph))
        #expect(Array(label.attributedStringValue.string.utf8) == Array(source.utf8))
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
        let second = String(repeating: "Deux e\u{301}\r\n", count: 4096)
        async let firstDocument = CoreMarkdownParser.parse(first)
        async let secondDocument = CoreMarkdownParser.parse(second)
        let (left, right) = try await (firstDocument, secondDocument)

        #expect(left.paragraphs.map { Array($0.utf8) } == [Array(first.utf8)])
        #expect(right.paragraphs.map { Array($0.utf8) } == [Array(second.utf8)])
    }
}
