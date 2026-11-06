import SwiftUI
import Foundation
import Combine
import OSLog
#if os(macOS)
import AppKit
#endif

#if os(macOS)
enum MarkdownRenderer {
    private static let logger = Logger(subsystem: "rocks.toodear.Marky", category: "MarkdownRenderer")

    static func renderInline(
        from text: String,
        mode: MarkdownTypographyMode = .allSystem,
        textSizePreset: MarkdownReaderTextSizePreset = .default,
        isDarkMode: Bool = false,
        headingLevel: Int? = nil,
        isTableHeader: Bool = false,
        referenceLinks: [String: URL] = [:]
    ) -> NSAttributedString {
        let typography = MarkdownTypography(mode: mode, textSizePreset: textSizePreset)
        let resolvedText = substituteReferenceLinks(in: text, referenceLinks: referenceLinks)

        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .inlineOnlyPreservingWhitespace

        let parsed: AttributedString
        do {
            parsed = try AttributedString(markdown: resolvedText, options: options)
        } catch {
            logger.error("Native Markdown parsing failed for inline text; falling back to raw attributed text")
            parsed = AttributedString(resolvedText)
        }

        let baseFont: NSFont
        let tracking: CGFloat
        let lineHeightMultiple: CGFloat

        if let level = headingLevel {
            baseFont = typography.headingFont(for: level)
            tracking = typography.headingTracking
            lineHeightMultiple = typography.headingLineHeight(for: level)
        } else if isTableHeader {
            let base = typography.bodyFont()
            baseFont = NSFontManager.shared.convert(base, toHaveTrait: .boldFontMask)
            tracking = typography.bodyTracking
            lineHeightMultiple = typography.bodyLineHeightMultiple
        } else {
            baseFont = typography.bodyFont()
            tracking = typography.bodyTracking
            lineHeightMultiple = typography.bodyLineHeightMultiple
        }

        let result = NSMutableAttributedString(string: String(parsed.characters))
        let baseParagraph = NSMutableParagraphStyle()
        baseParagraph.lineHeightMultiple = lineHeightMultiple
        baseParagraph.paragraphSpacing = 0

        result.addAttributes([
            .font: baseFont,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: baseParagraph,
            .kern: tracking
        ], range: NSRange(location: 0, length: result.length))

        var utf16Offset = 0
        for run in parsed.runs {
            let runString = String(parsed[run.range].characters)
            let runLength = (runString as NSString).length
            let runRange = NSRange(location: utf16Offset, length: runLength)
            utf16Offset += runLength

            guard runLength > 0 else { continue }

            if let intent = run.inlinePresentationIntent, !intent.isEmpty {
                applyPresentationIntent(
                    intent,
                    to: result,
                    range: runRange,
                    baseFont: baseFont,
                    typography: typography,
                    isDarkMode: isDarkMode
                )
            }

            if let url = run.link {
                result.addAttributes([
                    .link: url,
                    .underlineStyle: typography.linkUnderlineStyle.rawValue,
                    .foregroundColor: typography.linkColor
                ], range: runRange)
            }
        }

        // Process ALL detected links in source order so plain links also advance search offset
        let allLinks = detectLinks(in: resolvedText)
        var searchOffset = 0
        for link in allLinks {
            let labelParsed: AttributedString
            do {
                labelParsed = try AttributedString(markdown: link.labelMarkdown, options: options)
            } catch {
                logger.error("Native Markdown parsing failed for link label; falling back to unformatted label")
                labelParsed = AttributedString(link.labelMarkdown)
            }
            let plainLabel = String(labelParsed.characters)
            let plainLength = (plainLabel as NSString).length
            guard plainLength > 0 else { continue }

            let fullString = result.string as NSString
            var foundRange = NSRange(location: NSNotFound, length: 0)
            var searchLoc = searchOffset
            let expectedURL = URL(string: link.destination)

            while searchLoc + plainLength <= fullString.length {
                let testRange = NSRange(location: searchLoc, length: plainLength)
                if fullString.substring(with: testRange) == plainLabel {
                    if let url = result.attribute(.link, at: testRange.location, effectiveRange: nil) as? URL {
                        if expectedURL == nil || url.absoluteString == expectedURL?.absoluteString || url.absoluteString == link.destination {
                            foundRange = testRange
                            break
                        }
                    }
                }
                searchLoc += 1
            }

            guard foundRange.location != NSNotFound else { continue }
            // Advance searchOffset for all links to prevent same-label collisions
            searchOffset = foundRange.location + foundRange.length

            if link.labelMarkdown.contains("*") ||
               link.labelMarkdown.contains("_") ||
               link.labelMarkdown.contains("`") ||
               link.labelMarkdown.contains("~") {
                var subOffset = 0
                for subRun in labelParsed.runs {
                    let subString = String(labelParsed[subRun.range].characters)
                    let subLength = (subString as NSString).length
                    let subRange = NSRange(location: foundRange.location + subOffset, length: subLength)
                    subOffset += subLength

                    guard subLength > 0 else { continue }
                    if let intent = subRun.inlinePresentationIntent, !intent.isEmpty {
                        applyPresentationIntent(
                            intent,
                            to: result,
                            range: subRange,
                            baseFont: baseFont,
                            typography: typography,
                            isDarkMode: isDarkMode
                        )
                    }
                }
            }
        }

        return result
    }

