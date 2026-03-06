import SwiftUI
import Foundation
import Combine
#if os(macOS)
import AppKit
#endif

#if os(macOS)
enum MarkdownRenderer {
    private struct Typography {
        let bodyFontSize: CGFloat = 16
        let bodyLineHeightMultiple: CGFloat = 1.5
        let bodyParagraphSpacing: CGFloat = 0
        let bodyTracking: CGFloat = 0.15
        let paragraphBreakSpacingBefore: CGFloat = 8

        let headingScales: [CGFloat] = [1.72, 1.48, 1.30, 1.18, 1.08, 1.0]
        let headingLineHeights: [CGFloat] = [1.12, 1.15, 1.18, 1.22, 1.24, 1.26]
        let headingParagraphSpacingBefore: CGFloat = 26
        let headingParagraphSpacing: CGFloat = 6
        let headingTracking: CGFloat = -0.08

        let listIndent: CGFloat = 18
        let listParagraphSpacing: CGFloat = 4
        let listLineHeightMultiple: CGFloat = 1.42
        let checkboxUncheckedSymbol: String = "☐"
        let checkboxCheckedSymbol: String = "☑"

        let codeFontScale: CGFloat = 0.9
        let codeMinimumFontSize: CGFloat = 13
        let codeBackgroundOpacity: CGFloat = 0.18
        let codeForegroundColor: NSColor = .labelColor

        func headingFont(for level: Int) -> NSFont {
            let clamped = min(max(level, 1), 6)
            let scale = headingScales[clamped - 1]
            let size = bodyFontSize * scale
            let weight: NSFont.Weight = clamped <= 2 ? .bold : .semibold
            return NSFont.systemFont(ofSize: size, weight: weight)
        }

        func headingLineHeight(for level: Int) -> CGFloat {
            let clamped = min(max(level, 1), 6)
            return headingLineHeights[clamped - 1]
        }
    }

    private static let typography = Typography()

