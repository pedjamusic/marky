import Foundation
import SwiftUI

#if os(macOS)
enum MarkdownSourceBlock {
    case markdown(String)
    case code(String)
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

    static func parse(from text: String) -> [MarkdownSourceBlock] {
        let source = text.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = source.components(separatedBy: "\n")

        var blocks: [MarkdownSourceBlock] = []
        var markdownLines: [String] = []
        var codeLines: [String] = []
        var inCodeFence = false

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
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("```") {
                if inCodeFence {
                    flushCode()
                } else {
                    flushMarkdown()
                }
                inCodeFence.toggle()
                continue
            }

            if inCodeFence {
                codeLines.append(line)
            } else {
                markdownLines.append(line)
            }
        }

        if inCodeFence {
            flushCode()
        }
        flushMarkdown()

        if blocks.isEmpty {
            return [.markdown(source)]
        }
        return blocks
    }

    @MainActor
    static func render(
        from text: String,
        mode: MarkdownTypographyMode,
        textSizePreset: MarkdownReaderTextSizePreset = .default,
        isDarkMode: Bool
    ) -> [MarkdownRenderedBlock] {
        var renderedBlocks: [MarkdownRenderedBlock] = []
        var nextID = 0

        for block in parse(from: text) {
            switch block {
            case .markdown(let markdown):
                for proseBlock in proseBlocks(from: markdown) {
                    let kind: MarkdownRenderedBlock.Kind
                    switch proseBlock {
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
                    case .list(let source):
                        kind = .list(
                            renderListItems(
                                from: source,
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
                    }
                    renderedBlocks.append(MarkdownRenderedBlock(id: nextID, kind: kind))
                    nextID += 1
                }
            case .code(let code):
                renderedBlocks.append(MarkdownRenderedBlock(id: nextID, kind: .code(code)))
                nextID += 1
            }
        }

        return renderedBlocks
    }

    private static func proseBlocks(from markdown: String) -> [MarkdownTextBlock] {
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

            if currentKind == nil || currentKind! != lineKind {
                flushCurrent()
                currentKind = lineKind
            }
            currentLines.append(line)
        }

        flushCurrent()
        return blocks
    }

    private static func renderListItems(
        from source: String,
        mode: MarkdownTypographyMode,
        textSizePreset: MarkdownReaderTextSizePreset,
        isDarkMode: Bool
    ) -> [MarkdownListItem] {
        source
            .components(separatedBy: "\n")
            .enumerated()
            .compactMap { index, line in
                guard let item = parseListItem(from: line) else { return nil }
                let body = AttributedString(
                    MarkdownRenderer.render(
                        from: item.body,
                        mode: mode,
                        textSizePreset: textSizePreset,
                        isDarkMode: isDarkMode
                    )
                )
                return MarkdownListItem(
                    id: index,
                    nestingLevel: item.nestingLevel,
                    marker: item.marker,
                    body: body
                )
            }
    }

    private static func headingLevel(in line: String) -> Int? {
        guard line.hasPrefix("#") else { return nil }
        let hashes = line.prefix(while: { $0 == "#" }).count
        guard (1...6).contains(hashes), line.dropFirst(hashes).hasPrefix(" ") else { return nil }
        return hashes
    }

    private static func isListLine(_ line: String) -> Bool {
        parseListItem(from: line) != nil
    }

    private static func parseListItem(from line: String) -> (nestingLevel: Int, marker: String, body: String)? {
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

    private static func orderedListItem(in line: String) -> (marker: String, body: String)? {
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

    private static func nestingLevel(fromLeadingWhitespace count: Int) -> Int {
        max(0, count / 2)
    }
}
#endif