    private static func applyPresentationIntent(
        _ intent: InlinePresentationIntent,
        to result: NSMutableAttributedString,
        range: NSRange,
        baseFont: NSFont,
        typography: MarkdownTypography,
        isDarkMode: Bool
    ) {
        let fontManager = NSFontManager.shared
        if intent.contains(.code) {
            var codeFont = NSFont.monospacedSystemFont(
                ofSize: max(typography.codeMinimumFontSize, baseFont.pointSize * typography.codeFontScale),
                weight: .regular
            )
            if intent.contains(.stronglyEmphasized) {
                codeFont = fontManager.convert(codeFont, toHaveTrait: .boldFontMask)
            }
            result.addAttributes([
                .font: codeFont,
                .foregroundColor: typography.codeForegroundColor(isDarkMode: isDarkMode),
                .backgroundColor: typography.codeBackgroundColor(isDarkMode: isDarkMode)
            ], range: range)
        } else {
            var traits: NSFontTraitMask = []
            if intent.contains(.stronglyEmphasized) {
                traits.insert(.boldFontMask)
            }
            if intent.contains(.emphasized) {
                traits.insert(.italicFontMask)
            }
            if !traits.isEmpty {
                let currentFont = (result.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont) ?? baseFont
                let converted = fontManager.convert(currentFont, toHaveTrait: traits)
                if fontManager.traits(of: converted).contains(traits) {
                    result.addAttribute(.font, value: converted, range: range)
                } else {
                    var sym = currentFont.fontDescriptor.symbolicTraits
                    if traits.contains(.boldFontMask) { sym.insert(.bold) }
                    if traits.contains(.italicFontMask) { sym.insert(.italic) }
                    if let descFont = NSFont(descriptor: currentFont.fontDescriptor.withSymbolicTraits(sym), size: currentFont.pointSize) {
                        result.addAttribute(.font, value: descFont, range: range)
                    } else if traits.contains(.italicFontMask) {
                        result.addAttribute(.obliqueness, value: MarkyTheme.italicObliqueness, range: range)
                    }
                }
            }
        }

        if intent.contains(.strikethrough) {
            result.addAttribute(
                .strikethroughStyle,
                value: NSUnderlineStyle.single.rawValue,
                range: range
            )
        }
    }

    static func render(
        from text: String,
        mode: MarkdownTypographyMode = .allSystem,
        textSizePreset: MarkdownReaderTextSizePreset = .default,
        isDarkMode: Bool = false
    ) -> NSAttributedString {
        let (cleanedSource, documentLinks) = MarkdownContentBlocks.extractDocumentReferenceLinks(from: text)
        let typography = MarkdownTypography(mode: mode, textSizePreset: textSizePreset)
        let source = cleanedSource.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = MarkdownContentBlocks.sourceLines(from: source)
        var displayLines: [String] = []
        var lineStyles: [(headingLevel: Int?, isList: Bool, isQuote: Bool, isCodeBlock: Bool, startsAfterBlankLine: Bool)] = []
        displayLines.reserveCapacity(lines.count)
        lineStyles.reserveCapacity(lines.count)
        var pendingParagraphBreak = false

        for sourceLine in lines {
            let line = sourceLine.text
            let prefixCount = line.prefix(while: { $0 == " " || $0 == "\t" }).count
            let indent = String(line.prefix(prefixCount))
            let content = String(line.dropFirst(prefixCount))
            let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)

            if sourceLine.isFence {
                pendingParagraphBreak = true
                continue
            }

            if sourceLine.isCode {
                displayLines.append(line)
                lineStyles.append((
                    headingLevel: nil,
                    isList: false,
                    isQuote: false,
                    isCodeBlock: true,
                    startsAfterBlankLine: pendingParagraphBreak
                ))
                pendingParagraphBreak = false
                continue
            }

            if trimmedContent.isEmpty {
                displayLines.append("")
                lineStyles.append((
                    headingLevel: nil,
                    isList: false,
                    isQuote: false,
                    isCodeBlock: false,
                    startsAfterBlankLine: false
                ))
                pendingParagraphBreak = true
                continue
            }

            var renderedLine = line
            var headingLevelValue: Int?
            var isList = false
            var isQuote = false

            if let level = MarkdownContentBlocks.headingLevel(in: content) {
                headingLevelValue = level
                let markerLength = level + 1
                let body = String(content.dropFirst(markerLength))
                renderedLine = indent + body
            } else if let item = MarkdownContentBlocks.parseListItem(from: content) {
                isList = true
                renderedLine = indent + item.marker + " " + item.body
            } else if content.hasPrefix(">") {
                isQuote = true
                var quoteLevel = 0
                var remainder = content[...]
                while remainder.hasPrefix(">") {
                    quoteLevel += 1
                    remainder = remainder.dropFirst()
                    if remainder.hasPrefix(" ") {
                        remainder = remainder.dropFirst()
                    }
                }
                let bars = String(repeating: "▎ ", count: quoteLevel)
                renderedLine = indent + bars + String(remainder)
            }

            displayLines.append(renderedLine)
            lineStyles.append((
                headingLevel: headingLevelValue,
                isList: isList,
                isQuote: isQuote,
                isCodeBlock: false,
                startsAfterBlankLine: pendingParagraphBreak
            ))
            pendingParagraphBreak = false
        }

