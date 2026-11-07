import MarkyCore

nonisolated struct CoreMarkdownDocument: Sendable {
    let paragraphs: [String]
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
        if blockCount == 0 {
            return CoreMarkdownDocument(paragraphs: [])
        }

        var view = MarkyUtf8View()
        guard blockCount == 1,
              marky_document_paragraph_at(result, 0, &view) == MarkyStatus(MARKY_STATUS_OK),
              view.byte_count > 0,
              let data = view.data,
              let paragraph = String(validating: UnsafeRawBufferPointer(start: data, count: view.byte_count), as: UTF8.self)
        else {
            throw ParseError.internalFailure
        }
        return CoreMarkdownDocument(paragraphs: [paragraph])
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
