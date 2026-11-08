import MarkyCore

nonisolated struct CoreMarkdownDocument: Sendable {
    enum Block: Equatable, Sendable {
        case heading(level: Int, source: String)
        case paragraph(String)
        case code(String)
        case thematicBreak
        case list([ListItem])
        case quote([QuoteLine])
        case table(Table)
    }

    struct ListItem: Equatable, Sendable {
        enum Marker: Equatable, Sendable {
            case bullet
            case ordered(String)
            case task(checked: Bool)
        }

        let depth: Int
        let marker: Marker
        let source: String
    }

    struct QuoteLine: Equatable, Sendable {
        let depth: Int
        let source: String
    }

    struct Table: Equatable, Sendable {
        struct Row: RandomAccessCollection, Equatable, Sendable {
            fileprivate let cells: [String]
            let endIndex: Int
            var startIndex: Int { 0 }

            subscript(index: Int) -> String {
                precondition(index >= 0 && index < endIndex)
                return index < cells.count ? cells[index] : ""
            }
        }

        let headers: [String]
        let alignments: [MarkdownTableAlignment]
        let rows: [Row]
    }

    let blocks: [Block]
}

nonisolated enum CoreMarkdownParser {
    enum ParseError: Error {
        case invalidArgument
        case allocationFailure
        case internalFailure
    }

    @concurrent
    static func parse(_ source: String) async throws -> CoreMarkdownDocument {
        try Task.checkCancellation()
        let token = try CancellationToken()
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            let document = try copyDocument(from: source, token: token)
            try Task.checkCancellation()
            return document
        } onCancel: {
            token.request()
        }
    }

    private static func copyDocument(from source: String, token: CancellationToken) throws -> CoreMarkdownDocument {
        var input = source
        var result: OpaquePointer?
        let status = input.withUTF8 { bytes in
            bytes.withMemoryRebound(to: CChar.self) { chars in
                marky_document_create_cancellable(chars.baseAddress, chars.count, token.handle, &result)
            }
        }
        guard let result else { throw failure(for: status) }
        defer { marky_document_release(result) }
        guard status == MarkyStatus(MARKY_STATUS_OK) else { throw ParseError.internalFailure }

        let blockCount = marky_document_block_count(result)
        var blocks: [CoreMarkdownDocument.Block] = []
        blocks.reserveCapacity(blockCount)
        for index in 0..<blockCount {
            try Task.checkCancellation()
            var kind = MarkyBlockKind(MARKY_BLOCK_INVALID)
            var view = MarkyUtf8View()
            guard marky_document_block_at(result, index, &kind, &view) == MarkyStatus(MARKY_STATUS_OK) else {
                throw ParseError.internalFailure
            }

            switch kind {
            case MarkyBlockKind(MARKY_BLOCK_PARAGRAPH): blocks.append(.paragraph(try copyText(view)))
            case MarkyBlockKind(MARKY_BLOCK_CODE): blocks.append(.code(try copyText(view)))
            case MarkyBlockKind(MARKY_BLOCK_HEADING):
                var level: UInt32 = 0
                guard marky_document_heading_level_at(result, index, &level) == MarkyStatus(MARKY_STATUS_OK),
                      (1...6).contains(level)
                else {
                    throw ParseError.internalFailure
                }
                blocks.append(.heading(level: Int(level), source: try copyText(view)))
            case MarkyBlockKind(MARKY_BLOCK_THEMATIC_BREAK):
                blocks.append(.thematicBreak)
            case MarkyBlockKind(MARKY_BLOCK_LIST):
                blocks.append(.list(try copyList(from: result, blockIndex: index)))
            case MarkyBlockKind(MARKY_BLOCK_QUOTE):
                blocks.append(.quote(try copyQuote(from: result, blockIndex: index)))
            case MarkyBlockKind(MARKY_BLOCK_TABLE):
                blocks.append(.table(try copyTable(from: result, blockIndex: index)))
            default: throw ParseError.internalFailure
            }
        }
        return CoreMarkdownDocument(blocks: blocks)
    }

    private static func copyList(from document: OpaquePointer, blockIndex: Int) throws -> [CoreMarkdownDocument.ListItem] {
        let count = marky_document_list_item_count(document, blockIndex)
        guard count > 0 else { throw ParseError.internalFailure }
        var items: [CoreMarkdownDocument.ListItem] = []
        items.reserveCapacity(count)
        for index in 0..<count {
            try Task.checkCancellation()
            var item = MarkyListItemView()
            guard marky_document_list_item_at(document, blockIndex, index, &item) == MarkyStatus(MARKY_STATUS_OK) else {
                throw ParseError.internalFailure
            }
            let marker: CoreMarkdownDocument.ListItem.Marker
            switch item.marker_kind {
            case MarkyListMarkerKind(MARKY_LIST_MARKER_BULLET): marker = .bullet
            case MarkyListMarkerKind(MARKY_LIST_MARKER_ORDERED): marker = .ordered(try copyText(item.ordered_marker))
            case MarkyListMarkerKind(MARKY_LIST_MARKER_TASK_UNCHECKED): marker = .task(checked: false)
            case MarkyListMarkerKind(MARKY_LIST_MARKER_TASK_CHECKED): marker = .task(checked: true)
            default: throw ParseError.internalFailure
            }
            items.append(.init(depth: item.depth, marker: marker, source: try copyText(item.source)))
        }
        return items
    }

    private static func copyQuote(from document: OpaquePointer, blockIndex: Int) throws -> [CoreMarkdownDocument.QuoteLine] {
        let count = marky_document_quote_line_count(document, blockIndex)
        guard count > 0 else { throw ParseError.internalFailure }
        var lines: [CoreMarkdownDocument.QuoteLine] = []
        lines.reserveCapacity(count)
        for index in 0..<count {
            try Task.checkCancellation()
            var line = MarkyQuoteLineView()
            guard marky_document_quote_line_at(document, blockIndex, index, &line) == MarkyStatus(MARKY_STATUS_OK) else {
                throw ParseError.internalFailure
            }
            lines.append(.init(depth: line.depth, source: try copyText(line.source)))
        }
        return lines
    }

    private static func copyTable(from document: OpaquePointer, blockIndex: Int) throws -> CoreMarkdownDocument.Table {
        let columnCount = marky_document_table_column_count(document, blockIndex)
        guard columnCount > 0 else { throw ParseError.internalFailure }
        var headers: [String] = []
        var alignments: [MarkdownTableAlignment] = []
        headers.reserveCapacity(columnCount)
        alignments.reserveCapacity(columnCount)
        for columnIndex in 0..<columnCount {
            try Task.checkCancellation()
            var column = MarkyTableColumnView()
            guard marky_document_table_column_at(document, blockIndex, columnIndex, &column) == MarkyStatus(MARKY_STATUS_OK) else {
                throw ParseError.internalFailure
            }
            switch column.alignment {
            case MarkyTableAlignment(MARKY_TABLE_ALIGNMENT_LEFT): alignments.append(.left)
            case MarkyTableAlignment(MARKY_TABLE_ALIGNMENT_CENTER): alignments.append(.center)
            case MarkyTableAlignment(MARKY_TABLE_ALIGNMENT_RIGHT): alignments.append(.right)
            default: throw ParseError.internalFailure
            }
            headers.append(try copyText(column.header))
        }

        let rowCount = marky_document_table_row_count(document, blockIndex)
        var rows: [CoreMarkdownDocument.Table.Row] = []
        rows.reserveCapacity(rowCount)
        for rowIndex in 0..<rowCount {
            try Task.checkCancellation()
            let contentCount = marky_document_table_row_content_count(document, blockIndex, rowIndex)
            guard contentCount <= columnCount else { throw ParseError.internalFailure }
            var cells: [String] = []
            cells.reserveCapacity(contentCount)
            for columnIndex in 0..<contentCount {
                try Task.checkCancellation()
                var cell = MarkyUtf8View()
                guard marky_document_table_cell_at(document, blockIndex, rowIndex, columnIndex, &cell) == MarkyStatus(MARKY_STATUS_OK) else {
                    throw ParseError.internalFailure
                }
                cells.append(try copyText(cell))
            }
            rows.append(.init(cells: cells, endIndex: columnCount))
        }
        return .init(headers: headers, alignments: alignments, rows: rows)
    }

    private static func copyText(_ view: MarkyUtf8View) throws -> String {
        guard let data = view.data,
              let text = String(validating: UnsafeRawBufferPointer(start: data, count: view.byte_count), as: UTF8.self)
        else {
            throw ParseError.internalFailure
        }
        return text
    }

    private static func failure(for status: MarkyStatus) -> any Error {
        switch status {
        case MarkyStatus(MARKY_STATUS_INVALID_ARGUMENT):
            ParseError.invalidArgument
        case MarkyStatus(MARKY_STATUS_ALLOCATION_FAILURE):
            ParseError.allocationFailure
        case MarkyStatus(MARKY_STATUS_CANCELLED):
            CancellationError()
        default:
            ParseError.internalFailure
        }
    }

    // The handle is immutable and both closures retain its owner while they use it.
    // The core explicitly permits concurrent cancellation requests during a parse.
    private final class CancellationToken: @unchecked Sendable {
        let handle: OpaquePointer

        init() throws {
            var result: OpaquePointer?
            let status = marky_cancellation_token_create(&result)
            guard let result else { throw failure(for: status) }
            guard status == MarkyStatus(MARKY_STATUS_OK) else {
                marky_cancellation_token_release(result)
                throw ParseError.internalFailure
            }
            handle = result
        }

        deinit {
            marky_cancellation_token_release(handle)
        }

        func request() {
            marky_cancellation_token_request(handle)
        }
    }
}
