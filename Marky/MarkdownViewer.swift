import SwiftUI
import Foundation
import Combine
#if os(macOS)
import AppKit
#endif

final class MarkdownDoc: ObservableObject {
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
        var lineStyles: [(headingLevel: Int?, isList: Bool)] = []
        displayLines.reserveCapacity(lines.count)
        lineStyles.reserveCapacity(lines.count)

        for line in lines {
            let prefixCount = line.prefix(while: { $0 == " " || $0 == "\t" }).count
            let indent = String(line.prefix(prefixCount))
            let content = String(line.dropFirst(prefixCount))

            var renderedLine = line
            var headingLevelValue: Int?
            var isList = false

            if let level = headingLevel(in: content) {
                headingLevelValue = level
                let markerLength = level + 1 // leading '#' chars and following space
                let body = String(content.dropFirst(markerLength))
                renderedLine = indent + body
            } else if content.hasPrefix("- ") || content.hasPrefix("* ") || content.hasPrefix("+ ") {
                isList = true
                let body = String(content.dropFirst(2))
                renderedLine = indent + "• " + body
            }

            displayLines.append(renderedLine)
            lineStyles.append((headingLevel: headingLevelValue, isList: isList))
        }

        let display = displayLines.joined(separator: "\n")
        let styled = NSMutableAttributedString(string: display)
        let bodyFont = NSFont.systemFont(ofSize: 16, weight: .regular)
        let baseParagraph = NSMutableParagraphStyle()
        baseParagraph.lineHeightMultiple = 1.24
        baseParagraph.paragraphSpacing = 10
        styled.addAttributes([
            .font: bodyFont,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: baseParagraph
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

            if let level = style.headingLevel {
                switch level {
                case 1: font = NSFont.systemFont(ofSize: 34, weight: .bold)
                case 2: font = NSFont.systemFont(ofSize: 28, weight: .bold)
                case 3: font = NSFont.systemFont(ofSize: 23, weight: .semibold)
                case 4: font = NSFont.systemFont(ofSize: 20, weight: .semibold)
                default: font = NSFont.systemFont(ofSize: 18, weight: .semibold)
                }
                paragraph.paragraphSpacing = 14
            } else if style.isList {
                paragraph.firstLineHeadIndent = 18
                paragraph.headIndent = 18
                paragraph.paragraphSpacing = 6
            }

            styled.addAttribute(.font, value: font, range: lineRange)
            styled.addAttribute(.paragraphStyle, value: paragraph, range: lineRange)
        }

        applyInlineStyles(to: styled)
        return styled
    }

    private static func headingLevel(in line: String) -> Int? {
        guard line.hasPrefix("#") else { return nil }
        let hashes = line.prefix(while: { $0 == "#" }).count
        guard (1...6).contains(hashes), line.dropFirst(hashes).hasPrefix(" ") else { return nil }
        return hashes
    }

    private static func applyInlineStyles(to styled: NSMutableAttributedString) {
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
                attrs[.foregroundColor] = NSColor.linkColor
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
                attrs[.font] = NSFont.monospacedSystemFont(ofSize: max(13, currentFont.pointSize * 0.9), weight: .regular)
                attrs[.backgroundColor] = NSColor.secondaryLabelColor.withAlphaComponent(0.15)
                styled.replaceCharacters(in: match.range, with: NSAttributedString(string: text, attributes: attrs))
            }
        }
    }
}

struct MarkdownViewer: View {
    let url: URL
    @StateObject private var doc = MarkdownDoc()
    @State private var topFadeOpacity: Double = 0
    @State private var bottomFadeOpacity: Double = 0.88

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
                        attributed: rendered,
                        topFadeOpacity: $topFadeOpacity,
                        bottomFadeOpacity: $bottomFadeOpacity
                    )
                        .overlay {
                            ReaderEdgeFadeOverlay(topOpacity: topFadeOpacity, bottomOpacity: bottomFadeOpacity)
                        }
                    #else
                    ScrollView { Text(AttributedString(rendered)).textSelection(.enabled).padding() }
                    #endif
                } else if !doc.rawText.isEmpty {
                    ScrollView { Text(doc.rawText).font(.system(.body, design: .monospaced)).textSelection(.enabled).padding() }
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
        .navigationTitle("")
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
    @Binding var topFadeOpacity: Double
    @Binding var bottomFadeOpacity: Double

    final class Coordinator: NSObject {
        var observer: NSObjectProtocol?
        var topFadeOpacity: Binding<Double>
        var bottomFadeOpacity: Binding<Double>

        init(topFadeOpacity: Binding<Double>, bottomFadeOpacity: Binding<Double>) {
            self.topFadeOpacity = topFadeOpacity
            self.bottomFadeOpacity = bottomFadeOpacity
        }

        deinit {
            if let observer {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        func updateFade(for scrollView: NSScrollView) {
            let offsetY = scrollView.contentView.bounds.origin.y
            let visibleHeight = scrollView.contentView.bounds.height
            let contentHeight = scrollView.documentView?.bounds.height ?? 0
            let maxOffset = max(0, contentHeight - visibleHeight)

            let edgeDistance: CGFloat = 120
            let topProgress = min(max(offsetY / edgeDistance, 0), 1)
            let bottomDistance = max(0, maxOffset - offsetY)
            let bottomProgress = min(max(bottomDistance / edgeDistance, 0), 1)

            topFadeOpacity.wrappedValue = 0.2 + Double(topProgress) * 0.8
            bottomFadeOpacity.wrappedValue = 0.2 + Double(bottomProgress) * 0.8
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(topFadeOpacity: $topFadeOpacity, bottomFadeOpacity: $bottomFadeOpacity)
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
        textView.textContainerInset = NSSize(width: 70, height: 42)
        textView.allowsUndo = false
        textView.isRichText = true
        textView.importsGraphics = false
        textView.usesFindPanel = true
        textView.isAutomaticLinkDetectionEnabled = true
        textView.linkTextAttributes = [
            .foregroundColor: NSColor.linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textStorage?.setAttributedString(attributed)

        scrollView.documentView = textView
        scrollView.contentView.postsBoundsChangedNotifications = true

        context.coordinator.observer = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { _ in
            context.coordinator.updateFade(for: scrollView)
        }

        DispatchQueue.main.async {
            context.coordinator.updateFade(for: scrollView)
        }
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        textView.textStorage?.setAttributedString(attributed)
        DispatchQueue.main.async {
            context.coordinator.updateFade(for: nsView)
        }
    }
}
#endif

#Preview {
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Preview.md")
    try? "# Hello\n\nThis is a **Markdown** preview.".data(using: .utf8)?.write(to: tmp)
    return NavigationStack { MarkdownViewer(url: tmp) }
}
