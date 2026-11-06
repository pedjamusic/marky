import Foundation
import SwiftUI

#if os(macOS)
enum MarkdownSourceBlock {
    case markdown(String)
    case code(String)
}

enum MarkdownTableAlignment: String, Sendable {
    case left
    case center
    case right
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
        case table(headers: [String], alignments: [MarkdownTableAlignment], rows: [[String]])
        case thematicBreak
        case image(alt: String, url: String, title: String?)
    }

    nonisolated let id: Int
    nonisolated let kind: Kind
    nonisolated let referenceLinks: [String: URL]

    nonisolated init(id: Int, kind: Kind, referenceLinks: [String: URL] = [:]) {
        self.id = id
        self.kind = kind
        self.referenceLinks = referenceLinks
    }
}

struct MarkdownListItem: Identifiable {
    let id: Int
    let nestingLevel: Int
    let marker: String
    let body: AttributedString
}

struct MarkdownTableCell: Identifiable, Sendable {
    let id: Int
    let content: AttributedString
    let alignment: MarkdownTableAlignment
}

struct MarkdownTableRow: Identifiable, Sendable {
    let id: Int
    let cells: [MarkdownTableCell]
}

struct MarkdownRenderedTable: Sendable {
    let headers: [MarkdownTableCell]
    let rows: [MarkdownTableRow]
}

struct MarkdownRenderedBlock: Identifiable {
    enum Kind {
        case heading(level: Int, text: AttributedString)
        case paragraph(AttributedString)
        case list([MarkdownListItem])
        case quote(AttributedString)
        case code(String)
        case table(MarkdownRenderedTable)
        case thematicBreak
        case image(alt: String, url: String, title: String?)
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
        case code(String)
        case table(headers: [String], alignments: [MarkdownTableAlignment], rows: [[String]])
        case thematicBreak
        case image(alt: String, url: String, title: String?)
    }

    // Shared block recognition keeps literal fence contents identical in both render paths.
    nonisolated static func sourceLines(from text: String) -> [(text: String, isCode: Bool, isFence: Bool)] {
        var openingFence: (delimiter: Character, length: Int)?
        return text.replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")
            .map { line in
                let leadingSpaces = line.prefix(while: { $0 == " " }).count
                // Fences permit up to three leading spaces; deeper indentation stays literal.
                let trimmed = leadingSpaces <= 3 ? String(line.dropFirst(leadingSpaces)) : ""
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
            var start = 0
            while start < markdownLines.count && markdownLines[start].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                start += 1
            }
            var end = markdownLines.count
            while end > start && markdownLines[end - 1].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                end -= 1
            }
            if start < end {
                let markdown = markdownLines[start..<end].joined(separator: "\n")
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

    /// Normalizes a reference link label by stripping leading/trailing whitespace,
    /// collapsing internal whitespace runs to a single space, and case-folding.
    nonisolated static func normalizeReferenceLabel(_ raw: String) -> String {
        let pieces = raw.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        return pieces.joined(separator: " ").lowercased()
    }

    nonisolated static func extractDocumentReferenceLinks(from source: String) -> (cleanedSource: String, links: [String: URL]) {
        let linesWithStatus = sourceLines(from: source)
        var links: [String: URL] = [:]
        var outputLines: [String] = []

        let refRegex = try? NSRegularExpression(pattern: #"^[ ]{0,3}\[([^\]]+)\]:\s*<?([^\s>]+)>?(?:\s+["'(](.*?)["')])?\s*$"#)

        var previousLineWasBlank = true
        var inIndentedCode = false

        for item in linesWithStatus {
            let line = item.text
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if item.isFence || item.isCode {
                outputLines.append(line)
                previousLineWasBlank = false
                inIndentedCode = false
                continue
            }

            if trimmed.isEmpty {
                outputLines.append(line)
                previousLineWasBlank = true
                inIndentedCode = false
                continue
            }

            let isIndented = line.hasPrefix("    ") || line.hasPrefix("\t")
            if isIndented && (previousLineWasBlank || inIndentedCode) {
                inIndentedCode = true
                previousLineWasBlank = false
                outputLines.append(line)
                continue
            }
            inIndentedCode = false
            previousLineWasBlank = false

            let nsLine = line as NSString
            if let regex = refRegex, let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)) {
                let rawLabel = nsLine.substring(with: match.range(at: 1))
                let label = normalizeReferenceLabel(rawLabel)
                let urlString = nsLine.substring(with: match.range(at: 2))
                if !label.isEmpty, let url = URL(string: urlString) {
                    if links[label] == nil {
                        links[label] = url
                    }
                    outputLines.append("")
                    continue
                }
            }
            outputLines.append(line)
        }

        return (outputLines.joined(separator: "\n"), links)
    }

