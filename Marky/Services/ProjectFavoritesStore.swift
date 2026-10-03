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
        favoritesByProject[projectKey(for: projectURL)] ?? []
    }

    func saveFavoriteRelativePaths(_ relativePaths: [String], for projectURL: URL) {
        var favorites = favoritesByProject
        favorites[projectKey(for: projectURL)] = relativePaths
        userDefaults.set(favorites, forKey: favoritesByProjectKey)
    }

    func clearFavorites(for projectURL: URL) {
        var favorites = favoritesByProject
        favorites.removeValue(forKey: projectKey(for: projectURL))
        userDefaults.set(favorites, forKey: favoritesByProjectKey)
    }

    private var favoritesByProject: [String: [String]] {
        userDefaults.dictionary(forKey: favoritesByProjectKey) as? [String: [String]] ?? [:]
    }

    private func projectKey(for projectURL: URL) -> String {
        projectURL.standardizedFileURL.path
    }
}
