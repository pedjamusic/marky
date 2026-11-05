import Foundation
import SwiftUI

#if os(macOS)
enum MarkdownSourceBlock {
    case markdown(String)
    case code(String)
}

struct MarkdownPreparedListItem: Identifiable, Sendable {
    nonisolated let id: Int
    nonisolated let nestingLevel: Int
    nonisolated let marker: String
    nonisolated let body: String
}

struct MarkdownPreparedBlock: Identifiable, Sendable {
    enum Kind: Sendable {
        case heading(level: Int, source: String)
        case paragraph(String)
        case list([MarkdownPreparedListItem])
        case quote(String)
        case code(String)
    }

    nonisolated let id: Int
    nonisolated let kind: Kind
}

struct MarkdownListItem: Identifiable {
    let id: Int
    let nestingLevel: Int
    let marker: String
    let body: AttributedString
}

struct MarkdownRenderedBlock: Identifiable {
    enum Kind {
        case heading(level: Int, text: AttributedString)
        case paragraph(AttributedString)
        case list([MarkdownListItem])
        case quote(AttributedString)
        case code(String)
    }

    let id: Int
    let kind: Kind
}

enum MarkdownContentBlocks {
    private enum MarkdownTextBlock {
        case heading(level: Int, source: String)
        case paragraph(String)
        case list(String)
        case quote(String)
    }

    // Shared block recognition keeps literal fence contents identical in both render paths.
    nonisolated static func sourceLines(from text: String) -> [(text: String, isCode: Bool, isFence: Bool)] {
        var openingFence: (delimiter: Character, length: Int)?
        return text.replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")
            .map { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if let opening = openingFence {
                    let count = trimmed.prefix(while: { $0 == opening.delimiter }).count
                    if count >= opening.length,
                       trimmed.dropFirst(count).trimmingCharacters(in: .whitespaces).isEmpty {
                        openingFence = nil
                        return (line, false, true)
                    }
                    return (line, true, false)
                }
                if let delimiter = trimmed.first, delimiter == "`" || delimiter == "~" {
                    let count = trimmed.prefix(while: { $0 == delimiter }).count
                    let info = trimmed.dropFirst(count)
                    if count >= 3, delimiter != "`" || !info.contains("`") {
                        openingFence = (delimiter, count)
                        return (line, false, true)
                    }
                }
                return (line, false, false)
            }
    }

    nonisolated static func parse(from text: String) -> [MarkdownSourceBlock] {
        let source = text.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = sourceLines(from: source)

        var blocks: [MarkdownSourceBlock] = []
        var markdownLines: [String] = []
        var codeLines: [String] = []
        var hasCodeBlock = false

        func flushMarkdown() {
            let markdown = markdownLines
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                blocks.append(.markdown(markdown))
            }
            markdownLines.removeAll(keepingCapacity: true)
        }

        func flushCode() {
            blocks.append(.code(codeLines.joined(separator: "\n")))
            codeLines.removeAll(keepingCapacity: true)
        }

        for line in lines {
            if line.isFence {
                if hasCodeBlock {
                    flushCode()
                    hasCodeBlock = false
                } else {
                    flushMarkdown()
                    hasCodeBlock = true
                }
            } else if line.isCode {
                codeLines.append(line.text)
            } else {
                markdownLines.append(line.text)
            }
        }

        if hasCodeBlock {
            flushCode()
        }
        flushMarkdown()

