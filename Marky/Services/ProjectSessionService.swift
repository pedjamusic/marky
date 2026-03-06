import Foundation

struct RestoredProjectBookmark {
    let url: URL
    let isStale: Bool
}

protocol ProjectSessionServicing {
    func saveBookmark(for url: URL)
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

    func saveBookmark(for url: URL) {
        if let securityScopedData = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            userDefaults.set(securityScopedData, forKey: lastProjectBookmarkKey)
            return
        }

        if let plainData = try? url.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            userDefaults.set(plainData, forKey: lastProjectBookmarkKey)
            return
        }

        userDefaults.removeObject(forKey: lastProjectBookmarkKey)
    }

    func restoreBookmarkedURL() throws -> RestoredProjectBookmark? {
        guard let data = userDefaults.data(forKey: lastProjectBookmarkKey) else { return nil }

        var stale = false
        let url = try {
            do {
                return try URL(
                    resolvingBookmarkData: data,
                    options: [.withSecurityScope],
                    relativeTo: nil,
                    bookmarkDataIsStale: &stale
                )
            } catch {
                return try URL(
                    resolvingBookmarkData: data,
                    options: [],
                    relativeTo: nil,
                    bookmarkDataIsStale: &stale
                )
            }
        }()

        return RestoredProjectBookmark(url: url, isStale: stale)
    }

    func clearBookmark() {
        userDefaults.removeObject(forKey: lastProjectBookmarkKey)
    }
}
