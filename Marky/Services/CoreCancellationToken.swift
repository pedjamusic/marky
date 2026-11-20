import MarkyCore

// Cancellation can be requested while the core uses the immutable handle.
nonisolated final class CoreCancellationToken: @unchecked Sendable {
    let handle: OpaquePointer

    init(failure: (MarkyStatus) -> any Error) throws {
        var result: OpaquePointer?
        let status = marky_cancellation_token_create(&result)
        guard status == MarkyStatus(MARKY_STATUS_OK), let result else {
            marky_cancellation_token_release(result)
            throw failure(status)
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