        let attributedLines: [NSAttributedString] = displayLines.enumerated().map { index, line in
            let style = lineStyles[index]
            if style.isCodeBlock {
                let codeFont = NSFont.monospacedSystemFont(
                    ofSize: max(typography.codeMinimumFontSize, typography.bodyFont().pointSize * typography.codeFontScale),
                    weight: .regular
                )
                let codeParagraph = NSMutableParagraphStyle()
                codeParagraph.firstLineHeadIndent = typography.codeBlockHorizontalInset
                codeParagraph.headIndent = typography.codeBlockHorizontalInset
                codeParagraph.lineHeightMultiple = typography.codeBlockLineHeightMultiple
                let previousIsCode = index > 0 ? lineStyles[index - 1].isCodeBlock : false
                let nextIsCode = index < (lineStyles.count - 1) ? lineStyles[index + 1].isCodeBlock : false
                if !previousIsCode {
                    codeParagraph.paragraphSpacingBefore = max(
                        style.startsAfterBlankLine ? typography.paragraphBreakSpacingBefore : 0,
                        typography.codeBlockParagraphSpacingBefore
                    )
                }
                codeParagraph.paragraphSpacing = nextIsCode ? 0 : typography.codeBlockParagraphSpacingAfter

                let result = NSMutableAttributedString(string: line)
                result.addAttributes([
                    .font: codeFont,
                    .foregroundColor: typography.codeForegroundColor(isDarkMode: isDarkMode),
                    .backgroundColor: typography.codeBackgroundColor(isDarkMode: isDarkMode),
                    .paragraphStyle: codeParagraph
                ], range: NSRange(location: 0, length: result.length))
                return result
            }

            if line.isEmpty {
                return NSAttributedString(string: "")
            }

            let rendered = renderInline(
                from: line,
                mode: mode,
                textSizePreset: textSizePreset,
                isDarkMode: isDarkMode,
                headingLevel: style.headingLevel,
                referenceLinks: documentLinks
            )
            let mutable = NSMutableAttributedString(attributedString: rendered)
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineHeightMultiple = typography.bodyLineHeightMultiple
            paragraph.paragraphSpacing = typography.bodyParagraphSpacing
            paragraph.paragraphSpacingBefore = style.startsAfterBlankLine ? typography.paragraphBreakSpacingBefore : 0

            if let level = style.headingLevel {
                paragraph.lineHeightMultiple = typography.headingLineHeight(for: level)
                if index > 0 {
                    paragraph.paragraphSpacingBefore = max(
                        paragraph.paragraphSpacingBefore,
                        typography.headingSpacingBefore(for: level)
                    )
                }
                paragraph.paragraphSpacing = typography.headingSpacingAfter(for: level)
            } else if style.isList {
                applyIndentedParagraphStyle(
                    paragraph: paragraph,
                    indent: typography.listIndent,
                    paragraphSpacing: typography.listParagraphSpacing,
                    lineHeightMultiple: typography.listLineHeightMultiple
                )
            } else if style.isQuote {
                applyIndentedParagraphStyle(
                    paragraph: paragraph,
                    indent: typography.listIndent,
                    paragraphSpacing: typography.listParagraphSpacing,
                    lineHeightMultiple: typography.quoteLineHeightMultiple
                )
                mutable.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: NSRange(location: 0, length: mutable.length))
                mutable.addAttribute(.obliqueness, value: typography.quoteObliqueness, range: NSRange(location: 0, length: mutable.length))
            }

