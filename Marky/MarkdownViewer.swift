import SwiftUI
import Foundation
import Combine
#if os(macOS)
import AppKit
#endif

#if os(macOS)
enum MarkdownRenderer {
    static func renderInline(
        from runs: [CoreMarkdownDocument.InlineRun],
        mode: MarkdownTypographyMode = .allSystem,
        textSizePreset: MarkdownReaderTextSizePreset = .default,
        isDarkMode: Bool = false,
        headingLevel: Int? = nil,
        isTableHeader: Bool = false
    ) -> NSAttributedString {
        let style = InlineStyle(mode: mode, textSizePreset: textSizePreset, isDarkMode: isDarkMode,
                                headingLevel: headingLevel, isTableHeader: isTableHeader)
        let text = runs.map(\.text).joined()
        let result = style.attributedText(text)
        var characters = text.makeIterator()
        var nextCharacterLength = characters.next()?.utf16.count ?? 0
        var runEnd = 0
        var characterEnd = 0
        for run in runs {
            runEnd += run.text.utf16.count
            let start = characterEnd
            // The reader's character view assigns a split grapheme to the run containing its end.
            while nextCharacterLength > 0, nextCharacterLength <= runEnd - characterEnd {
                characterEnd += nextCharacterLength
                nextCharacterLength = characters.next()?.utf16.count ?? 0
            }
            let range = NSRange(location: start, length: characterEnd - start)
            if let destination = run.linkDestination, !destination.isEmpty, let link = URL(string: destination) {
                style.applyLink(link, to: result, range: range)
            }
            // The reader's formatted link labels use the code foreground where the label contains code.
            style.apply(run.intent, to: result, range: range)
        }
        return result
    }

    private struct InlineStyle {
        let typography: MarkdownTypography
        let isDarkMode: Bool
        let baseFont: NSFont
        let tracking: CGFloat
        let lineHeightMultiple: CGFloat

        init(
            mode: MarkdownTypographyMode,
            textSizePreset: MarkdownReaderTextSizePreset,
            isDarkMode: Bool,
            headingLevel: Int?,
            isTableHeader: Bool
        ) {
            let typography = MarkdownTypography(mode: mode, textSizePreset: textSizePreset)
            self.typography = typography
            self.isDarkMode = isDarkMode
            if let level = headingLevel {
                baseFont = typography.headingFont(for: level)
                tracking = typography.headingTracking
                lineHeightMultiple = typography.headingLineHeight(for: level)
            } else {
                let body = typography.bodyFont()
                baseFont = isTableHeader ? NSFontManager.shared.convert(body, toHaveTrait: .boldFontMask) : body
                tracking = typography.bodyTracking
                lineHeightMultiple = typography.bodyLineHeightMultiple
            }
        }

        func attributedText(_ text: String) -> NSMutableAttributedString {
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineHeightMultiple = lineHeightMultiple
            paragraph.paragraphSpacing = 0
            return NSMutableAttributedString(string: text, attributes: [
                .font: baseFont,
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraph,
                .kern: tracking
            ])
        }

        func apply(
            _ intent: InlinePresentationIntent,
            to result: NSMutableAttributedString,
            range: NSRange
        ) {
            guard range.length > 0, !intent.isEmpty else { return }
            MarkdownRenderer.applyPresentationIntent(
                intent, to: result, range: range, baseFont: baseFont, typography: typography, isDarkMode: isDarkMode
            )
        }

        func applyLink(_ link: URL, to result: NSMutableAttributedString, range: NSRange) {
            guard range.length > 0 else { return }
            result.addAttributes([
                .link: link,
                .underlineStyle: typography.linkUnderlineStyle.rawValue,
                .foregroundColor: typography.linkColor
            ], range: range)
        }
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
}
#endif

private enum MarkdownDocumentLoadError: LocalizedError {
    case unsupportedTextEncoding
    case parseFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedTextEncoding:
            return String(localized: "Unable to decode file as UTF-8/UTF-16 text")
        case .parseFailed:
            return String(localized: "Unable to read this Markdown document")
        }
    }
}

@MainActor
final class MarkdownDoc: ObservableObject {
    @Published var blocks: [MarkdownRenderedBlock] = []
    @Published var isLoading: Bool = false
    @Published var error: String?

    private var preparedDocument: CoreMarkdownDocument?
    private let readText: @Sendable (URL) async throws -> String
    private var loadGeneration: UInt64 = 0
    private var mode: MarkdownTypographyMode = .allSystem
    private var textSizePreset: MarkdownReaderTextSizePreset = .default
    private var isDarkMode = false

