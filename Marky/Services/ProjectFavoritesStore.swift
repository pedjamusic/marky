import Foundation

protocol ProjectFavoritesStoring {
    func favoriteRelativePaths(for projectURL: URL) -> [String]
    func saveFavoriteRelativePaths(_ relativePaths: [String], for projectURL: URL)
    func clearFavorites(for projectURL: URL)
    func migrateFavorites(from grantedProjectURL: URL, to canonicalProjectURL: URL)
}

extension ProjectFavoritesStoring {
    func migrateFavorites(from grantedProjectURL: URL, to canonicalProjectURL: URL) {}
}

final class ProjectFavoritesStore: ProjectFavoritesStoring {
    private let userDefaults: UserDefaults
    private let favoritesByProjectKey: String

    init(
        userDefaults: UserDefaults = .standard,
        favoritesByProjectKey: String = "FavoriteRelativePathsByProjectKey"
    ) {
        self.userDefaults = userDefaults
        self.favoritesByProjectKey = favoritesByProjectKey
    }

    func favoriteRelativePaths(for projectURL: URL) -> [String] {
        favoritesByProject[projectKey(for: projectURL)] ?? []
    }

    func saveFavoriteRelativePaths(_ relativePaths: [String], for projectURL: URL) {
        var favorites = favoritesByProject
        favorites[projectKey(for: projectURL)] = relativePaths
        userDefaults.set(favorites, forKey: favoritesByProjectKey)
    }

    func clearFavorites(for projectURL: URL) {
        var favorites = favoritesByProject
        let key = projectKey(for: projectURL)
        favorites.removeValue(forKey: key)
        for (alias, canonical) in projectAliases where canonical == key {
            favorites.removeValue(forKey: alias)
        }
        userDefaults.set(favorites, forKey: favoritesByProjectKey)
    }

    /// The caller supplies the current grant and its scanned canonical identity.
    /// Unrelated legacy keys stay untouched until their location is explicitly opened.
    func migrateFavorites(from grantedProjectURL: URL, to canonicalProjectURL: URL) {
        let grantedKey = grantedProjectURL.standardizedFileURL.path
        let canonicalKey = canonicalProjectURL.standardizedFileURL.path
        guard grantedKey != canonicalKey else { return }
        var aliases = projectAliases
        aliases[grantedKey] = canonicalKey
        userDefaults.set(aliases, forKey: favoritesByProjectKey + ".Aliases")
        var favorites = favoritesByProject
        if let legacyPaths = favorites.removeValue(forKey: grantedKey) {
            favorites[canonicalKey] = Set(legacyPaths + (favorites[canonicalKey] ?? [])).sorted()
            userDefaults.set(favorites, forKey: favoritesByProjectKey)
        }
    }

    private var favoritesByProject: [String: [String]] {
        userDefaults.dictionary(forKey: favoritesByProjectKey) as? [String: [String]] ?? [:]
    }

    private var projectAliases: [String: String] {
        userDefaults.dictionary(forKey: favoritesByProjectKey + ".Aliases") as? [String: String] ?? [:]
    }

    private func projectKey(for projectURL: URL) -> String {
        let path = projectURL.standardizedFileURL.path
        return projectAliases[path] ?? path
    }
}
