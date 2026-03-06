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
                userDefaults.removeObject(forKey: lastProjectBookmarkKey)
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
