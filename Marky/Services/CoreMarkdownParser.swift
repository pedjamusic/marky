import MarkyCore

nonisolated struct CoreMarkdownDocument: Sendable {
    enum Block: Equatable, Sendable {
        case heading(level: Int, source: String)
        case paragraph(String)
        case code(String)
        case thematicBreak
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
            guard marky_document_block_at(result, index, &kind, &view) == MarkyStatus(MARKY_STATUS_OK),
                  let data = view.data,
                  let text = String(validating: UnsafeRawBufferPointer(start: data, count: view.byte_count), as: UTF8.self)
            else {
                throw ParseError.internalFailure
            }

            switch kind {
            case MarkyBlockKind(MARKY_BLOCK_PARAGRAPH): blocks.append(.paragraph(text))
            case MarkyBlockKind(MARKY_BLOCK_CODE): blocks.append(.code(text))
            case MarkyBlockKind(MARKY_BLOCK_HEADING):
                var level: UInt32 = 0
                guard marky_document_heading_level_at(result, index, &level) == MarkyStatus(MARKY_STATUS_OK),
                      (1...6).contains(level)
                else {
                    throw ParseError.internalFailure
                }
                blocks.append(.heading(level: Int(level), source: text))
            case MarkyBlockKind(MARKY_BLOCK_THEMATIC_BREAK):
                blocks.append(.thematicBreak)
            default: throw ParseError.internalFailure
            }
        }
        return CoreMarkdownDocument(blocks: blocks)
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