    init(
        readText: @escaping @Sendable (URL) async throws -> String = MarkdownDoc.readDocument
    ) {
        self.readText = readText
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
        preparedDocument = nil

        do {
            let prepared = try await Self.prepareDocument(from: url, readText: readText)
            try Task.checkCancellation()
            guard generation == loadGeneration else { return }
            preparedDocument = prepared
            rerenderFromPreparedBlocks(mode: self.mode, textSizePreset: self.textSizePreset, isDarkMode: self.isDarkMode)
            isLoading = false
        } catch is CancellationError {
            guard generation == loadGeneration else { return }
            isLoading = false
        } catch {
            guard generation == loadGeneration else { return }
            isLoading = false
            guard !Task.isCancelled else { return }
            self.error = error is CoreMarkdownParser.ParseError
                ? MarkdownDocumentLoadError.parseFailed.localizedDescription
                : error.localizedDescription
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
        guard let preparedDocument else { return }
        #if os(macOS)
        blocks = MarkdownContentBlocks.render(
            coreDocument: preparedDocument, mode: mode, textSizePreset: textSizePreset, isDarkMode: isDarkMode
        )
        #else
        blocks = []
        #endif
    }

    @concurrent
    private static func prepareDocument(
        from url: URL,
        readText: @Sendable (URL) async throws -> String
    ) async throws -> CoreMarkdownDocument {
        let text = try await readText(url)
        return try await CoreMarkdownParser.parse(text)
    }

    @concurrent
    private static func readDocument(from url: URL) async throws -> String {
        try Task.checkCancellation()
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
        return text
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
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(blocks) { block in
                switch block.kind {
                case .heading(let level, let rendered):
                    MarkdownLinkText(text: rendered)
                        .padding(.top, topSpacing(for: block))
                        .padding(.bottom, typography.headingSpacingAfter(for: level))
                case .paragraph(let rendered):
                    MarkdownLinkText(text: rendered, lineSpacing: typography.bodyLineSpacing)
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

private struct MarkdownLinkText: View {
    let text: AttributedString
    var lineSpacing: CGFloat = 0

    @State private var pointer: CGPoint?
    @State private var linkBounds: [LinkBounds] = []

    private struct LinkID: TextAttribute {
        let index: Int
    }

    private struct LinkBounds: Equatable {
        let id: LinkID
        let rect: CGRect
    }

    var body: some View {
        if text.runs.contains(where: { $0.link != nil }) {
            let hoveredLink = pointer.flatMap { point in
                linkBounds.first { $0.rect.contains(point) }?.id
            }
            annotatedText(hoveredLink: hoveredLink)
                .lineSpacing(lineSpacing)
                .textSelection(.enabled)
                .onContinuousHover(coordinateSpace: .global) { phase in
                    switch phase {
                    case .active(let point): pointer = point
                    case .ended: pointer = nil
                    }
                }
                .backgroundPreferenceValue(Text.LayoutKey.self) { layouts in
                    GeometryReader { geometry in
                        let frame = geometry.frame(in: .global)
                        let bounds = layouts.flatMap { anchored in
                            let origin = geometry[anchored.origin]
                            return anchored.layout.flatMap { line in
                                line.compactMap { run -> LinkBounds? in
                                    guard let id = run[LinkID.self] else { return nil }
                                    let rect = run.typographicBounds.rect.offsetBy(
                                        dx: frame.minX + origin.x,
                                        dy: frame.minY + origin.y
                                    )
                                    return LinkBounds(id: id, rect: rect)
                                }
                            }
                        }
                        Color.clear
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                            .onChange(of: bounds, initial: true) { _, bounds in linkBounds = bounds }
                    }
                }
        } else {
            Text(text)
                .lineSpacing(lineSpacing)
                .textSelection(.enabled)
        }
    }

    private func annotatedText(hoveredLink: LinkID?) -> Text {
        var result = Text(verbatim: "")
        // Group adjacent styles with the same destination into one link target.
        for (index, (url, range)) in text.runs[\.link].enumerated() {
            var segment = AttributedString(text[range])
            var part = Text(segment)
            if url != nil {
                let id = LinkID(index: index)
                if hoveredLink == id {
                    segment.appKit.foregroundColor = .controlAccentColor
                }
                part = Text(segment).customAttribute(id)
            }
            result = Text("\(result)\(part)")
        }
        return result
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
            MarkdownLinkText(text: rendered, lineSpacing: typography.bodyLineSpacing)
                .foregroundStyle(Color.secondary)
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

        return MarkdownLinkText(
            text: cell.content,
            lineSpacing: typography.bodyLineSpacing * MarkyTheme.tableLineSpacingScale
        )
        .multilineTextAlignment(textAlignment)
        .foregroundStyle(Color.primary)
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
    private enum LoadState {
        case loading
        case loaded(NSImage)
        case failed(String?)
    }

    let alt: String
    let url: String
    let title: String?
    let documentURL: URL?
    let typography: MarkdownTypography
    let colorScheme: ColorScheme

    @State private var loadState = LoadState.loading
    @State private var grantedFolderURL: URL?
    @State private var loadAttemptID = UUID()
    @State private var isPresentingFolderPicker = false
    @State private var isPresentingPreview = false

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

    private var imageLabel: String {
        alt.isEmpty ? String(localized: "Image") : alt
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
            await loadImage()
        }
    }

    @ViewBuilder
    private var imageContent: some View {
        switch loadState {
        case .loading where Self.remoteURL(from: url) != nil:
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
        case .loading:
            fallbackCard(errorMessage: nil)
        case .loaded(let image):
            Button {
                isPresentingPreview = true
            } label: {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(image.size, contentMode: .fit)
                    .frame(maxWidth: image.size.width)
                    .clipShape(RoundedRectangle(cornerRadius: MarkyTheme.imageCornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: MarkyTheme.imageCornerRadius, style: .continuous)
                            .stroke(MarkyTheme.tableBorderColor(for: colorScheme), lineWidth: MarkyTheme.tableCellBorderLineWidth)
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(imageLabel)
            .accessibilityHint("Opens image preview")
            .sheet(isPresented: $isPresentingPreview) {
                MarkdownImagePreview(image: image, imageLabel: imageLabel)
            }
        case .failed(let errorMessage):
            fallbackCard(errorMessage: errorMessage)
        }
    }

    private func fallbackCard(errorMessage: String?) -> some View {
        HStack(spacing: MarkyTheme.imageCardHStackSpacing) {
            Image(systemName: "photo")
                .font(.system(size: MarkyTheme.imageCardIconSize))
                .foregroundStyle(Color.secondary)
            VStack(alignment: .leading, spacing: MarkyTheme.imageCardVStackSpacing) {
                Text(imageLabel)
                    .font(.system(size: typography.bodyFontSize * MarkyTheme.imageCardTitleFontScale, weight: .medium))
                    .foregroundStyle(Color.primary)
                Text(url)
                    .font(.system(size: typography.bodyFontSize * MarkyTheme.imageCardUrlFontScale, design: .monospaced))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: typography.bodyFontSize * MarkyTheme.imageCardUrlFontScale))
                        .foregroundStyle(Color.secondary)
                }
            }
            .textSelection(.enabled)

            if Self.resolveLocalFileURL(for: url, relativeTo: documentURL) != nil {
                Spacer()
                Button {
                    promptForFolderAccess()
                } label: {
                    Label(
                        errorMessage != nil ? String(localized: "Grant Folder Access…") : String(localized: "Choose Folder…"),
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

    private func loadImage() async {
        guard !Task.isCancelled else { return }
        loadState = .loading
        let remoteURL = Self.remoteURL(from: url)
        let localURL = Self.resolveLocalFileURL(for: url, relativeTo: documentURL)
        do {
            let image: NSImage
            if let remoteURL {
                image = try await Self.loadRemoteImage(at: remoteURL)
            } else if let localURL, let grantedFolderURL {
                image = try await LocalImageLoader.loadImage(at: localURL, under: grantedFolderURL)
            } else if let localURL {
                image = try await LocalImageLoader.loadImage(at: localURL)
            } else {
                loadState = .failed(nil)
                return
            }
            try Task.checkCancellation()
            guard image.size.width.isFinite, image.size.width > 0,
                  image.size.height.isFinite, image.size.height > 0 else {
                throw LocalImageLoadError.invalidImageData
            }
            loadState = .loaded(image)
        } catch is CancellationError {
            // A replacement task owns the loading state after cancellation.
        } catch {
            guard !Task.isCancelled else { return }
            loadState = .failed(remoteURL == nil ? error.localizedDescription : nil)
        }
    }

    @concurrent
    private nonisolated static func loadRemoteImage(at url: URL) async throws -> NSImage {
        let (data, response) = try await URLSession.shared.data(from: url)
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
        guard let image = NSImage(data: data) else {
            throw URLError(.cannotDecodeContentData)
        }
        return image
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
                    MarkdownLinkText(text: item.body, lineSpacing: typography.bodyLineSpacing)
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