            mutable.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: mutable.length))
            return mutable
        }

        let combined = NSMutableAttributedString(string: "")
        for (index, attrLine) in attributedLines.enumerated() {
            if index > 0 {
                combined.append(NSAttributedString(string: "\n"))
            }
            combined.append(attrLine)
        }
        return combined
    }

    private struct DetectedLink {
        let labelMarkdown: String
        let destination: String
    }

    private static func detectLinks(in text: String) -> [DetectedLink] {
        var links: [DetectedLink] = []
        var idx = text.startIndex

        while idx < text.endIndex {
            let ch = text[idx]
            if ch == "\\" {
                idx = text.index(after: idx)
                if idx < text.endIndex { idx = text.index(after: idx) }
                continue
            }
            if ch == "`" {
                let run = text[idx...].prefix(while: { $0 == "`" })
                let count = run.count
                var search = text.index(idx, offsetBy: count)
                var foundClosing = false
                while search < text.endIndex {
                    if text[search] == "`" {
                        let closeRun = text[search...].prefix(while: { $0 == "`" })
                        if closeRun.count == count {
                            idx = text.index(search, offsetBy: count)
                            foundClosing = true
                            break
                        } else {
                            search = text.index(search, offsetBy: closeRun.count)
                            continue
                        }
                    }
                    search = text.index(after: search)
                }
                if foundClosing {
                    continue
                }
            }
            if ch == "!" && text.index(after: idx) < text.endIndex && text[text.index(after: idx)] == "[" {
                idx = text.index(after: idx)
                continue
            }
            if ch == "[" {
                let labelStart = text.index(after: idx)
                var scan = labelStart
                var labelEnd: String.Index? = nil
                while scan < text.endIndex {
                    let c = text[scan]
                    if c == "\\" {
                        scan = text.index(after: scan)
                        if scan < text.endIndex { scan = text.index(after: scan) }
                        continue
                    }
                    if c == "`" {
                        let run = text[scan...].prefix(while: { $0 == "`" })
                        let count = run.count
                        scan = text.index(scan, offsetBy: count)
                        while scan < text.endIndex {
                            if text[scan] == "`" {
                                let closeRun = text[scan...].prefix(while: { $0 == "`" })
                                if closeRun.count == count {
                                    scan = text.index(scan, offsetBy: count)
                                    break
                                } else {
                                    scan = text.index(scan, offsetBy: closeRun.count)
                                    continue
                                }
                            }
                            scan = text.index(after: scan)
                        }
                        continue
                    }
                    if c == "]" {
                        labelEnd = scan
                        break
                    }
                    scan = text.index(after: scan)
                }

                if let lEnd = labelEnd {
                    let afterBracket = text.index(after: lEnd)
                    if afterBracket < text.endIndex && text[afterBracket] == "(" {
                        let destStart = text.index(after: afterBracket)
                        var destScan = destStart
                        var openParens = 1
                        var destEnd: String.Index? = nil
                        var insideAngleBrackets = false
                        if destStart < text.endIndex && text[destStart] == "<" {
                            insideAngleBrackets = true
                        }
                        while destScan < text.endIndex {
                            let dc = text[destScan]
                            if dc == "\\" {
                                destScan = text.index(after: destScan)
                                if destScan < text.endIndex { destScan = text.index(after: destScan) }
                                continue
                            }
                            if insideAngleBrackets {
                                if dc == ">" {
                                    insideAngleBrackets = false
                                }
                            } else {
                                if dc == "(" {
                                    openParens += 1
                                } else if dc == ")" {
                                    openParens -= 1
                                    if openParens == 0 {
                                        destEnd = destScan
                                        break
                                    }
                                }
                            }
                            destScan = text.index(after: destScan)
                        }

                        if let dEnd = destEnd {
                            let label = String(text[labelStart..<lEnd])
                            let destRaw = String(text[destStart..<dEnd]).trimmingCharacters(in: .whitespaces)
                            let destClean: String
                            if destRaw.hasPrefix("<") && destRaw.hasSuffix(">") {
                                destClean = String(destRaw.dropFirst().dropLast())
                            } else if let spaceIdx = destRaw.firstIndex(where: { $0.isWhitespace }) {
                                destClean = String(destRaw[..<spaceIdx])
                            } else {
                                destClean = destRaw
                            }
                            links.append(DetectedLink(labelMarkdown: label, destination: destClean))
                            idx = text.index(after: dEnd)
                            continue
                        }
                    }
                }
            }
            idx = text.index(after: idx)
        }
        return links
    }

    /// Serializes a URL destination for Markdown expansion, safely wrapping in angle brackets
    /// if the URL contains parentheses or whitespace that could truncate the inline link.
    nonisolated static func serializeMarkdownDestination(_ url: URL) -> String {
        let str = url.absoluteString
        if str.contains(")") || str.contains("(") || str.contains(" ") {
            let escaped = str.replacingOccurrences(of: ">", with: "%3E")
            return "<\(escaped)>"
        }
        return str
    }

    private static func substituteReferenceLinks(
        in text: String,
        referenceLinks: [String: URL]
    ) -> String {
        guard !referenceLinks.isEmpty else { return text }

        var result = ""
        result.reserveCapacity(text.count)
        var idx = text.startIndex

        while idx < text.endIndex {
            let ch = text[idx]

            if ch == "\\" {
                result.append(ch)
                let next = text.index(after: idx)
                if next < text.endIndex {
                    result.append(text[next])
                    idx = text.index(after: next)
                } else {
                    idx = next
                }
                continue
            }

            if ch == "`" {
                let run = text[idx...].prefix(while: { $0 == "`" })
                let count = run.count
                var search = text.index(idx, offsetBy: count)
                var foundClosing = false
                while search < text.endIndex {
                    if text[search] == "`" {
                        let closeRun = text[search...].prefix(while: { $0 == "`" })
                        if closeRun.count == count {
                            let closeEnd = text.index(search, offsetBy: count)
                            result.append(contentsOf: text[idx..<closeEnd])
                            idx = closeEnd
                            foundClosing = true
                            break
                        } else {
                            search = text.index(search, offsetBy: closeRun.count)
                            continue
                        }
                    }
                    search = text.index(after: search)
                }
                if foundClosing {
                    continue
                }
            }

            if ch == "[" {
                let labelStart = text.index(after: idx)
                var scan = labelStart
                var labelEnd: String.Index? = nil

                while scan < text.endIndex {
                    let c = text[scan]
                    if c == "\\" {
                        scan = text.index(after: scan)
                        if scan < text.endIndex { scan = text.index(after: scan) }
                        continue
                    }
                    if c == "`" {
                        let run = text[scan...].prefix(while: { $0 == "`" })
                        let count = run.count
                        scan = text.index(scan, offsetBy: count)
                        while scan < text.endIndex {
                            if text[scan] == "`" {
                                let closeRun = text[scan...].prefix(while: { $0 == "`" })
                                if closeRun.count == count {
                                    scan = text.index(scan, offsetBy: count)
                                    break
                                } else {
                                    scan = text.index(scan, offsetBy: closeRun.count)
                                    continue
                                }
                            }
                            scan = text.index(after: scan)
                        }
                        continue
                    }
                    if c == "]" {
                        labelEnd = scan
                        break
                    }
                    scan = text.index(after: scan)
                }

                if let lEnd = labelEnd {
                    let label = String(text[labelStart..<lEnd])
                    let afterBracket = text.index(after: lEnd)

                    if afterBracket < text.endIndex && text[afterBracket] == "(" {
                        result.append(ch)
                        idx = text.index(after: idx)
                        continue
                    }

                    if afterBracket < text.endIndex && text[afterBracket] == "[" {
                        let refStart = text.index(after: afterBracket)
                        var refScan = refStart
                        var refEnd: String.Index? = nil
                        while refScan < text.endIndex {
                            let rc = text[refScan]
                            if rc == "\\" {
                                refScan = text.index(after: refScan)
                                if refScan < text.endIndex { refScan = text.index(after: refScan) }
                                continue
                            }
                            if rc == "]" {
                                refEnd = refScan
                                break
                            }
                            refScan = text.index(after: refScan)
                        }

                        if let rEnd = refEnd {
                            let refRaw = String(text[refStart..<rEnd])
                            let lookupLabel = refRaw.isEmpty ? label : refRaw
                            let key = MarkdownContentBlocks.normalizeReferenceLabel(lookupLabel)
                            if !key.isEmpty, let url = referenceLinks[key] {
                                result.append("[\(label)](\(serializeMarkdownDestination(url)))")
                                idx = text.index(after: rEnd)
                                continue
                            } else {
                                // Explicit reference ([foo][bar] or [foo][]) where reference is undefined:
                                // Don't fall back to shortcut foo. Copy the entire reference literal as-is
                                // and advance past rEnd so inner labels are not scanned as shortcut links.
                                result.append(contentsOf: text[idx...rEnd])
                                idx = text.index(after: rEnd)
                                continue
                            }
                        }
                    }

                    let key = MarkdownContentBlocks.normalizeReferenceLabel(label)
                    if !key.isEmpty, let url = referenceLinks[key] {
                        result.append("[\(label)](\(serializeMarkdownDestination(url)))")
                        idx = text.index(after: lEnd)
                        continue
                    }
                }
            }

            result.append(ch)
            idx = text.index(after: idx)
        }

        return result
    }

    private static func applyIndentedParagraphStyle(
        paragraph: NSMutableParagraphStyle,
        indent: CGFloat,
        paragraphSpacing: CGFloat,
        lineHeightMultiple: CGFloat
    ) {
        paragraph.firstLineHeadIndent = indent
        paragraph.headIndent = indent
        paragraph.paragraphSpacing = paragraphSpacing
        paragraph.lineHeightMultiple = lineHeightMultiple
    }
}
#endif

private enum MarkdownDocumentLoadError: LocalizedError {
    case unsupportedTextEncoding

    var errorDescription: String? {
        switch self {
        case .unsupportedTextEncoding:
            return String(localized: "Unable to decode file as UTF-8/UTF-16 text")
        }
    }
}

@MainActor
final class MarkdownDoc: ObservableObject {
    @Published var blocks: [MarkdownRenderedBlock] = []
    @Published var isLoading: Bool = false
    @Published var error: String?

