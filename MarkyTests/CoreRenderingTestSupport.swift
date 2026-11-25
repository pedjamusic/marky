import AppKit
@testable import Marky

/// Parses with the production core and renders with the native reader.
@MainActor
func coreBlocks(
    _ source: String, mode: MarkdownTypographyMode = .allSystem,
    textSizePreset: MarkdownReaderTextSizePreset = .default, isDarkMode: Bool = false
) async throws -> [MarkdownRenderedBlock] {
    let document = try await CoreMarkdownParser.parse(source)
    return MarkdownContentBlocks.render(coreDocument: document, mode: mode, textSizePreset: textSizePreset, isDarkMode: isDarkMode)
}

/// The text of every rendered block, joined by newlines, for assertions about visible text and inline styles.
/// Code blocks contribute plain text: the view, not the renderer, styles them.
@MainActor
func coreText(
    _ source: String, mode: MarkdownTypographyMode = .allSystem, textSizePreset: MarkdownReaderTextSizePreset = .default
) async throws -> NSAttributedString {
    let result = NSMutableAttributedString()
    for block in try await coreBlocks(source, mode: mode, textSizePreset: textSizePreset) {
        let pieces: [NSAttributedString] = switch block.kind {
        case .heading(_, let text), .paragraph(let text), .quote(let text): [NSAttributedString(text)]
        case .code(let text): [NSAttributedString(string: text)]
        case .list(let items): items.map { NSAttributedString($0.body) }
        case .table(let table): (table.headers + table.rows.flatMap(\.cells)).map { NSAttributedString($0.content) }
        case .image(let alt, _, _): [NSAttributedString(string: alt)]
        case .thematicBreak: []
        }
        for piece in pieces {
            if result.length > 0 { result.append(NSAttributedString(string: "\n")) }
            result.append(piece)
        }
    }
    return result
}