    static func render(from text: String) -> NSAttributedString {
        let source = text.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = source.components(separatedBy: "\n")
        var displayLines: [String] = []
        var lineStyles: [(headingLevel: Int?, isList: Bool, isQuote: Bool, startsAfterBlankLine: Bool)] = []
        displayLines.reserveCapacity(lines.count)
        lineStyles.reserveCapacity(lines.count)
        var pendingParagraphBreak = false

        for line in lines {
            let prefixCount = line.prefix(while: { $0 == " " || $0 == "\t" }).count
            let indent = String(line.prefix(prefixCount))
            let content = String(line.dropFirst(prefixCount))
            let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)

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
                startsAfterBlankLine: pendingParagraphBreak
            ))
            pendingParagraphBreak = false
        }

        let display = displayLines.joined(separator: "\n")
        let styled = NSMutableAttributedString(string: display)
        let bodyFont = NSFont.systemFont(ofSize: typography.bodyFontSize, weight: .regular)
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

            if let level = style.headingLevel {
                font = typography.headingFont(for: level)
                paragraph.lineHeightMultiple = typography.headingLineHeight(for: level)
                if index > 0 {
                    paragraph.paragraphSpacingBefore = max(
                        paragraph.paragraphSpacingBefore,
                        typography.headingParagraphSpacingBefore
                    )
                }
                paragraph.paragraphSpacing = typography.headingParagraphSpacing
                styled.addAttribute(.kern, value: typography.headingTracking, range: lineRange)
            } else if style.isList {
                paragraph.firstLineHeadIndent = typography.listIndent
                paragraph.headIndent = typography.listIndent
                paragraph.paragraphSpacing = typography.listParagraphSpacing
                paragraph.lineHeightMultiple = typography.listLineHeightMultiple
            } else if style.isQuote {
                paragraph.firstLineHeadIndent = typography.listIndent
                paragraph.headIndent = typography.listIndent
                paragraph.paragraphSpacing = typography.listParagraphSpacing
                paragraph.lineHeightMultiple = 1.45
                styled.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: lineRange)
                styled.addAttribute(.obliqueness, value: 0.08, range: lineRange)
            }

            styled.addAttribute(.font, value: font, range: lineRange)
            styled.addAttribute(.paragraphStyle, value: paragraph, range: lineRange)
        }

        applyInlineStyles(to: styled, typography: typography)
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

    private static func applyInlineStyles(to styled: NSMutableAttributedString, typography: Typography) {
        let boldRegex = try? NSRegularExpression(pattern: #"\*\*([^*\n]+)\*\*"#)
        let codeRegex = try? NSRegularExpression(pattern: #"`([^`\n]+)`"#)
        let linkRegex = try? NSRegularExpression(pattern: #"\[([^\]]+)\]\(([^)\s]+)\)"#)

        if let linkRegex {
            let ns = styled.string as NSString
            let matches = linkRegex.matches(in: styled.string, range: NSRange(location: 0, length: ns.length))
            for match in matches.reversed() {
                guard match.numberOfRanges >= 3 else { continue }
                let textRange = match.range(at: 1)
                let urlRange = match.range(at: 2)
                let text = ns.substring(with: textRange)
                let urlString = ns.substring(with: urlRange)
                var attrs = styled.attributes(at: match.range.location, effectiveRange: nil)
                if let url = URL(string: urlString) {
                    attrs[.link] = url
                    attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
                    attrs[.foregroundColor] = MarkyTheme.nsBlue
                }
                styled.replaceCharacters(in: match.range, with: NSAttributedString(string: text, attributes: attrs))
            }
        }

        if let boldRegex {
            let ns = styled.string as NSString
            let matches = boldRegex.matches(in: styled.string, range: NSRange(location: 0, length: ns.length))
            for match in matches.reversed() {
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
                guard match.numberOfRanges >= 2 else { continue }
                let textRange = match.range(at: 1)
                let text = ns.substring(with: textRange)
                var attrs = styled.attributes(at: match.range.location, effectiveRange: nil)
                let currentFont = (attrs[.font] as? NSFont) ?? NSFont.systemFont(ofSize: 16)
                attrs[.font] = NSFont.monospacedSystemFont(
                    ofSize: max(typography.codeMinimumFontSize, currentFont.pointSize * typography.codeFontScale),
                    weight: .regular
                )
                attrs[.foregroundColor] = typography.codeForegroundColor
                attrs[.backgroundColor] = NSColor.secondaryLabelColor.withAlphaComponent(typography.codeBackgroundOpacity)
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

    func load(from url: URL) {
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
                    AttributedString(MarkdownRenderer.render(from: text))
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
}

private enum ReaderLayout {
    static let maxReadableWidth: CGFloat = 700
    static let horizontalPadding: CGFloat = 24
    static let verticalPadding: CGFloat = 42
}

struct MarkdownViewer: View {
    let url: URL
    @StateObject private var doc = MarkdownDoc()

    private let topFadeOpacity: Double = 0.9
    private let bottomFadeOpacity: Double = 0.96

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
            doc.load(from: url)
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
            .overlay {
                ReaderEdgeFadeOverlay(topOpacity: topFadeOpacity, bottomOpacity: bottomFadeOpacity)
            }
        } else if !doc.rawText.isEmpty {
            ReaderScrollContainer {
                Text(doc.rawText)
                    .font(.system(.body, design: .monospaced))
                    .lineSpacing(8)
                    .kerning(0.15)
                    .textSelection(.enabled)
            }
            .overlay {
                ReaderEdgeFadeOverlay(topOpacity: topFadeOpacity, bottomOpacity: bottomFadeOpacity)
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

private struct ReaderEdgeFadeOverlay: View {
    let topOpacity: Double
    let bottomOpacity: Double

    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor).opacity(topOpacity),
                    Color(nsColor: .windowBackgroundColor).opacity(0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 72)

            Spacer(minLength: 0)

            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor).opacity(0),
                    Color(nsColor: .windowBackgroundColor).opacity(bottomOpacity)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 76)
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Preview.md")
    try? "# Hello\n\nThis is a **Markdown** preview.".data(using: .utf8)?.write(to: tmp)
    return NavigationStack { MarkdownViewer(url: tmp) }
}