    private var preparedBlocks: [MarkdownPreparedBlock] = []
    private let prepareDocument: @Sendable (URL) async throws -> [MarkdownPreparedBlock]
    private var loadGeneration: UInt64 = 0
    private var mode: MarkdownTypographyMode = .allSystem
    private var textSizePreset: MarkdownReaderTextSizePreset = .default
    private var isDarkMode = false

    init(prepareDocument: (@Sendable (URL) async throws -> [MarkdownPreparedBlock])? = nil) {
        self.prepareDocument = prepareDocument ?? Self.loadPreparedBlocks
    }

    func load(
        from url: URL,
        mode: MarkdownTypographyMode = .allSystem,
        textSizePreset: MarkdownReaderTextSizePreset = .default,
        isDarkMode: Bool = false
    ) async {
        guard !Task.isCancelled else { return }
        loadGeneration &+= 1
        let generation = loadGeneration
        self.mode = mode
        self.textSizePreset = textSizePreset
        self.isDarkMode = isDarkMode
        isLoading = true
        error = nil
        blocks = []
        preparedBlocks = []

        do {
            let prepared = try await prepareDocument(url)
            try Task.checkCancellation()
            guard generation == loadGeneration else { return }
            preparedBlocks = prepared
            rerenderFromPreparedBlocks(mode: self.mode, textSizePreset: self.textSizePreset, isDarkMode: self.isDarkMode)
            isLoading = false
        } catch is CancellationError {
            guard generation == loadGeneration else { return }
            isLoading = false
        } catch {
            guard generation == loadGeneration else { return }
            isLoading = false
            guard !Task.isCancelled else { return }
            self.error = error.localizedDescription
        }
    }

    func rerenderFromPreparedBlocks(
        mode: MarkdownTypographyMode,
        textSizePreset: MarkdownReaderTextSizePreset,
        isDarkMode: Bool
    ) {
        self.mode = mode
        self.textSizePreset = textSizePreset
        self.isDarkMode = isDarkMode
        guard !preparedBlocks.isEmpty else { return }
        #if os(macOS)
        blocks = MarkdownContentBlocks.render(
            preparedBlocks: preparedBlocks,
            mode: mode,
            textSizePreset: textSizePreset,
            isDarkMode: isDarkMode
        )
        #else
        blocks = []
        #endif
    }

    private nonisolated static func loadPreparedBlocks(from url: URL) async throws -> [MarkdownPreparedBlock] {
        let needsAccess = url.startAccessingSecurityScopedResource()
        defer {
            if needsAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        try Task.checkCancellation()
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16) else {
            throw MarkdownDocumentLoadError.unsupportedTextEncoding
        }
        return MarkdownContentBlocks.prepare(from: text)
    }
}

private enum ReaderLayout {
    static let maxReadableWidth: CGFloat = 700
    static let horizontalPadding: CGFloat = 24
    static let verticalPadding: CGFloat = 42
    static let edgeFadeHeight: CGFloat = 34
}

struct MarkdownViewer: View {
    let url: URL
    @StateObject private var doc = MarkdownDoc()
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(AppPreferenceKeys.markdownTypographyMode)
    private var typographyModeRawValue = MarkdownTypographyMode.allSystem.rawValue
    @AppStorage(AppPreferenceKeys.markdownReaderTextSizePreset)
    private var textSizePresetRawValue = MarkdownReaderTextSizePreset.default.rawValue

    private var typographyMode: MarkdownTypographyMode {
        MarkdownTypographyMode(rawValue: typographyModeRawValue) ?? .allSystem
    }

    private var textSizePreset: MarkdownReaderTextSizePreset {
        MarkdownReaderTextSizePreset(rawValue: textSizePresetRawValue) ?? .default
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: MarkyTheme.backgroundGradientColors(for: colorScheme),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            content
        }
        .task(id: url) {
            await doc.load(
                from: url,
                mode: typographyMode,
                textSizePreset: textSizePreset,
                isDarkMode: colorScheme == .dark
            )
        }
        .onChange(of: typographyModeRawValue) {
            doc.rerenderFromPreparedBlocks(
                mode: typographyMode,
                textSizePreset: textSizePreset,
                isDarkMode: colorScheme == .dark
            )
        }
        .onChange(of: textSizePresetRawValue) {
            doc.rerenderFromPreparedBlocks(
                mode: typographyMode,
                textSizePreset: textSizePreset,
                isDarkMode: colorScheme == .dark
            )
        }
        .onChange(of: colorScheme) {
            doc.rerenderFromPreparedBlocks(
                mode: typographyMode,
                textSizePreset: textSizePreset,
                isDarkMode: colorScheme == .dark
            )
        }
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    @ViewBuilder
    private var content: some View {
        if doc.isLoading {
            ProgressView("Loading…")
        } else if let error = doc.error {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                Text(error)
            }
            .padding()
        } else if !doc.blocks.isEmpty {
            ReaderScrollContainer {
                MarkdownDocumentBlocks(
                    blocks: doc.blocks,
                    documentURL: url,
                    typographyMode: typographyMode,
                    textSizePreset: textSizePreset,
                    isDarkMode: colorScheme == .dark
                )
            }
            .accessibilityIdentifier("markdown-reader")
        } else {
            Text("No content")
        }
    }
}

