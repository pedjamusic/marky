import Foundation

struct RestoredProjectBookmark {
    let url: URL
    let isStale: Bool
}

enum ProjectSessionError: Error {
    case bookmarkEncodingFailed
    case bookmarkResolutionFailed
}

protocol ProjectSessionServicing {
    func saveBookmark(for url: URL) throws
    func restoreBookmarkedURL() throws -> RestoredProjectBookmark?
    func clearBookmark()
}

final class ProjectSessionService: ProjectSessionServicing {
    private let userDefaults: UserDefaults
    private let lastProjectBookmarkKey: String

    init(
        userDefaults: UserDefaults = .standard,
        lastProjectBookmarkKey: String = "LastProjectBookmarkKey"
    ) {
        self.userDefaults = userDefaults
        self.lastProjectBookmarkKey = lastProjectBookmarkKey
    }

    func saveBookmark(for url: URL) throws {
        do {
            let securityScopedData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            userDefaults.set(securityScopedData, forKey: lastProjectBookmarkKey)
            return
        } catch {
            do {
                let plainData = try url.bookmarkData(
                    options: [],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                userDefaults.set(plainData, forKey: lastProjectBookmarkKey)
                return
            } catch {
                throw ProjectSessionError.bookmarkEncodingFailed
            }
        }
    }

    func restoreBookmarkedURL() throws -> RestoredProjectBookmark? {
        guard let data = userDefaults.data(forKey: lastProjectBookmarkKey) else { return nil }

        var stale = false
        let url: URL
        do {
            url = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )
        } catch {
            do {
                url = try URL(
                    resolvingBookmarkData: data,
                    options: [],
                    relativeTo: nil,
                    bookmarkDataIsStale: &stale
                )
            } catch {
                throw ProjectSessionError.bookmarkResolutionFailed
            }
        }

        return RestoredProjectBookmark(url: url, isStale: stale)
    }

    func clearBookmark() {
        userDefaults.removeObject(forKey: lastProjectBookmarkKey)
    }
}

@MainActor
protocol ProjectResourceAccessing {
    func startAccessing(_ url: URL) -> Bool
    func stopAccessing(_ url: URL)
}

struct ProjectResourceAccess: ProjectResourceAccessing {
    func startAccessing(_ url: URL) -> Bool { url.startAccessingSecurityScopedResource() }
    func stopAccessing(_ url: URL) { url.stopAccessingSecurityScopedResource() }
}

#if os(macOS)
import AppKit

/// Typed domain errors for local image file loading.
enum LocalImageLoadError: LocalizedError, Equatable {
    case readFailed(String)
    case invalidImageData

    var errorDescription: String? {
        switch self {
        case .readFailed(let message):
            return message
        case .invalidImageData:
            return String(localized: "Unable to decode image data")
        }
    }
}

/// Helper service for loading local image data under explicit security-scoped access.
enum LocalImageLoader {
    /// Loads image bytes directly at `targetURL` (e.g. within an existing active folder grant).
    @MainActor
    static func loadImage(at targetURL: URL) async throws -> NSImage {
        try Task.checkCancellation()
        let image = try await Task.detached(priority: .userInitiated) { () -> NSImage in
            try Task.checkCancellation()
            let data: Data
            do {
                data = try Data(contentsOf: targetURL)
            } catch {
                throw LocalImageLoadError.readFailed(error.localizedDescription)
            }
            try Task.checkCancellation()
            guard let image = NSImage(data: data) else {
                throw LocalImageLoadError.invalidImageData
            }
            return image
        }.value
        try Task.checkCancellation()
        return image
    }

    /// Loads image bytes from `targetURL` under the security scope of `securityScopedFolderURL`.
    /// Holds security-scoped access through Data read and NSImage decoding, stopping it cleanly via defer.
    @MainActor
    static func loadImage(
        at targetURL: URL,
        under securityScopedFolderURL: URL,
        resourceAccess: ProjectResourceAccessing = ProjectResourceAccess()
    ) async throws -> NSImage {
        let didAccess = resourceAccess.startAccessing(securityScopedFolderURL)
        defer {
            if didAccess {
                resourceAccess.stopAccessing(securityScopedFolderURL)
            }
        }
        try Task.checkCancellation()
        let image = try await loadImage(at: targetURL)
        try Task.checkCancellation()
        return image
    }
}
#endif