        if blocks.isEmpty {
            return [.markdown(source)]
        }
        return blocks
    }

    nonisolated static func prepare(from text: String) -> [MarkdownPreparedBlock] {
        var preparedBlocks: [MarkdownPreparedBlock] = []
        var nextID = 0

        for block in parse(from: text) {
            switch block {
            case .markdown(let markdown):
                for proseBlock in proseBlocks(from: markdown) {
                    let kind: MarkdownPreparedBlock.Kind
                    switch proseBlock {
                    case .heading(let level, let source):
                        kind = .heading(level: level, source: source)
                    case .paragraph(let source):
                        kind = .paragraph(source)
                    case .list(let source):
                        kind = .list(preparedListItems(from: source))
                    case .quote(let source):
                        kind = .quote(source)
                    }
                    preparedBlocks.append(MarkdownPreparedBlock(id: nextID, kind: kind))
                    nextID += 1
                }
            case .code(let code):
                preparedBlocks.append(MarkdownPreparedBlock(id: nextID, kind: .code(code)))
                nextID += 1
            }
        }

        return preparedBlocks
    }

    @MainActor
    static func render(
        from text: String,
        mode: MarkdownTypographyMode,
        textSizePreset: MarkdownReaderTextSizePreset = .default,
        isDarkMode: Bool
    ) -> [MarkdownRenderedBlock] {
        render(
            preparedBlocks: prepare(from: text),
            mode: mode,
            textSizePreset: textSizePreset,
            isDarkMode: isDarkMode
        )
    }

    @MainActor
    static func render(
        preparedBlocks: [MarkdownPreparedBlock],
        mode: MarkdownTypographyMode,
        textSizePreset: MarkdownReaderTextSizePreset = .default,
        isDarkMode: Bool
    ) -> [MarkdownRenderedBlock] {
        preparedBlocks.map { block in
            let kind: MarkdownRenderedBlock.Kind
            switch block.kind {
            case .heading(let level, let source):
                kind = .heading(
                    level: level,
                    text: AttributedString(
                        MarkdownRenderer.render(
                            from: source,
                            mode: mode,
                            textSizePreset: textSizePreset,
                            isDarkMode: isDarkMode
                        )
                    )
                )
            case .paragraph(let source):
                kind = .paragraph(
                    AttributedString(
                        MarkdownRenderer.render(
                            from: source,
                            mode: mode,
                            textSizePreset: textSizePreset,
                            isDarkMode: isDarkMode
                        )
                    )
                )
            case .list(let items):
                kind = .list(
                    renderListItems(
                        from: items,
                        mode: mode,
                        textSizePreset: textSizePreset,
                        isDarkMode: isDarkMode
                    )
                )
            case .quote(let source):
                kind = .quote(
                    AttributedString(
                        MarkdownRenderer.render(
                            from: source,
                            mode: mode,
                            textSizePreset: textSizePreset,
                            isDarkMode: isDarkMode
                        )
                    )
                )
            case .code(let code):
                kind = .code(code)
            }
            return MarkdownRenderedBlock(id: block.id, kind: kind)
        }
    }

    nonisolated private static func proseBlocks(from markdown: String) -> [MarkdownTextBlock] {
        let lines = markdown.components(separatedBy: "\n")
        var blocks: [MarkdownTextBlock] = []
        var currentKind: ProseKind?
        var currentLines: [String] = []

        enum ProseKind {
            case paragraph
            case list
            case quote
        }

        func flushCurrent() {
            guard let currentKind, !currentLines.isEmpty else { return }
            switch currentKind {
            case .paragraph:
                let paragraph = currentLines
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .joined(separator: " ")
                blocks.append(.paragraph(paragraph))
            case .list:
                blocks.append(.list(currentLines.joined(separator: "\n")))
            case .quote:
                blocks.append(.quote(currentLines.joined(separator: "\n")))
            }
            currentLines.removeAll(keepingCapacity: true)
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                flushCurrent()
                currentKind = nil
                continue
            }

            if let level = headingLevel(in: trimmed) {
                flushCurrent()
                currentKind = nil
                blocks.append(.heading(level: level, source: trimmed))
                continue
            }

            let lineKind: ProseKind
            if isListLine(trimmed) {
                lineKind = .list
            } else if trimmed.hasPrefix(">") {
                lineKind = .quote
            } else {
                lineKind = .paragraph
            }

            if currentKind != lineKind {
                flushCurrent()
                currentKind = lineKind
            }
            currentLines.append(line)
        }

        flushCurrent()
        return blocks
    }

    nonisolated private static func preparedListItems(from source: String) -> [MarkdownPreparedListItem] {
        source
            .components(separatedBy: "\n")
            .enumerated()
            .compactMap { index, line in
                guard let item = parseListItem(from: line) else { return nil }
                return MarkdownPreparedListItem(
                    id: index,
                    nestingLevel: item.nestingLevel,
                    marker: item.marker,
                    body: item.body
                )
            }
    }

    private static func renderListItems(
        from items: [MarkdownPreparedListItem],
        mode: MarkdownTypographyMode,
        textSizePreset: MarkdownReaderTextSizePreset,
        isDarkMode: Bool
    ) -> [MarkdownListItem] {
        items.map { item in
            let body = AttributedString(
                MarkdownRenderer.render(
                    from: item.body,
                    mode: mode,
                    textSizePreset: textSizePreset,
                    isDarkMode: isDarkMode
                )
            )
            return MarkdownListItem(
                id: item.id,
                nestingLevel: item.nestingLevel,
                marker: item.marker,
                body: body
            )
        }
    }

    nonisolated static func headingLevel(in line: String) -> Int? {
        guard line.hasPrefix("#") else { return nil }
        let hashes = line.prefix(while: { $0 == "#" }).count
        guard (1...6).contains(hashes), line.dropFirst(hashes).hasPrefix(" ") else { return nil }
        return hashes
    }

    nonisolated private static func isListLine(_ line: String) -> Bool {
        parseListItem(from: line) != nil
    }

    nonisolated static func parseListItem(from line: String) -> (nestingLevel: Int, marker: String, body: String)? {
        let leadingWhitespaceCount = line.prefix(while: { $0 == " " || $0 == "\t" }).count
        let content = String(line.dropFirst(leadingWhitespaceCount))

        let taskPrefixes = [
            ("- [ ] ", "☐"),
            ("* [ ] ", "☐"),
            ("+ [ ] ", "☐"),
            ("- [x] ", "☑"),
            ("* [x] ", "☑"),
            ("+ [x] ", "☑"),
            ("- [X] ", "☑"),
            ("* [X] ", "☑"),
            ("+ [X] ", "☑")
        ]
        for (prefix, marker) in taskPrefixes where content.hasPrefix(prefix) {
            return (
                nestingLevel: nestingLevel(fromLeadingWhitespace: leadingWhitespaceCount),
                marker: marker,
                body: String(content.dropFirst(prefix.count))
            )
        }

        let unorderedPrefixes = ["- ", "* ", "+ ", "• "]
        for prefix in unorderedPrefixes where content.hasPrefix(prefix) {
            return (
                nestingLevel: nestingLevel(fromLeadingWhitespace: leadingWhitespaceCount),
                marker: "•",
                body: String(content.dropFirst(prefix.count))
            )
        }

        if let ordered = orderedListItem(in: content) {
            return (
                nestingLevel: nestingLevel(fromLeadingWhitespace: leadingWhitespaceCount),
                marker: ordered.marker,
                body: ordered.body
            )
        }

        return nil
    }

    nonisolated private static func orderedListItem(in line: String) -> (marker: String, body: String)? {
        var digits = ""
        var index = line.startIndex
        while index < line.endIndex, line[index].isNumber {
            digits.append(line[index])
            index = line.index(after: index)
        }

        guard !digits.isEmpty, index < line.endIndex, line[index] == "." else { return nil }
        index = line.index(after: index)
        guard index < line.endIndex, line[index] == " " else { return nil }
        let body = String(line[line.index(after: index)...])
        return ("\(digits).", body)
    }

    nonisolated private static func nestingLevel(fromLeadingWhitespace count: Int) -> Int {
        max(0, count / 2)
    }
}
#endif