private struct MarkdownDocumentBlocks: View {
    let blocks: [MarkdownRenderedBlock]
    let documentURL: URL?
    let typographyMode: MarkdownTypographyMode
    let textSizePreset: MarkdownReaderTextSizePreset
    let isDarkMode: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var typography: MarkdownTypography {
        MarkdownTypography(mode: typographyMode, textSizePreset: textSizePreset)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(blocks) { block in
                switch block.kind {
                case .heading(let level, let rendered):
                    Text(rendered)
                        .textSelection(.enabled)
                        .padding(.top, topSpacing(for: block))
                        .padding(.bottom, typography.headingSpacingAfter(for: level))
                case .paragraph(let rendered):
                    Text(rendered)
                        .lineSpacing(typography.bodyLineSpacing)
                        .textSelection(.enabled)
                        .padding(.top, topSpacing(for: block))
                        .padding(.bottom, typography.paragraphBlockSpacing)
                case .list(let items):
                    MarkdownListBlock(items: items, typography: typography)
                        .padding(.top, topSpacing(for: block))
                        .padding(.bottom, typography.listBlockSpacing)
                case .quote(let rendered):
                    MarkdownQuoteBlock(rendered: rendered, typography: typography, colorScheme: colorScheme)
                        .padding(.top, topSpacing(for: block))
                        .padding(.bottom, typography.quoteBlockSpacing)
                case .code(let code):
                    MarkdownCodeBlock(code: code, typography: typography, isDarkMode: isDarkMode)
                        .padding(.top, topSpacing(for: block))
                case .table(let table):
                    MarkdownTableView(table: table, typography: typography, colorScheme: colorScheme)
                        .padding(.top, topSpacing(for: block))
                        .padding(.bottom, typography.paragraphBlockSpacing)
                case .thematicBreak:
                    MarkdownThematicBreakView(colorScheme: colorScheme)
                        .padding(.top, topSpacing(for: block))
                        .padding(.bottom, typography.paragraphBlockSpacing)
                case .image(let alt, let url, let title):
                    MarkdownImageView(
                        alt: alt,
                        url: url,
                        title: title,
                        documentURL: documentURL,
                        typography: typography,
                        colorScheme: colorScheme
                    )
                    .padding(.top, topSpacing(for: block))
                    .padding(.bottom, typography.paragraphBlockSpacing)
                }
            }
        }
    }

    private func topSpacing(for block: MarkdownRenderedBlock) -> CGFloat {
        guard let previous = blocks[safe: block.id - 1] else { return 0 }

        switch block.kind {
        case .heading(let level, _):
            return typography.headingSpacingBefore(for: level)
        case .paragraph:
            if case .heading = previous.kind {
                return 0
            }
            return 0
        case .list:
            if case .heading = previous.kind {
                return 0
            }
            return typography.paragraphBlockSpacing * 0.25
        case .quote:
            if case .heading = previous.kind {
                return typography.paragraphBlockSpacing * 0.15
            }
            return typography.paragraphBlockSpacing * 0.25
        case .code:
            return 0
        case .table:
            return typography.paragraphBlockSpacing * 0.35
        case .thematicBreak:
            return 0
        case .image:
            return typography.paragraphBlockSpacing * 0.3
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}

private struct MarkdownQuoteBlock: View {
    let rendered: AttributedString
    let typography: MarkdownTypography
    let colorScheme: ColorScheme

    var body: some View {
        HStack(alignment: .top, spacing: MarkyTheme.quoteBarSpacing) {
            RoundedRectangle(cornerRadius: MarkyTheme.quoteBarCornerRadius)
                .fill(MarkyTheme.quoteBarColor(for: colorScheme))
                .frame(width: MarkyTheme.quoteBarWidth)
            Text(rendered)
                .lineSpacing(typography.bodyLineSpacing)
                .foregroundStyle(Color.secondary)
                .textSelection(.enabled)
        }
        .padding(.leading, MarkyTheme.quoteLeadingInset)
    }
}

private struct MarkdownThematicBreakView: View {
    let colorScheme: ColorScheme

    var body: some View {
        Rectangle()
            .fill(MarkyTheme.thematicBreakColor(for: colorScheme))
            .frame(height: MarkyTheme.thematicBreakHeight)
            .padding(.vertical, MarkyTheme.thematicBreakPaddingVertical)
            .accessibilityElement()
            .accessibilityLabel("Horizontal Rule")
    }
}

private struct MarkdownTableView: View {
    let table: MarkdownRenderedTable
    let typography: MarkdownTypography
    let colorScheme: ColorScheme

    @State private var contentHeight: CGFloat = 0

    private func computeColumnWidths() -> [CGFloat] {
        let headerCount = table.headers.count
        let maxRowCount = table.rows.map(\.cells.count).max() ?? 0
        let count = max(headerCount, maxRowCount)
        guard count > 0 else { return [] }
        let charWidth = typography.bodyFontSize * MarkyTheme.tableCharacterWidthMultiplier
        let padding = MarkyTheme.tableCellHorizontalPadding * 2

        return (0..<count).map { colIndex in
            var maxChars = 0
            if colIndex < table.headers.count {
                maxChars = max(maxChars, table.headers[colIndex].content.characters.count)
            }
            for row in table.rows {
                if colIndex < row.cells.count {
                    maxChars = max(maxChars, row.cells[colIndex].content.characters.count)
                }
            }
            let estimatedWidth = CGFloat(maxChars) * charWidth + padding
            return min(max(estimatedWidth, MarkyTheme.tableCellMinWidth), MarkyTheme.tableCellMaxWidth)
        }
    }

    var body: some View {
        let widths = computeColumnWidths()

        ScrollView(.horizontal, showsIndicators: true) {
            gridContent(widths: widths)
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    ceil(proxy.size.height)
                } action: { newHeight in
                    if abs(contentHeight - newHeight) > 1.0 {
                        contentHeight = newHeight
                    }
                }
        }
        .frame(height: contentHeight > 0 ? contentHeight : nil)
        .accessibilityIdentifier("table-scroll-view")
    }

    private func gridContent(widths: [CGFloat]) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
            if !table.headers.isEmpty {
                GridRow {
                    ForEach(Array(table.headers.enumerated()), id: \.element.id) { colIndex, cell in
                        cellView(
                            cell,
                            width: widths[safe: colIndex] ?? MarkyTheme.tableCellMinWidth,
                            isHeader: true,
                            isAlternate: false
                        )
                    }
                }
            }
            ForEach(Array(table.rows.enumerated()), id: \.element.id) { index, row in
                GridRow {
                    ForEach(Array(row.cells.enumerated()), id: \.element.id) { colIndex, cell in
                        cellView(
                            cell,
                            width: widths[safe: colIndex] ?? MarkyTheme.tableCellMinWidth,
                            isHeader: false,
                            isAlternate: index % 2 == 1
                        )
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: MarkyTheme.tableCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: MarkyTheme.tableCornerRadius, style: .continuous)
                .stroke(MarkyTheme.tableBorderColor(for: colorScheme), lineWidth: MarkyTheme.tableBorderLineWidth)
        )
        .padding(MarkyTheme.tableOuterPadding)
        .padding(.bottom, MarkyTheme.tableScrollIndicatorSpacing)
    }

    private func cellView(
        _ cell: MarkdownTableCell,
        width: CGFloat,
        isHeader: Bool,
        isAlternate: Bool
    ) -> some View {
        let textAlignment: TextAlignment = {
            switch cell.alignment {
            case .left: return .leading
            case .center: return .center
            case .right: return .trailing
            }
        }()

        let frameAlignment: Alignment = {
            switch cell.alignment {
            case .left: return .leading
            case .center: return .center
            case .right: return .trailing
            }
        }()

        return Text(cell.content)
            .lineSpacing(typography.bodyLineSpacing * MarkyTheme.tableLineSpacingScale)
            .multilineTextAlignment(textAlignment)
            .foregroundStyle(Color.primary)
            .textSelection(.enabled)
            .padding(.horizontal, MarkyTheme.tableCellHorizontalPadding)
            .padding(.vertical, MarkyTheme.tableCellVerticalPadding)
            .frame(width: width, alignment: frameAlignment)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: frameAlignment)
            .background(
                isHeader
                    ? MarkyTheme.tableHeaderBackgroundColor(for: colorScheme)
                    : MarkyTheme.tableRowBackgroundColor(isAlternate: isAlternate, for: colorScheme)
            )
            .overlay(
                Rectangle()
                    .stroke(MarkyTheme.tableBorderColor(for: colorScheme), lineWidth: MarkyTheme.tableCellBorderLineWidth)
            )
    }
}

