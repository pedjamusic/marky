import SwiftUI
import Foundation
import Combine
#if os(macOS)
import AppKit
#endif

#if os(macOS)
enum MarkdownTypographyMode: String, CaseIterable, Identifiable {
    case allSystem
    case serifHeadingsSystemBody
    case systemHeadingsSerifBody

    var id: String { rawValue }

    var title: String {
        switch self {
        case .allSystem:
            return "All System"
        case .serifHeadingsSystemBody:
            return "Serif Headings + System Body"
        case .systemHeadingsSerifBody:
            return "System Headings + Serif Body"
        }
    }
}

enum MarkdownRenderer {
    private enum FontFamily {
        case systemSans
        case literataSerif
    }

    private struct ModeProfile {
        let headingFamily: FontFamily
        let bodyFamily: FontFamily
        let bodyFontSize: CGFloat
        let bodyLineHeightMultiple: CGFloat
        let bodyParagraphSpacing: CGFloat
        let bodyTracking: CGFloat
        let paragraphBreakSpacingBefore: CGFloat

        let headingScales: [CGFloat]
        let headingLineHeights: [CGFloat]
        let headingSpacingBeforeMultipliers: [CGFloat]
        let headingSpacingAfterMultipliers: [CGFloat]
        let headingTracking: CGFloat

        let listIndent: CGFloat
        let listParagraphSpacing: CGFloat
        let listLineHeightMultiple: CGFloat
        let quoteLineHeightMultiple: CGFloat
        let quoteObliqueness: CGFloat
        let checkboxUncheckedSymbol: String
        let checkboxCheckedSymbol: String

        let codeFontScale: CGFloat
        let codeMinimumFontSize: CGFloat
        let codeBackgroundLightColor: NSColor
        let codeBackgroundDarkColor: NSColor
        let codeForegroundLightColor: NSColor
        let codeForegroundDarkColor: NSColor
        let codeBlockLineHeightMultiple: CGFloat
        let codeBlockParagraphSpacingBefore: CGFloat
        let codeBlockParagraphSpacingAfter: CGFloat
        let codeBlockHorizontalInset: CGFloat
        let linkColor: NSColor
        let linkUnderlineStyle: NSUnderlineStyle

        static func forMode(_ mode: MarkdownTypographyMode) -> Self {
            switch mode {
            case .allSystem:
                return baseProfile(
                    headingFamily: .systemSans,
                    bodyFamily: .systemSans,
                )
            case .serifHeadingsSystemBody:
                return baseProfile(
                    headingFamily: .literataSerif,
                    bodyFamily: .systemSans
                )
            case .systemHeadingsSerifBody:
                return baseProfile(
                    headingFamily: .systemSans,
                    bodyFamily: .literataSerif,
                    bodyFontSize: 17,
                    bodyLineHeightMultiple: 1.58
                )
            }
        }

        private static func baseProfile(
            headingFamily: FontFamily,
            bodyFamily: FontFamily,
            bodyFontSize: CGFloat = 16,
            bodyLineHeightMultiple: CGFloat = 1.45
        ) -> Self {
            Self(
                headingFamily: headingFamily,
                bodyFamily: bodyFamily,
                bodyFontSize: bodyFontSize,
                bodyLineHeightMultiple: bodyLineHeightMultiple,
                bodyParagraphSpacing: 0,
                bodyTracking: 0.12,
                paragraphBreakSpacingBefore: bodyFontSize * 0.85,
                headingScales: [1.90, 1.50, 1.25, 1.10, 1.00, 0.95],
                headingLineHeights: [1.12, 1.16, 1.20, 1.24, 1.26, 1.28],
                headingSpacingBeforeMultipliers: [2.20, 2.00, 1.70, 1.50, 1.35, 1.20],
                headingSpacingAfterMultipliers: [0.60, 0.50, 0.40, 0.35, 0.30, 0.28],
                headingTracking: -0.16,
                listIndent: bodyFontSize * 1.40,
                listParagraphSpacing: bodyFontSize * 0.30,
                listLineHeightMultiple: max(1.42, bodyLineHeightMultiple),
                quoteLineHeightMultiple: bodyLineHeightMultiple,
                quoteObliqueness: 0.06,
                checkboxUncheckedSymbol: "☐",
                checkboxCheckedSymbol: "☑",
                codeFontScale: 0.9,
                codeMinimumFontSize: 13,
                codeBackgroundLightColor: NSColor(srgbRed: 0.90, green: 0.90, blue: 0.93, alpha: 1.0),
                codeBackgroundDarkColor: NSColor(srgbRed: 0.20, green: 0.22, blue: 0.26, alpha: 1.0),
                codeForegroundLightColor: NSColor.labelColor,
                codeForegroundDarkColor: NSColor.labelColor,
                codeBlockLineHeightMultiple: 1.5,
                codeBlockParagraphSpacingBefore: bodyFontSize * 1.1,
                codeBlockParagraphSpacingAfter: bodyFontSize * 1.1,
                codeBlockHorizontalInset: 14,
                linkColor: NSColor.labelColor.withAlphaComponent(0.86),
                linkUnderlineStyle: .single
            )
        }
    }

    private struct Typography {
        private let profile: ModeProfile

        var bodyFontSize: CGFloat { profile.bodyFontSize }
        var bodyLineHeightMultiple: CGFloat { profile.bodyLineHeightMultiple }
        var bodyParagraphSpacing: CGFloat { profile.bodyParagraphSpacing }
        var bodyTracking: CGFloat { profile.bodyTracking }
        var paragraphBreakSpacingBefore: CGFloat { profile.paragraphBreakSpacingBefore }

