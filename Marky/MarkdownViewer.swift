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
    private static let codeRegex = compilePattern(#"(?<!`)(`+)(?!`)([^\n]+?)(?<!`)\1(?!`)"#)
    private static let linkRegex = compilePattern(#"\[([^\]]+)\]\(([^)\s]+)\)"#)
    private static let boldRegex = compilePattern(#"\*\*([^*\n]+)\*\*"#)

    private static func compilePattern(_ pattern: String) -> NSRegularExpression? {
        do {
            return try NSRegularExpression(pattern: pattern)
        } catch {
            logger.fault("Built-in Markdown pattern compilation failed")
            return nil
        }
    }

    static func render(
        from text: String,
        mode: MarkdownTypographyMode = .allSystem,
        textSizePreset: MarkdownReaderTextSizePreset = .default,
        isDarkMode: Bool = false
    ) -> NSAttributedString {
        let typography = MarkdownTypography(mode: mode, textSizePreset: textSizePreset)
        let source = text.replacingOccurrences(of: "\r\n", with: "\n")
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
            } else if content.hasPrefix("> ") {
                isQuote = true
                let body = String(content.dropFirst(2))
                renderedLine = indent + "▎ " + body
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

        let display = displayLines.joined(separator: "\n")
        let styled = NSMutableAttributedString(string: display)
        let bodyFont = typography.bodyFont()
        let baseParagraph = NSMutableParagraphStyle()
        baseParagraph.lineHeightMultiple = typography.bodyLineHeightMultiple
        baseParagraph.paragraphSpacing = typography.bodyParagraphSpacing

        styled.addAttributes([
            .font: bodyFont,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: baseParagraph,
            .kern: typography.bodyTracking
        ], range: NSRange(location: 0, length: styled.length))

        var location = 0
        for (index, line) in displayLines.enumerated() {
            let lineLength = (line as NSString).length
            let lineRange = NSRange(location: location, length: lineLength)
            location += lineLength + 1
            guard lineLength > 0 else { continue }

            var font = bodyFont
            let paragraph = baseParagraph.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
            let style = lineStyles[index]
            paragraph.paragraphSpacingBefore = style.startsAfterBlankLine ? typography.paragraphBreakSpacingBefore : 0

            if style.isCodeBlock {
                font = NSFont.monospacedSystemFont(
                    ofSize: max(typography.codeMinimumFontSize, bodyFont.pointSize * typography.codeFontScale),
                    weight: .regular
                )
                paragraph.firstLineHeadIndent = typography.codeBlockHorizontalInset
                paragraph.headIndent = typography.codeBlockHorizontalInset
                paragraph.lineHeightMultiple = typography.codeBlockLineHeightMultiple
                let previousIsCodeBlock = index > 0 ? lineStyles[index - 1].isCodeBlock : false
                let nextIsCodeBlock = index < (lineStyles.count - 1) ? lineStyles[index + 1].isCodeBlock : false
                if !previousIsCodeBlock {
                    paragraph.paragraphSpacingBefore = max(
                        paragraph.paragraphSpacingBefore,
                        typography.codeBlockParagraphSpacingBefore
                    )
                }
                paragraph.paragraphSpacing = nextIsCodeBlock ? 0 : typography.codeBlockParagraphSpacingAfter
                styled.addAttribute(
                    .backgroundColor,
                    value: typography.codeBackgroundColor(isDarkMode: isDarkMode),
                    range: lineRange
                )
            } else if let level = style.headingLevel {
                font = typography.headingFont(for: level)
                paragraph.lineHeightMultiple = typography.headingLineHeight(for: level)
                if index > 0 {
                    paragraph.paragraphSpacingBefore = max(
                        paragraph.paragraphSpacingBefore,
                        typography.headingSpacingBefore(for: level)
                    )
                }
                paragraph.paragraphSpacing = typography.headingSpacingAfter(for: level)
                styled.addAttribute(.kern, value: typography.headingTracking, range: lineRange)
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
                styled.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: lineRange)
                styled.addAttribute(.obliqueness, value: typography.quoteObliqueness, range: lineRange)
            }

            styled.addAttribute(.font, value: font, range: lineRange)
            styled.addAttribute(.paragraphStyle, value: paragraph, range: lineRange)
        }

        let protectedRanges = codeBlockRanges(displayLines: displayLines, lineStyles: lineStyles)
        applyInlineStyles(
            to: styled,
            typography: typography,
            protectedRanges: protectedRanges,
            isDarkMode: isDarkMode
        )
        return styled
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

    private static func codeBlockRanges(
        displayLines: [String],
        lineStyles: [(headingLevel: Int?, isList: Bool, isQuote: Bool, isCodeBlock: Bool, startsAfterBlankLine: Bool)]
    ) -> [NSRange] {
        var ranges: [NSRange] = []
        var location = 0
        for (index, line) in displayLines.enumerated() {
            let lineLength = (line as NSString).length
            if lineStyles[index].isCodeBlock, lineLength > 0 {
                ranges.append(NSRange(location: location, length: lineLength))
            }
            location += lineLength + 1
        }
        return ranges
    }

    private static func applyInlineStyles(
        to styled: NSMutableAttributedString,
        typography: MarkdownTypography,
        protectedRanges: [NSRange],
        isDarkMode: Bool
    ) {
        // Attributes move with edits; absolute offsets from an earlier pass do not.
        let literal = NSAttributedString.Key("MarkyLiteralCode")
        for range in protectedRanges {
            styled.addAttribute(literal, value: true, range: range)
        }
        func transform(
            _ regex: NSRegularExpression?,
            bodyGroup: Int = 1,
            allowsLiteralBody: Bool = true,
            apply: (NSTextCheckingResult, NSMutableAttributedString) -> Void
        ) {
            guard let regex else { return }
            let matches = regex.matches(in: styled.string, range: NSRange(location: 0, length: styled.length))
            for match in matches.reversed() {
                let bodyRange = match.range(at: bodyGroup)
                var crossesLiteralSyntax = false
                styled.enumerateAttribute(literal, in: match.range) { value, range, _ in
                    guard value != nil else { return }
                    // A label may contain code, but its delimiters and URL must be prose.
                    if !allowsLiteralBody || NSIntersectionRange(range, bodyRange) != range {
                        crossesLiteralSyntax = true
                    }
                }
                guard !crossesLiteralSyntax else { continue }
                let replacement = NSMutableAttributedString(attributedString: styled.attributedSubstring(from: bodyRange))
                apply(match, replacement)
                styled.replaceCharacters(in: match.range, with: replacement)
            }
        }

        // Backreferences pair whole delimiter runs; shorter backticks remain literal content.
        transform(codeRegex, bodyGroup: 2, allowsLiteralBody: false) { _, replacement in
            let fullRange = NSRange(location: 0, length: replacement.length)
            replacement.enumerateAttribute(.font, in: fullRange) { value, range, _ in
                let font = (value as? NSFont) ?? typography.bodyFont()
                replacement.addAttribute(.font, value: NSFont.monospacedSystemFont(
                    ofSize: max(typography.codeMinimumFontSize, font.pointSize * typography.codeFontScale),
                    weight: .regular
                ), range: range)
            }
            replacement.addAttributes([
                literal: true,
                .foregroundColor: typography.codeForegroundColor(isDarkMode: isDarkMode),
                .backgroundColor: typography.codeBackgroundColor(isDarkMode: isDarkMode)
            ], range: fullRange)
        }
        transform(linkRegex) { match, replacement in
            let urlString = (styled.string as NSString).substring(with: match.range(at: 2))
            if let url = URL(string: urlString) {
                replacement.addAttributes([
                    .link: url,
                    .underlineStyle: typography.linkUnderlineStyle.rawValue,
                    .foregroundColor: typography.linkColor
                ], range: NSRange(location: 0, length: replacement.length))
            }
        }
        transform(boldRegex) { _, replacement in
            replacement.enumerateAttributes(in: NSRange(location: 0, length: replacement.length)) { attributes, range, _ in
                guard attributes[literal] == nil else { return }
                let font = (attributes[.font] as? NSFont) ?? typography.bodyFont()
                replacement.addAttribute(.font, value: NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask), range: range)
            }
        }
        styled.removeAttribute(literal, range: NSRange(location: 0, length: styled.length))
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
    let typographyMode: MarkdownTypographyMode
    let textSizePreset: MarkdownReaderTextSizePreset
    let isDarkMode: Bool

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
                    Text(rendered)
                        .lineSpacing(typography.bodyLineSpacing)
                        .textSelection(.enabled)
                        .padding(.top, topSpacing(for: block))
                        .padding(.bottom, typography.quoteBlockSpacing)
                case .code(let code):
                    MarkdownCodeBlock(code: code, typography: typography, isDarkMode: isDarkMode)
                        .padding(.top, topSpacing(for: block))
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
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
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