struct MarkdownImageView: View {
    let alt: String
    let url: String
    let title: String?
    let documentURL: URL?
    let typography: MarkdownTypography
    let colorScheme: ColorScheme

    @State private var loadedLocalImage: NSImage?
    @State private var loadErrorMessage: String?
    @State private var grantedFolderURL: URL?
    @State private var loadAttemptID = UUID()
    @State private var isPresentingFolderPicker = false

    /// Normalizes and returns a remote URL if the string scheme is http or https (case-insensitively).
    static func remoteURL(from urlString: String) -> URL? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsed = URL(string: trimmed), let scheme = parsed.scheme?.lowercased() else {
            return nil
        }
        guard scheme == "http" || scheme == "https" else {
            return nil
        }
        if parsed.scheme != scheme {
            var components = URLComponents(url: parsed, resolvingAgainstBaseURL: false)
            components?.scheme = scheme
            return components?.url ?? parsed
        }
        return parsed
    }

    static func resolveLocalFileURL(for urlString: String, relativeTo documentURL: URL?) -> URL? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let parsedURL = URL(string: trimmed), let scheme = parsedURL.scheme {
            if scheme.lowercased() == "file" {
                return parsedURL.standardizedFileURL
            } else {
                return nil
            }
        }

        let baseDir = documentURL?.deletingLastPathComponent().standardizedFileURL

        if let url = URL(string: trimmed, relativeTo: baseDir), url.isFileURL {
            return url.standardizedFileURL
        }

        if let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
           let url = URL(string: encoded, relativeTo: baseDir), url.isFileURL {
            return url.standardizedFileURL
        }

        if trimmed.hasPrefix("/") {
            return URL(fileURLWithPath: trimmed).standardizedFileURL
        }

        if let baseDir {
            let decoded = trimmed.removingPercentEncoding ?? trimmed
            return URL(fileURLWithPath: decoded, relativeTo: baseDir).standardizedFileURL
        }

        return nil
    }

    private var isLocalImage: Bool {
        Self.remoteURL(from: url) == nil && Self.resolveLocalFileURL(for: url, relativeTo: documentURL) != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MarkyTheme.imageCaptionSpacing) {
            imageContent
            if let title, !title.isEmpty {
                Text(title)
                    .font(.system(size: typography.bodyFontSize * MarkyTheme.imageTitleFontScale))
                    .foregroundStyle(Color.secondary)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: "\(url)|\(documentURL?.path ?? "")|\(loadAttemptID)") {
            await loadLocalImageAsync(folderURL: grantedFolderURL)
        }
    }

    @ViewBuilder
    private var imageContent: some View {
        if let remoteURL = Self.remoteURL(from: url) {
            AsyncImage(url: remoteURL) { phase in
                switch phase {
                case .empty:
                    HStack(spacing: MarkyTheme.imageLoadingHStackSpacing) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text(alt.isEmpty ? String(localized: "Loading image…") : alt)
                            .font(.system(size: typography.bodyFontSize * MarkyTheme.imageLoadingTextFontScale))
                            .foregroundStyle(Color.secondary)
                    }
                    .frame(height: MarkyTheme.imagePlaceholderHeight)
                    .frame(maxWidth: .infinity)
                    .background(MarkyTheme.tableHeaderBackgroundColor(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: MarkyTheme.imageCornerRadius, style: .continuous))
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: MarkyTheme.imageCornerRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: MarkyTheme.imageCornerRadius, style: .continuous)
                                .stroke(MarkyTheme.tableBorderColor(for: colorScheme), lineWidth: MarkyTheme.tableCellBorderLineWidth)
                        )
                        .accessibilityLabel(alt.isEmpty ? String(localized: "Image") : alt)
                case .failure:
                    fallbackCard
                @unknown default:
                    fallbackCard
                }
            }
        } else if let localImage = loadedLocalImage {
            Image(nsImage: localImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: MarkyTheme.imageCornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: MarkyTheme.imageCornerRadius, style: .continuous)
                        .stroke(MarkyTheme.tableBorderColor(for: colorScheme), lineWidth: MarkyTheme.tableCellBorderLineWidth)
                )
                .accessibilityLabel(alt.isEmpty ? String(localized: "Image") : alt)
        } else {
            fallbackCard
        }
    }

    private var fallbackCard: some View {
        HStack(spacing: MarkyTheme.imageCardHStackSpacing) {
            Image(systemName: "photo")
                .font(.system(size: MarkyTheme.imageCardIconSize))
                .foregroundStyle(Color.secondary)
            VStack(alignment: .leading, spacing: MarkyTheme.imageCardVStackSpacing) {
                Text(alt.isEmpty ? String(localized: "Image") : alt)
                    .font(.system(size: typography.bodyFontSize * MarkyTheme.imageCardTitleFontScale, weight: .medium))
                    .foregroundStyle(Color.primary)
                Text(url)
                    .font(.system(size: typography.bodyFontSize * MarkyTheme.imageCardUrlFontScale, design: .monospaced))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
                if let loadErrorMessage {
                    Text(loadErrorMessage)
                        .font(.system(size: typography.bodyFontSize * MarkyTheme.imageCardUrlFontScale))
                        .foregroundStyle(Color.secondary)
                }
            }
            .textSelection(.enabled)

            if isLocalImage {
                Spacer()
                Button {
                    promptForFolderAccess()
                } label: {
                    Label(
                        loadErrorMessage != nil ? String(localized: "Grant Folder Access…") : String(localized: "Choose Folder…"),
                        systemImage: "folder.badge.plus"
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, MarkyTheme.imageCardHorizontalPadding)
        .padding(.vertical, MarkyTheme.imageCardVerticalPadding)
        .background(MarkyTheme.tableHeaderBackgroundColor(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: MarkyTheme.imageCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: MarkyTheme.imageCornerRadius, style: .continuous)
                .stroke(MarkyTheme.tableBorderColor(for: colorScheme), lineWidth: MarkyTheme.tableCellBorderLineWidth)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(alt.isEmpty ? String(localized: "Image: \(url)") : alt)
    }

    private func loadLocalImageAsync(folderURL: URL? = nil) async {
        self.loadedLocalImage = nil
        self.loadErrorMessage = nil
        guard let targetURL = Self.resolveLocalFileURL(for: url, relativeTo: documentURL) else { return }
        do {
            let image: NSImage
            if let folderURL {
                image = try await LocalImageLoader.loadImage(at: targetURL, under: folderURL)
            } else {
                image = try await LocalImageLoader.loadImage(at: targetURL)
            }
            guard !Task.isCancelled else { return }
            self.loadedLocalImage = image
            self.loadErrorMessage = nil
        } catch is CancellationError {
            // Cancelled cleanly
        } catch {
            guard !Task.isCancelled else { return }
            self.loadErrorMessage = error.localizedDescription
        }
    }

    private func promptForFolderAccess() {
        #if os(macOS)
        guard !isPresentingFolderPicker else { return }
        isPresentingFolderPicker = true
        let capturedURL = self.url
        let capturedDocURL = self.documentURL
        guard let targetURL = Self.resolveLocalFileURL(for: capturedURL, relativeTo: capturedDocURL) else {
            isPresentingFolderPicker = false
            return
        }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.prompt = String(localized: "Grant Access")
        panel.message = String(localized: "Select the folder containing this image.")
        panel.directoryURL = targetURL.deletingLastPathComponent().standardizedFileURL

        Task { @MainActor in
            defer { self.isPresentingFolderPicker = false }
            let response = await withCheckedContinuation { continuation in
                panel.begin { res in continuation.resume(returning: res) }
            }
            guard self.url == capturedURL && self.documentURL == capturedDocURL else {
                return
            }
            guard response == .OK, let selectedFolder = panel.url else {
                return
            }
            self.grantedFolderURL = selectedFolder
            self.loadAttemptID = UUID()
        }
        #endif
    }
}

private struct MarkdownListBlock: View {
    let items: [MarkdownListItem]
    let typography: MarkdownTypography

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                HStack(alignment: .firstTextBaseline, spacing: typography.listMarkerGap) {
                    Text(item.marker)
                        .font(Font(typography.listMarkerFont(for: item.marker)))
                        .frame(width: typography.listMarkerColumnWidth, alignment: .leading)
                    Text(item.body)
                        .lineSpacing(typography.bodyLineSpacing)
                        .textSelection(.enabled)
                }
                .padding(.leading, CGFloat(item.nestingLevel) * typography.nestedListIndent)
                .padding(.top, topSpacing(for: index))
            }
        }
    }

    private func topSpacing(for index: Int) -> CGFloat {
        guard index > 0 else { return 0 }
        let previous = items[index - 1]
        let current = items[index]
        if current.nestingLevel != previous.nestingLevel {
            return typography.nestedListSpacing
        }
        return typography.listItemSpacing
    }
}

