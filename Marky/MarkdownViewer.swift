import SwiftUI
import Foundation
import Combine
#if os(macOS)
import AppKit
#endif

#if os(macOS)
enum MarkdownRenderer {
    static func render(
        from text: String,
        mode: MarkdownTypographyMode = .allSystem,
        isDarkMode: Bool = false
    ) -> NSAttributedString {
        let typography = MarkdownTypography(mode: mode)
        let source = text.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = source.components(separatedBy: "\n")
        var displayLines: [String] = []
        var lineStyles: [(headingLevel: Int?, isList: Bool, isQuote: Bool, isCodeBlock: Bool, startsAfterBlankLine: Bool)] = []
        displayLines.reserveCapacity(lines.count)
        lineStyles.reserveCapacity(lines.count)
        var pendingParagraphBreak = false
        var inCodeFence = false

        for line in lines {
            let prefixCount = line.prefix(while: { $0 == " " || $0 == "\t" }).count
            let indent = String(line.prefix(prefixCount))
            let content = String(line.dropFirst(prefixCount))
            let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmedContent.hasPrefix("```") {
                inCodeFence.toggle()
                pendingParagraphBreak = true
                continue
            }

            if inCodeFence {
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

            if let level = headingLevel(in: content) {
                headingLevelValue = level
                let markerLength = level + 1
                let body = String(content.dropFirst(markerLength))
                renderedLine = indent + body
            } else if let taskItem = taskListItem(in: content) {
                isList = true
                let checkbox = taskItem.isChecked ? typography.checkboxCheckedSymbol : typography.checkboxUncheckedSymbol
                renderedLine = indent + checkbox + " " + taskItem.body
            } else if content.hasPrefix("- ")
                || content.hasPrefix("* ")
                || content.hasPrefix("+ ")
                || content.hasPrefix("• ")
            {
                isList = true
                if content.hasPrefix("• ") {
                    renderedLine = indent + content
                } else {
                    let body = String(content.dropFirst(2))
                    renderedLine = indent + "• " + body
                }
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

    private static func headingLevel(in line: String) -> Int? {
        guard line.hasPrefix("#") else { return nil }
        let hashes = line.prefix(while: { $0 == "#" }).count
        guard (1...6).contains(hashes), line.dropFirst(hashes).hasPrefix(" ") else { return nil }
        return hashes
    }

    private static func taskListItem(in line: String) -> (isChecked: Bool, body: String)? {
        let patterns: [(prefix: String, checked: Bool)] = [
            ("- [ ] ", false), ("* [ ] ", false), ("+ [ ] ", false),
            ("- [x] ", true), ("* [x] ", true), ("+ [x] ", true),
            ("- [X] ", true), ("* [X] ", true), ("+ [X] ", true)
        ]

        for pattern in patterns where line.hasPrefix(pattern.prefix) {
            let body = String(line.dropFirst(pattern.prefix.count))
            return (pattern.checked, body)
        }
        return nil
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

    private static func intersectsProtectedRange(_ range: NSRange, protectedRanges: [NSRange]) -> Bool {
        for protectedRange in protectedRanges where NSIntersectionRange(range, protectedRange).length > 0 {
            return true
        }
        return false
    }

    private static func applyInlineStyles(
        to styled: NSMutableAttributedString,
        typography: MarkdownTypography,
        protectedRanges: [NSRange],
        isDarkMode: Bool
    ) {
        let boldRegex = try? NSRegularExpression(pattern: #"\*\*([^*\n]+)\*\*"#)
        let codeRegex = try? NSRegularExpression(pattern: #"`([^`\n]+)`"#)
        let linkRegex = try? NSRegularExpression(pattern: #"\[([^\]]+)\]\(([^)\s]+)\)"#)

        if let linkRegex {
            let ns = styled.string as NSString
            let matches = linkRegex.matches(in: styled.string, range: NSRange(location: 0, length: ns.length))
            for match in matches.reversed() {
                if intersectsProtectedRange(match.range, protectedRanges: protectedRanges) {
                    continue
                }
                guard match.numberOfRanges >= 3 else { continue }
                let textRange = match.range(at: 1)
                let urlRange = match.range(at: 2)
                let text = ns.substring(with: textRange)
                let urlString = ns.substring(with: urlRange)
                var attrs = styled.attributes(at: match.range.location, effectiveRange: nil)
                if let url = URL(string: urlString) {
                    attrs[.link] = url
                    attrs[.underlineStyle] = typography.linkUnderlineStyle.rawValue
                    attrs[.foregroundColor] = typography.linkColor
                }
                styled.replaceCharacters(in: match.range, with: NSAttributedString(string: text, attributes: attrs))
            }
        }

        if let boldRegex {
            let ns = styled.string as NSString
            let matches = boldRegex.matches(in: styled.string, range: NSRange(location: 0, length: ns.length))
            for match in matches.reversed() {
                if intersectsProtectedRange(match.range, protectedRanges: protectedRanges) {
                    continue
                }
                guard match.numberOfRanges >= 2 else { continue }
                let textRange = match.range(at: 1)
                let text = ns.substring(with: textRange)
                var attrs = styled.attributes(at: match.range.location, effectiveRange: nil)
                let currentFont = (attrs[.font] as? NSFont) ?? NSFont.systemFont(ofSize: 16)
                attrs[.font] = NSFont.systemFont(ofSize: currentFont.pointSize, weight: .semibold)
                styled.replaceCharacters(in: match.range, with: NSAttributedString(string: text, attributes: attrs))
            }
        }

        if let codeRegex {
            let ns = styled.string as NSString
            let matches = codeRegex.matches(in: styled.string, range: NSRange(location: 0, length: ns.length))
            for match in matches.reversed() {
                if intersectsProtectedRange(match.range, protectedRanges: protectedRanges) {
                    continue
                }
                guard match.numberOfRanges >= 2 else { continue }
                let textRange = match.range(at: 1)
                let text = ns.substring(with: textRange)
                var attrs = styled.attributes(at: match.range.location, effectiveRange: nil)
                let currentFont = (attrs[.font] as? NSFont) ?? NSFont.systemFont(ofSize: 16)
                attrs[.font] = NSFont.monospacedSystemFont(
                    ofSize: max(typography.codeMinimumFontSize, currentFont.pointSize * typography.codeFontScale),
                    weight: .regular
                )
                attrs[.foregroundColor] = typography.codeForegroundColor(isDarkMode: isDarkMode)
                attrs[.backgroundColor] = typography.codeBackgroundColor(isDarkMode: isDarkMode)
                styled.replaceCharacters(in: match.range, with: NSAttributedString(string: text, attributes: attrs))
            }
        }
    }
}
#endif

final class MarkdownDoc: ObservableObject {
    @Published var blocks: [MarkdownRenderedBlock] = []
    @Published var rawText: String = ""
    @Published var isLoading: Bool = false
    @Published var error: String?

    private var loadTask: Task<Void, Never>?
    private var loadGeneration: UInt64 = 0

    deinit {
        loadTask?.cancel()
    }

    func load(
        from url: URL,
        mode: MarkdownTypographyMode = .allSystem,
        isDarkMode: Bool = false
    ) {
        loadTask?.cancel()
        loadGeneration &+= 1
        let generation = loadGeneration

        isLoading = true
        error = nil
        blocks = []
        rawText = ""

        loadTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let needsAccess = url.startAccessingSecurityScopedResource()
            defer {
                if needsAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let data = try Data(contentsOf: url)
                try Task.checkCancellation()

                let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16)
                guard let text else {
                    await MainActor.run { [weak self] in
                        guard let self, generation == self.loadGeneration else { return }
                        self.isLoading = false
                        self.error = "Unable to decode file as UTF-8/UTF-16 text"
                        self.loadTask = nil
                    }
                    return
                }

                #if os(macOS)
                let blocks = await MainActor.run {
                    MarkdownContentBlocks.render(from: text, mode: mode, isDarkMode: isDarkMode)
                }
                #else
                let rendered = try? AttributedString(markdown: text)
                #endif

                try Task.checkCancellation()
                await MainActor.run { [weak self] in
                    guard let self, generation == self.loadGeneration else { return }
                    self.rawText = text
                    #if os(macOS)
                    self.blocks = blocks
                    #else
                    if let rendered {
                        self.blocks = [MarkdownRenderedBlock(id: 0, kind: .markdown(rendered))]
                    } else {
                        self.blocks = []
                    }
                    #endif
                    self.isLoading = false
                    self.loadTask = nil
                }
            } catch is CancellationError {
                await MainActor.run { [weak self] in
                    guard let self, generation == self.loadGeneration else { return }
                    self.isLoading = false
                    self.loadTask = nil
                }
            } catch {
                await MainActor.run { [weak self] in
                    guard let self, generation == self.loadGeneration else { return }
                    self.isLoading = false
                    self.error = error.localizedDescription
                    self.loadTask = nil
                }
            }
        }
    }

    @MainActor
    func rerenderFromCachedText(mode: MarkdownTypographyMode, isDarkMode: Bool) {
        guard !rawText.isEmpty else { return }
        #if os(macOS)
        blocks = MarkdownContentBlocks.render(from: rawText, mode: mode, isDarkMode: isDarkMode)
        #else
        if let rendered = try? AttributedString(markdown: rawText) {
            blocks = [MarkdownRenderedBlock(id: 0, kind: .markdown(rendered))]
        } else {
            blocks = []
        }
        #endif
    }
}

private enum ReaderLayout {
    static let maxReadableWidth: CGFloat = 700
    static let horizontalPadding: CGFloat = 24
    static let verticalPadding: CGFloat = 42
}

struct MarkdownViewer: View {
    let url: URL
    @StateObject private var doc = MarkdownDoc()
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(AppPreferenceKeys.markdownTypographyMode)
    private var typographyModeRawValue = MarkdownTypographyMode.allSystem.rawValue
    @AppStorage(AppPreferenceKeys.appearanceMode)
    private var appearanceModeRawValue = AppAppearanceMode.system.rawValue

    private var typographyMode: MarkdownTypographyMode {
        MarkdownTypographyMode(rawValue: typographyModeRawValue) ?? .allSystem
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .textBackgroundColor).opacity(0.92)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            content
        }
        .task(id: url) {
            doc.load(from: url, mode: typographyMode, isDarkMode: colorScheme == .dark)
        }
        .onChange(of: typographyModeRawValue) { _ in
            doc.rerenderFromCachedText(mode: typographyMode, isDarkMode: colorScheme == .dark)
        }
        .onChange(of: appearanceModeRawValue) { _ in
            doc.rerenderFromCachedText(mode: typographyMode, isDarkMode: colorScheme == .dark)
        }
        .onChange(of: colorScheme) { newScheme in
            doc.rerenderFromCachedText(mode: typographyMode, isDarkMode: newScheme == .dark)
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
                    isDarkMode: colorScheme == .dark
                )
            }
        } else {
            Text("No content")
        }
    }
}

private struct MarkdownDocumentBlocks: View {
    let blocks: [MarkdownRenderedBlock]
    let typographyMode: MarkdownTypographyMode
    let isDarkMode: Bool

    private var typography: MarkdownTypography {
        MarkdownTypography(mode: typographyMode)
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
                .padding(.leading, CGFloat(item.nestingLevel) * typography.listIndent)
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
    }
}

#Preview {
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Preview.md")
    try? "# Hello\n\nThis is a **Markdown** preview.".data(using: .utf8)?.write(to: tmp)
    return NavigationStack { MarkdownViewer(url: tmp) }
}
