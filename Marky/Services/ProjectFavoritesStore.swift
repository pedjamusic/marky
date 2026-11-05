import Foundation

protocol ProjectFavoritesStoring {
    func favoriteRelativePaths(for projectURL: URL) -> [String]
    func saveFavoriteRelativePaths(_ relativePaths: [String], for projectURL: URL)
    func clearFavorites(for projectURL: URL)
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
        let key = projectKey(for: projectURL)
        // Older versions persisted the granted path. Preserve those favorites when
        // the same project is subsequently opened through another path alias.
        return Set(favoritesByProject.flatMap { storedKey, paths in
            projectKey(for: URL(fileURLWithPath: storedKey)) == key ? paths : []
        }).sorted()
    }

    func saveFavoriteRelativePaths(_ relativePaths: [String], for projectURL: URL) {
        var favorites = removingAliases(of: projectURL)
        favorites[projectKey(for: projectURL)] = relativePaths
        userDefaults.set(favorites, forKey: favoritesByProjectKey)
    }

    func clearFavorites(for projectURL: URL) {
        userDefaults.set(removingAliases(of: projectURL), forKey: favoritesByProjectKey)
    }

    private func removingAliases(of projectURL: URL) -> [String: [String]] {
        let key = projectKey(for: projectURL)
        return favoritesByProject.filter { storedKey, _ in
            projectKey(for: URL(fileURLWithPath: storedKey)) != key
        }
    }

    private var favoritesByProject: [String: [String]] {
        userDefaults.dictionary(forKey: favoritesByProjectKey) as? [String: [String]] ?? [:]
    }

    private func projectKey(for projectURL: URL) -> String {
        projectURL.canonicalFileURL.path
    }
}
