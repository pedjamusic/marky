import Foundation
import SwiftUI

#if os(macOS)
enum MarkdownTableAlignment: String, Sendable {
    case left
    case center
    case right
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
    @MainActor
    static func render(
        coreDocument document: CoreMarkdownDocument,
        mode: MarkdownTypographyMode,
        textSizePreset: MarkdownReaderTextSizePreset = .default,
        isDarkMode: Bool
    ) -> [MarkdownRenderedBlock] {
        let typography = MarkdownTypography(mode: mode, textSizePreset: textSizePreset)
        return document.blocks.enumerated().map { blockIndex, block in
            @MainActor
            func inline(row: Int = 0, column: Int = 0, heading: Int? = nil, header: Bool = false) -> AttributedString {
                AttributedString(MarkdownRenderer.renderInline(
                    from: document.inlineRuns(inBlock: blockIndex, row: row, column: column),
                    mode: mode, textSizePreset: textSizePreset, isDarkMode: isDarkMode,
                    headingLevel: heading, isTableHeader: header
                ))
            }

            let kind: MarkdownRenderedBlock.Kind
            switch block {
            case .heading(let level, _):
                kind = .heading(level: level, text: inline(heading: level))
            case .paragraph:
                kind = .paragraph(inline())
            case .list(let items):
                kind = .list(items.enumerated().map { index, item in
                    let marker = switch item.marker {
                    case .bullet: "•"
                    case .ordered(let source): source
                    case .task(let checked): checked ? typography.checkboxCheckedSymbol : typography.checkboxUncheckedSymbol
                    }
                    return MarkdownListItem(id: index, nestingLevel: item.depth, marker: marker, body: inline(row: index))
                })
            case .quote:
                kind = .quote(inline())
            case .code(let code):
                kind = .code(code)
            case .table(let table):
                @MainActor
                func cells(row: Int) -> [MarkdownTableCell] {
                    table.alignments.enumerated().map { column, alignment in
                        MarkdownTableCell(id: column, content: inline(row: row, column: column, header: row == 0),
                                          alignment: alignment)
                    }
                }
                let rows = table.rows.indices.map { MarkdownTableRow(id: $0, cells: cells(row: $0 + 1)) }
                kind = .table(.init(headers: cells(row: 0), rows: rows))
            case .thematicBreak:
                kind = .thematicBreak
            case .image(let alt, let destination, let title):
                kind = .image(alt: alt, url: destination, title: title)
            }
            return MarkdownRenderedBlock(id: blockIndex, kind: kind)
        }
    }

    nonisolated static let nestedQuoteIndicator = "▎ "
}
#endif