        var headingScales: [CGFloat] { profile.headingScales }
        var headingLineHeights: [CGFloat] { profile.headingLineHeights }
        var headingTracking: CGFloat { profile.headingTracking }

        var listIndent: CGFloat { profile.listIndent }
        var listParagraphSpacing: CGFloat { profile.listParagraphSpacing }
        var listLineHeightMultiple: CGFloat { profile.listLineHeightMultiple }
        var quoteLineHeightMultiple: CGFloat { profile.quoteLineHeightMultiple }
        var quoteObliqueness: CGFloat { profile.quoteObliqueness }
        var checkboxUncheckedSymbol: String { profile.checkboxUncheckedSymbol }
        var checkboxCheckedSymbol: String { profile.checkboxCheckedSymbol }

        var codeFontScale: CGFloat { profile.codeFontScale }
        var codeMinimumFontSize: CGFloat { profile.codeMinimumFontSize }
        var codeBlockLineHeightMultiple: CGFloat { profile.codeBlockLineHeightMultiple }
        var codeBlockParagraphSpacingBefore: CGFloat { profile.codeBlockParagraphSpacingBefore }
        var codeBlockParagraphSpacingAfter: CGFloat { profile.codeBlockParagraphSpacingAfter }
        var codeBlockHorizontalInset: CGFloat { profile.codeBlockHorizontalInset }
        var linkColor: NSColor { profile.linkColor }
        var linkUnderlineStyle: NSUnderlineStyle { profile.linkUnderlineStyle }

        func codeBackgroundColor(isDarkMode: Bool) -> NSColor {
            isDarkMode ? profile.codeBackgroundDarkColor : profile.codeBackgroundLightColor
        }

        func codeForegroundColor(isDarkMode: Bool) -> NSColor {
            isDarkMode ? profile.codeForegroundDarkColor : profile.codeForegroundLightColor
        }

        init(mode: MarkdownTypographyMode) {
            self.profile = ModeProfile.forMode(mode)
        }

        func headingFont(for level: Int) -> NSFont {
            let clamped = min(max(level, 1), 6)
            let scale = headingScales[clamped - 1]
            let size = bodyFontSize * scale
            let weight: NSFont.Weight = clamped <= 2 ? .bold : .semibold
            return makeFont(family: profile.headingFamily, size: size, weight: weight)
        }

        func headingLineHeight(for level: Int) -> CGFloat {
            let clamped = min(max(level, 1), 6)
            return headingLineHeights[clamped - 1]
        }

        func headingSpacingBefore(for level: Int) -> CGFloat {
            let clamped = min(max(level, 1), 6)
            return bodyFontSize * profile.headingSpacingBeforeMultipliers[clamped - 1]
        }

        func headingSpacingAfter(for level: Int) -> CGFloat {
            let clamped = min(max(level, 1), 6)
            return bodyFontSize * profile.headingSpacingAfterMultipliers[clamped - 1]
        }

        func bodyFont() -> NSFont {
            makeFont(family: profile.bodyFamily, size: bodyFontSize, weight: .regular)
        }

        private func makeFont(family: FontFamily, size: CGFloat, weight: NSFont.Weight) -> NSFont {
            switch family {
            case .systemSans:
                return NSFont.systemFont(ofSize: size, weight: weight)
            case .literataSerif:
                return literataFont(size: size, weight: weight)
            }
        }

        private func literataFont(size: CGFloat, weight: NSFont.Weight) -> NSFont {
            let preferredPostScriptNames: [String]
            if weight >= .semibold {
                preferredPostScriptNames = ["Literata-SemiBold", "Literata-Bold", "Literata"]
            } else {
                preferredPostScriptNames = ["Literata-Regular", "Literata"]
            }

            for name in preferredPostScriptNames {
                if let font = NSFont(name: name, size: size) {
                    return font
                }
            }

            let base = NSFont.systemFont(ofSize: size, weight: weight)
            if
                let descriptor = base.fontDescriptor.withDesign(.serif),
                let serifFont = NSFont(descriptor: descriptor, size: size)
            {
                return serifFont
            }
            return base
        }
    }

    static func render(
        from text: String,
        mode: MarkdownTypographyMode = .allSystem,
        isDarkMode: Bool = false
    ) -> NSAttributedString {
        let typography = Typography(mode: mode)
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
            } else if content.hasPrefix("- ") || content.hasPrefix("* ") || content.hasPrefix("+ ") {
                isList = true
                let body = String(content.dropFirst(2))
                renderedLine = indent + "• " + body
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
        typography: Typography,
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
    @Published var rendered: AttributedString?
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
        rendered = nil
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
                let rendered = await MainActor.run {
                    AttributedString(MarkdownRenderer.render(from: text, mode: mode, isDarkMode: isDarkMode))
                }
                #else
                let rendered = try? AttributedString(markdown: text)
                #endif

                try Task.checkCancellation()
                await MainActor.run { [weak self] in
                    guard let self, generation == self.loadGeneration else { return }
                    self.rawText = text
                    self.rendered = rendered
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
        rendered = AttributedString(MarkdownRenderer.render(from: rawText, mode: mode, isDarkMode: isDarkMode))
        #else
        rendered = try? AttributedString(markdown: rawText)
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
        } else if let rendered = doc.rendered {
            ReaderScrollContainer {
                Text(rendered)
                    .textSelection(.enabled)
            }
        } else if !doc.rawText.isEmpty {
            ReaderScrollContainer {
                Text(doc.rawText)
                    .font(.system(.body, design: .monospaced))
                    .lineSpacing(8)
                    .kerning(0.15)
                    .textSelection(.enabled)
            }
        } else {
            Text("No content")
        }
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
