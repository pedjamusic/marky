import SwiftUI
import Foundation
import Combine
#if os(macOS)
import AppKit
#endif

final class MarkdownDoc: ObservableObject {
    private struct Typography {
        let bodyFontSize: CGFloat = 16
        let bodyLineHeightMultiple: CGFloat = 1.5
        // Keep body text tight; markdown blank lines provide paragraph breaks.
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

    @Published var rendered: NSAttributedString?
    @Published var rawText: String = ""
    @Published var isLoading: Bool = false
    @Published var error: String?

    func load(from url: URL) {
        isLoading = true
        error = nil
        rendered = nil
        rawText = ""

        Task.detached { [weak self] in
            guard let self else { return }
            let needsAccess = url.startAccessingSecurityScopedResource()
            defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                var text = String(data: data, encoding: .utf8)
                if text == nil {
                    text = String(data: data, encoding: .utf16)
                }
                guard let text else {
                    await MainActor.run { [weak self] in
                        self?.isLoading = false
                        self?.error = "Unable to decode file as UTF-8/UTF-16 text"
                    }
                    return
                }

                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.rendered = Self.makeStyledMarkdown(from: text)
                    self.rawText = text
                    self.isLoading = false
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.isLoading = false
                    self?.error = error.localizedDescription
                }
            }
        }
    }

    @MainActor
    private static func makeStyledMarkdown(from text: String) -> NSAttributedString {
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
                let markerLength = level + 1 // leading '#' chars and following space
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
        // Keep body text around 150% leading for easier long-form reading.
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
            location += lineLength + 1 // account for newline separator
            guard lineLength > 0 else { continue }

            var font = bodyFont
            let paragraph = baseParagraph.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
            let style = lineStyles[index]
            paragraph.paragraphSpacingBefore = style.startsAfterBlankLine ? typography.paragraphBreakSpacingBefore : 0

            if let level = style.headingLevel {
                font = typography.headingFont(for: level)
                paragraph.lineHeightMultiple = typography.headingLineHeight(for: level)
                paragraph.paragraphSpacingBefore = max(
                    paragraph.paragraphSpacingBefore,
                    typography.headingParagraphSpacingBefore
                )
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
                let url = URL(string: urlString)
                var attrs = styled.attributes(at: match.range.location, effectiveRange: nil)
                attrs[.link] = url
                attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
                attrs[.foregroundColor] = MarkyTheme.nsBlue
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

            Group {
                if doc.isLoading {
                    ProgressView("Loading…")
                } else if let rendered = doc.rendered {
                    #if os(macOS)
                    MarkdownTextView(
                        attributed: rendered
                    )
                        .overlay {
                            ReaderEdgeFadeOverlay(topOpacity: topFadeOpacity, bottomOpacity: bottomFadeOpacity)
                        }
                    #else
                    ScrollView { Text(AttributedString(rendered)).textSelection(.enabled).padding() }
                    #endif
                } else if !doc.rawText.isEmpty {
                    ScrollView {
                        Text(doc.rawText)
                            .font(.system(.body, design: .monospaced))
                            .lineSpacing(8)
                            .kerning(0.15)
                            .textSelection(.enabled)
                            .frame(maxWidth: 700, alignment: .leading)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 42)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                        .overlay {
                            ReaderEdgeFadeOverlay(topOpacity: topFadeOpacity, bottomOpacity: bottomFadeOpacity)
                        }
                } else if let error = doc.error {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle").font(.largeTitle)
                        Text(error)
                    }.padding()
                } else {
                    Text("No content")
                }
            }
        }
        .task(id: url) {
            doc.load(from: url)
        }
    }
}

#if os(macOS)
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