private struct MarkdownCodeBlock: View {
    let code: String
    let typography: MarkdownTypography
    let isDarkMode: Bool

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            Text(verbatim: code)
                .font(
                    .system(
                        size: max(
                            typography.codeMinimumFontSize,
                            typography.bodyFontSize * typography.codeFontScale
                        ),
                        design: .monospaced
                    )
                )
                .foregroundStyle(Color(nsColor: typography.codeForegroundColor(isDarkMode: isDarkMode)))
                .lineSpacing(
                    typography.bodyFontSize * max(0, typography.codeBlockLineHeightMultiple - 1.0)
                )
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, typography.codeBlockHorizontalInset)
                .padding(.vertical, typography.codeBlockVerticalInset)
                .fixedSize(horizontal: true, vertical: false)
        }
        .background(Color(nsColor: typography.codeBackgroundColor(isDarkMode: isDarkMode)))
        .clipShape(RoundedRectangle(cornerRadius: typography.codeBlockCornerRadius, style: .continuous))
        .padding(.top, typography.codeBlockParagraphSpacingBefore)
        .padding(.bottom, typography.codeBlockParagraphSpacingAfter)
    }
}

private struct ReaderScrollContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .frame(maxWidth: ReaderLayout.maxReadableWidth, alignment: .leading)
            .padding(.horizontal, ReaderLayout.horizontalPadding)
            .padding(.vertical, ReaderLayout.verticalPadding)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .mask {
            GeometryReader { geometry in
                let height = max(geometry.size.height, 1)
                let normalizedFade = min(ReaderLayout.edgeFadeHeight / height, 0.45)

                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: normalizedFade),
                        .init(color: .black, location: 1 - normalizedFade),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }
}

#Preview {
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Preview.md")
    try? "# Hello\n\nThis is a **Markdown** preview.".data(using: .utf8)?.write(to: tmp)
    return NavigationStack { MarkdownViewer(url: tmp) }
}