    nonisolated static func prepare(from text: String) -> [MarkdownPreparedBlock] {
        var preparedBlocks: [MarkdownPreparedBlock] = []
        var nextID = 0

        let (cleanedDocument, documentLinks) = extractDocumentReferenceLinks(from: text)

        for block in parse(from: cleanedDocument) {
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
                    case .code(let code):
                        kind = .code(code)
                    case .table(let headers, let alignments, let rows):
                        kind = .table(headers: headers, alignments: alignments, rows: rows)
                    case .thematicBreak:
                        kind = .thematicBreak
                    case .image(let alt, let url, let title):
                        kind = .image(alt: alt, url: url, title: title)
                    }
                    preparedBlocks.append(MarkdownPreparedBlock(id: nextID, kind: kind, referenceLinks: documentLinks))
                    nextID += 1
                }
            case .code(let code):
                preparedBlocks.append(MarkdownPreparedBlock(id: nextID, kind: .code(code), referenceLinks: documentLinks))
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
                        MarkdownRenderer.renderInline(
                            from: source,
                            mode: mode,
                            textSizePreset: textSizePreset,
                            isDarkMode: isDarkMode,
                            headingLevel: level,
                            referenceLinks: block.referenceLinks
                        )
                    )
                )
            case .paragraph(let source):
                kind = .paragraph(
                    AttributedString(
                        MarkdownRenderer.renderInline(
                            from: source,
                            mode: mode,
                            textSizePreset: textSizePreset,
                            isDarkMode: isDarkMode,
                            referenceLinks: block.referenceLinks
                        )
                    )
                )
            case .list(let items):
                kind = .list(
                    renderListItems(
                        from: items,
                        mode: mode,
                        textSizePreset: textSizePreset,
                        isDarkMode: isDarkMode,
                        referenceLinks: block.referenceLinks
                    )
                )
            case .quote(let source):
                kind = .quote(
                    AttributedString(
                        MarkdownRenderer.renderInline(
                            from: cleanQuoteText(source),
                            mode: mode,
                            textSizePreset: textSizePreset,
                            isDarkMode: isDarkMode,
                            referenceLinks: block.referenceLinks
                        )
                    )
                )
            case .code(let code):
                kind = .code(code)
            case .table(let headers, let alignments, let rows):
                let renderedHeaders = headers.enumerated().map { index, text in
                    let alignment = index < alignments.count ? alignments[index] : .left
                    let rendered = AttributedString(
                        MarkdownRenderer.renderInline(
                            from: text,
                            mode: mode,
                            textSizePreset: textSizePreset,
                            isDarkMode: isDarkMode,
                            isTableHeader: true,
                            referenceLinks: block.referenceLinks
                        )
                    )
                    return MarkdownTableCell(id: index, content: rendered, alignment: alignment)
                }
                let renderedRows = rows.enumerated().map { rowIndex, rowCells in
                    let cells = rowCells.enumerated().map { colIndex, cellText in
                        let alignment = colIndex < alignments.count ? alignments[colIndex] : .left
                        let rendered = AttributedString(
                            MarkdownRenderer.renderInline(
                                from: cellText,
                                mode: mode,
                                textSizePreset: textSizePreset,
                                isDarkMode: isDarkMode,
                                referenceLinks: block.referenceLinks
                            )
                        )
                        return MarkdownTableCell(id: colIndex, content: rendered, alignment: alignment)
                    }
                    return MarkdownTableRow(id: rowIndex, cells: cells)
                }
                kind = .table(MarkdownRenderedTable(headers: renderedHeaders, rows: renderedRows))
            case .thematicBreak:
                kind = .thematicBreak
            case .image(let alt, let url, let title):
                kind = .image(alt: alt, url: url, title: title)
            }
            return MarkdownRenderedBlock(id: block.id, kind: kind)
        }
    }

    nonisolated private static func cleanQuoteText(_ source: String) -> String {
        source
            .components(separatedBy: "\n")
            .map { line in
                var text = line.trimmingCharacters(in: .whitespaces)
                var quoteLevel = 0
                while text.hasPrefix(">") {
                    quoteLevel += 1
                    text = String(text.dropFirst()).trimmingCharacters(in: .whitespaces)
                }
                if quoteLevel > 1 {
                    let nestedIndicator = String(repeating: "▎ ", count: quoteLevel - 1)
                    return nestedIndicator + text
                }
                return text
            }
            .joined(separator: "\n")
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
                var paragraph = ""
                for (index, line) in currentLines.enumerated() {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if index == 0 {
                        paragraph = trimmed
                    } else {
                        let prev = currentLines[index - 1]
                        if prev.hasSuffix("  ") || prev.hasSuffix("\\") {
                            paragraph += "\n" + trimmed
                        } else {
                            paragraph += " " + trimmed
                        }
                    }
                }
                if !paragraph.isEmpty {
                    blocks.append(.paragraph(paragraph))
                }
            case .list:
                blocks.append(.list(currentLines.joined(separator: "\n")))
            case .quote:
                blocks.append(.quote(currentLines.joined(separator: "\n")))
            }
            currentLines.removeAll(keepingCapacity: true)
        }

        var i = 0
        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.isEmpty {
                flushCurrent()
                currentKind = nil
                i += 1
                continue
            }

            // Check for Indented Code Block (4 spaces or 1 tab preceded by blank line or start of document)
            if currentKind == nil && (line.hasPrefix("    ") || line.hasPrefix("\t")) {
                flushCurrent()
                var codeLines: [String] = []
                var j = i
                while j < lines.count {
                    let codeLine = lines[j]
                    if codeLine.hasPrefix("    ") {
                        codeLines.append(String(codeLine.dropFirst(4)))
                        j += 1
                    } else if codeLine.hasPrefix("\t") {
                        codeLines.append(String(codeLine.dropFirst(1)))
                        j += 1
                    } else if codeLine.trimmingCharacters(in: .whitespaces).isEmpty {
                        var peek = j + 1
                        var hasMoreIndented = false
                        while peek < lines.count {
                            if lines[peek].hasPrefix("    ") || lines[peek].hasPrefix("\t") {
                                hasMoreIndented = true
                                break
                            }
                            if !lines[peek].trimmingCharacters(in: .whitespaces).isEmpty {
                                break
                            }
                            peek += 1
                        }
                        if hasMoreIndented {
                            codeLines.append("")
                            j += 1
                        } else {
                            break
                        }
                    } else {
                        break
                    }
                }
                while let last = codeLines.last, last.trimmingCharacters(in: .whitespaces).isEmpty {
                    codeLines.removeLast()
                }
                if !codeLines.isEmpty {
                    blocks.append(.code(codeLines.joined(separator: "\n")))
                }
                i = j
                continue
            }

            // Check for Setext headings:
            if currentKind == .paragraph && !currentLines.isEmpty {
                if trimmed.allSatisfy({ $0 == "=" }) && trimmed.count >= 1 {
                    let source = currentLines.map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: " ")
                    currentLines.removeAll(keepingCapacity: true)
                    currentKind = nil
                    blocks.append(.heading(level: 1, source: source))
                    i += 1
                    continue
                } else if trimmed.allSatisfy({ $0 == "-" }) && trimmed.count >= 1 && !isListLine(trimmed) {
                    let source = currentLines.map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: " ")
                    currentLines.removeAll(keepingCapacity: true)
                    currentKind = nil
                    blocks.append(.heading(level: 2, source: source))
                    i += 1
                    continue
                }
            }

            // Check for Thematic Breaks (---, ***, ___):
            if isThematicBreak(trimmed) {
                flushCurrent()
                currentKind = nil
                blocks.append(.thematicBreak)
                i += 1
                continue
            }

            // Check for Standalone Image:
            if let imageInfo = parseStandaloneImage(trimmed) {
                flushCurrent()
                currentKind = nil
                blocks.append(.image(alt: imageInfo.alt, url: imageInfo.url, title: imageInfo.title))
                i += 1
                continue
            }

            // Check for ATX Headings:
            if let level = headingLevel(in: trimmed) {
                flushCurrent()
                currentKind = nil
                let hashes = trimmed.prefix(while: { $0 == "#" }).count
                var body = String(trimmed.dropFirst(hashes)).trimmingCharacters(in: .whitespaces)
                if body.hasSuffix("#") {
                    let trailingHashes = body.reversed().prefix(while: { $0 == "#" }).count
                    let withoutTrailing = body.dropLast(trailingHashes)
                    if withoutTrailing.hasSuffix(" ") {
                        body = withoutTrailing.trimmingCharacters(in: .whitespaces)
                    }
                }
                blocks.append(.heading(level: level, source: body))
                i += 1
                continue
            }

            // Check for GFM Table:
            // 1. Line must not be a quote, heading, list, or thematic break!
            // 2. Header line MUST contain a real unescaped pipe outside code spans!
            // 3. Delimiter line MUST contain a real unescaped pipe outside code spans!
            // 4. Delimiter line must be a valid delimiter row.
            // 5. Header cells count MUST EXACTLY match delimiter alignments count!
            if !trimmed.hasPrefix(">") && headingLevel(in: trimmed) == nil && !isListLine(trimmed) && !isThematicBreak(trimmed) && containsUnescapedPipe(line) && i + 1 < lines.count {
                let nextLine = lines[i + 1]
                if containsUnescapedPipe(nextLine), let alignments = parseTableDelimiterRow(nextLine) {
                    let headerCells = splitTableRow(line)
                    if headerCells.count == alignments.count {
                        flushCurrent()
                        currentKind = nil

                        var rows: [[String]] = []
                        var j = i + 2
                        while j < lines.count {
                            let rowLine = lines[j]
                            let rowTrimmed = rowLine.trimmingCharacters(in: .whitespacesAndNewlines)
                            // Terminate on real block boundaries:
                            if rowTrimmed.isEmpty { break }
                            if rowTrimmed.hasPrefix(">") { break }
                            if headingLevel(in: rowTrimmed) != nil { break }
                            if rowTrimmed.allSatisfy({ $0 == "=" }) && !rowTrimmed.isEmpty { break }
                            if isThematicBreak(rowTrimmed) { break }
                            if isListLine(rowTrimmed) { break }
                            if parseStandaloneImage(rowTrimmed) != nil { break }
                            if rowLine.hasPrefix("    ") || rowLine.hasPrefix("\t") { break }

                            let rawCells = splitTableRow(rowLine)
                            var cells: [String] = []
                            for colIndex in 0..<alignments.count {
                                if colIndex < rawCells.count {
                                    cells.append(rawCells[colIndex])
                                } else {
                                    cells.append("")
                                }
                            }
                            rows.append(cells)
                            j += 1
                        }

                        blocks.append(.table(headers: headerCells, alignments: alignments, rows: rows))
                        i = j
                        continue
                    }
                }
            }

            // Check for List item or continuation:
            let isList = isListLine(trimmed)
            if isList {
                if currentKind != .list {
                    flushCurrent()
                    currentKind = .list
                }
                currentLines.append(line)
                i += 1
                continue
            }

            if currentKind == .list {
                let leadingWhitespace = line.prefix(while: { $0 == " " || $0 == "\t" }).count
                if leadingWhitespace >= 2 {
                    currentLines.append(line)
                    i += 1
                    continue
                }
            }

            // Check for Quote:
            if trimmed.hasPrefix(">") {
                if currentKind != .quote {
                    flushCurrent()
                    currentKind = .quote
                }
                currentLines.append(line)
                i += 1
                continue
            }

            // Default to paragraph:
            if currentKind != .paragraph {
                flushCurrent()
                currentKind = .paragraph
            }
            currentLines.append(line)
            i += 1
        }

        flushCurrent()
        return blocks
    }

    /// Finds the end index of a matched backtick code span starting at `startIndex`, or nil if unmatched.
    nonisolated static func findMatchingCodeSpanEnd(in text: String, startingAt startIndex: String.Index, delimiterLength: Int) -> String.Index? {
        var searchIndex = text.index(startIndex, offsetBy: delimiterLength)
        while searchIndex < text.endIndex {
            if text[searchIndex] == "`" {
                let run = text[searchIndex...].prefix(while: { $0 == "`" })
                if run.count == delimiterLength {
                    return text.index(searchIndex, offsetBy: delimiterLength)
                }
                searchIndex = text.index(searchIndex, offsetBy: run.count)
            } else {
                searchIndex = text.index(after: searchIndex)
            }
        }
        return nil
    }

    nonisolated static func containsUnescapedPipe(_ line: String) -> Bool {
        var isEscaped = false
        var idx = line.startIndex
        while idx < line.endIndex {
            let ch = line[idx]
            if isEscaped {
                isEscaped = false
                idx = line.index(after: idx)
                continue
            }
            if ch == "\\" {
                isEscaped = true
                idx = line.index(after: idx)
                continue
            }
            if ch == "`" {
                let run = line[idx...].prefix(while: { $0 == "`" })
                if let spanEnd = findMatchingCodeSpanEnd(in: line, startingAt: idx, delimiterLength: run.count) {
                    idx = spanEnd
                    continue
                } else {
                    idx = line.index(idx, offsetBy: run.count)
                    continue
                }
            }
            if ch == "|" {
                return true
            }
            idx = line.index(after: idx)
        }
        return false
    }

    nonisolated static func isThematicBreak(_ line: String) -> Bool {
        let stripped = line.filter { !$0.isWhitespace }
        guard stripped.count >= 3 else { return false }
        if stripped.allSatisfy({ $0 == "-" }) { return true }
        if stripped.allSatisfy({ $0 == "*" }) { return true }
        if stripped.allSatisfy({ $0 == "_" }) { return true }
        return false
    }

    nonisolated static func parseStandaloneImage(_ line: String) -> (alt: String, url: String, title: String?)? {
        guard line.hasPrefix("![") && line.hasSuffix(")") else { return nil }
        guard let regex = try? NSRegularExpression(pattern: #"^!\[([^\]]*)\]\(\s*(?:<([^>\r\n]+)>|([^\s>]+))(?:\s+["'](.*?)["'])?\s*\)$"#) else {
            return nil
        }
        let nsLine = line as NSString
        let range = NSRange(location: 0, length: nsLine.length)
        guard let match = regex.firstMatch(in: line, range: range) else { return nil }
        let alt = nsLine.substring(with: match.range(at: 1))
        let url: String
        if match.range(at: 2).location != NSNotFound {
            url = nsLine.substring(with: match.range(at: 2))
        } else if match.range(at: 3).location != NSNotFound {
            url = nsLine.substring(with: match.range(at: 3))
        } else {
            return nil
        }
        var title: String? = nil
        if match.numberOfRanges > 4, match.range(at: 4).location != NSNotFound {
            title = nsLine.substring(with: match.range(at: 4))
        }
        return (alt, url, title)
    }

    nonisolated static func parseTableDelimiterRow(_ line: String) -> [MarkdownTableAlignment]? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains("-") else { return nil }
        let cells = splitTableRow(trimmed)
        guard !cells.isEmpty else { return nil }

        var alignments: [MarkdownTableAlignment] = []
        for cell in cells {
            let text = cell.trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { return nil }

            var chars = text[...]
            let hasLeadingColon = chars.first == ":"
            if hasLeadingColon { chars = chars.dropFirst() }
            let hasTrailingColon = chars.last == ":"
            if hasTrailingColon { chars = chars.dropLast() }

            guard !chars.isEmpty, chars.allSatisfy({ $0 == "-" }) else {
                return nil
            }

            if hasLeadingColon && hasTrailingColon {
                alignments.append(.center)
            } else if hasTrailingColon {
                alignments.append(.right)
            } else {
                alignments.append(.left)
            }
        }
        return alignments
    }

    nonisolated static func splitTableRow(_ line: String) -> [String] {
        var raw = line.trimmingCharacters(in: .whitespaces)
        if raw.hasPrefix("|") {
            raw.removeFirst()
        }
        if raw.hasSuffix("|") {
            var backslashCount = 0
            var idx = raw.index(before: raw.endIndex)
            while idx > raw.startIndex {
                let prev = raw.index(before: idx)
                if raw[prev] == "\\" {
                    backslashCount += 1
                    idx = prev
                } else {
                    break
                }
            }
            if backslashCount % 2 == 0 {
                raw.removeLast()
            }
        }

        var cells: [String] = []
        var currentCell = ""
        var isEscaped = false
        var index = raw.startIndex

        while index < raw.endIndex {
            let ch = raw[index]

            if isEscaped {
                currentCell.append(ch)
                isEscaped = false
                index = raw.index(after: index)
                continue
            }

            if ch == "\\" {
                isEscaped = true
                currentCell.append(ch)
                index = raw.index(after: index)
                continue
            }

            if ch == "`" {
                let run = raw[index...].prefix(while: { $0 == "`" })
                if let spanEnd = findMatchingCodeSpanEnd(in: raw, startingAt: index, delimiterLength: run.count) {
                    currentCell.append(contentsOf: raw[index..<spanEnd])
                    index = spanEnd
                    continue
                } else {
                    currentCell.append(contentsOf: run)
                    index = raw.index(index, offsetBy: run.count)
                    continue
                }
            }

            if ch == "|" {
                cells.append(currentCell.trimmingCharacters(in: .whitespaces))
                currentCell = ""
                index = raw.index(after: index)
                continue
            }

            currentCell.append(ch)
            index = raw.index(after: index)
        }
        cells.append(currentCell.trimmingCharacters(in: .whitespaces))
        return cells
    }

    nonisolated private static func preparedListItems(from source: String) -> [MarkdownPreparedListItem] {
        var items: [MarkdownPreparedListItem] = []
        var nextID = 0

        for line in source.components(separatedBy: "\n") {
            if let item = parseListItem(from: line) {
                items.append(
                    MarkdownPreparedListItem(
                        id: nextID,
                        nestingLevel: item.nestingLevel,
                        marker: item.marker,
                        body: item.body
                    )
                )
                nextID += 1
            } else if !items.isEmpty {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    let last = items.removeLast()
                    let updatedBody = last.body + "\n" + trimmed
                    items.append(
                        MarkdownPreparedListItem(
                            id: last.id,
                            nestingLevel: last.nestingLevel,
                            marker: last.marker,
                            body: updatedBody
                        )
                    )
                }
            }
        }
        return items
    }

    private static func renderListItems(
        from items: [MarkdownPreparedListItem],
        mode: MarkdownTypographyMode,
        textSizePreset: MarkdownReaderTextSizePreset,
        isDarkMode: Bool,
        referenceLinks: [String: URL] = [:]
    ) -> [MarkdownListItem] {
        items.map { item in
            let body = AttributedString(
                MarkdownRenderer.renderInline(
                    from: item.body,
                    mode: mode,
                    textSizePreset: textSizePreset,
                    isDarkMode: isDarkMode,
                    referenceLinks: referenceLinks
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

        guard !digits.isEmpty, index < line.endIndex, line[index] == "." || line[index] == ")" else { return nil }
        let delimiter = line[index]
        index = line.index(after: index)
        guard index < line.endIndex, line[index] == " " else { return nil }
        let body = String(line[line.index(after: index)...])
        return ("\(digits)\(delimiter)", body)
    }

    nonisolated private static func nestingLevel(fromLeadingWhitespace count: Int) -> Int {
        max(0, count / 2)
    }
}
#endif