private struct MarkdownTextView: NSViewRepresentable {
    let attributed: NSAttributedString
    private static let desiredMeasureCharacters: CGFloat = 65
    private static let maxReadableWidth: CGFloat = 700
    private static let minimumHorizontalInset: CGFloat = 24

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.automaticallyAdjustsContentInsets = true

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 24, height: 42)
        textView.allowsUndo = false
        textView.isRichText = true
        textView.importsGraphics = false
        textView.usesFindPanel = true
        textView.isAutomaticLinkDetectionEnabled = true
        textView.linkTextAttributes = [
            .foregroundColor: MarkyTheme.nsBlue,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: 640, height: CGFloat.greatestFiniteMagnitude)
        textView.autoresizingMask = [.width]
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textStorage?.setAttributedString(attributed)

        scrollView.documentView = textView
        context.coordinator.startObserving(scrollView: scrollView, textView: textView) { observedScrollView, observedTextView in
            Self.applyReadableMeasure(in: observedScrollView, textView: observedTextView)
        }
        Self.applyReadableMeasure(in: scrollView, textView: textView)
        DispatchQueue.main.async {
            Self.applyReadableMeasure(in: scrollView, textView: textView)
        }
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        textView.textStorage?.setAttributedString(attributed)
        Self.applyReadableMeasure(in: nsView, textView: textView)
    }

    private static func applyReadableMeasure(in scrollView: NSScrollView, textView: NSTextView) {
        guard let container = textView.textContainer else { return }
        let bodyFont = textView.font ?? NSFont.systemFont(ofSize: 16, weight: .regular)
        let availableWidth = max(0, scrollView.contentSize.width)
        let averageCharacterWidth = ("abcdefghijklmnopqrstuvwxyz" as NSString)
            .size(withAttributes: [.font: bodyFont]).width / 26
        let desiredMeasureWidth = averageCharacterWidth * desiredMeasureCharacters
        let cappedMeasureWidth = min(maxReadableWidth, desiredMeasureWidth)
        let maxFittingWidth = max(160, availableWidth - (minimumHorizontalInset * 2))
        let usedColumnWidth = min(cappedMeasureWidth, maxFittingWidth)
        let inset = max(0, (availableWidth - usedColumnWidth) / 2)

        textView.textContainerInset = NSSize(width: inset, height: 42)
        container.widthTracksTextView = false
        container.containerSize = NSSize(width: usedColumnWidth, height: CGFloat.greatestFiniteMagnitude)
    }

    final class Coordinator {
        private var observers: [NSObjectProtocol] = []

        deinit {
            for observer in observers {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        func startObserving(
            scrollView: NSScrollView,
            textView: NSTextView,
            onChange: @escaping (NSScrollView, NSTextView) -> Void
        ) {
            scrollView.contentView.postsBoundsChangedNotifications = true
            scrollView.contentView.postsFrameChangedNotifications = true
            scrollView.postsFrameChangedNotifications = true

            for observer in observers {
                NotificationCenter.default.removeObserver(observer)
            }
            observers.removeAll()

            let boundsObserver = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: scrollView.contentView,
                queue: .main
            ) { [weak scrollView, weak textView] _ in
                guard let scrollView, let textView else { return }
                onChange(scrollView, textView)
            }

            let contentFrameObserver = NotificationCenter.default.addObserver(
                forName: NSView.frameDidChangeNotification,
                object: scrollView.contentView,
                queue: .main
            ) { [weak scrollView, weak textView] _ in
                guard let scrollView, let textView else { return }
                onChange(scrollView, textView)
            }

            let scrollFrameObserver = NotificationCenter.default.addObserver(
                forName: NSView.frameDidChangeNotification,
                object: scrollView,
                queue: .main
            ) { [weak scrollView, weak textView] _ in
                guard let scrollView, let textView else { return }
                onChange(scrollView, textView)
            }

            observers = [boundsObserver, contentFrameObserver, scrollFrameObserver]
        }
    }
}
#endif

#Preview {
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Preview.md")
    try? "# Hello\n\nThis is a **Markdown** preview.".data(using: .utf8)?.write(to: tmp)
    return NavigationStack { MarkdownViewer(url: tmp) }
}
