import Foundation
import MarkyCore

protocol ProjectFavoritesStoring {
    func favoriteRelativePaths(for projectURL: URL) -> [String]
    func saveFavoriteRelativePaths(_ relativePaths: [String], for projectURL: URL)
    func clearFavorites(for projectURL: URL)
    func savedPaths(for projectURL: URL, authorizedAlias: URL?) -> (canonical: [String], alias: [String])
    func saveReconciledPaths(_ paths: [String], for projectURL: URL, migrating alias: URL?)
}

extension ProjectFavoritesStoring {
    func savedPaths(for projectURL: URL, authorizedAlias: URL?) -> (canonical: [String], alias: [String]) {
        (favoriteRelativePaths(for: projectURL), authorizedAlias.map { favoriteRelativePaths(for: $0) } ?? [])
    }

    func saveReconciledPaths(_ paths: [String], for projectURL: URL, migrating alias: URL?) {
        if paths.isEmpty {
            clearFavorites(for: projectURL)
        } else {
            saveFavoriteRelativePaths(paths, for: projectURL)
        }
    }

    func reconcileFavorites(for projectURL: URL, authorizedAlias: URL?, confirmedMissing: Set<String>,
                            scanState: MarkyProjectScanState) throws -> [String] {
        let latest = savedPaths(for: projectURL, authorizedAlias: authorizedAlias)
        // Swift path equality treats canonically equivalent Unicode spellings as equal.
        // Keep each stored spelling while supplying one byte representation per key.
        let paths = latest.canonical + latest.alias
        let spellings = Dictionary(paths.map { ($0, $0) }, uniquingKeysWith: { first, _ in first })
        var bytes = Data()
        let ranges = [latest.canonical, latest.alias, Array(confirmedMissing)].map { paths in
            paths.map { path -> Range<Int> in
                let start = bytes.count
                bytes.append(contentsOf: path.precomposedStringWithCanonicalMapping.utf8)
                return start..<bytes.count
            }
        }
        var result: OpaquePointer?
        let status = bytes.withUnsafeBytes { buffer in
            let chars = buffer.bindMemory(to: CChar.self)
            let lists = ranges.map { list in
                list.map { range in
                    MarkyUtf8View(data: chars.baseAddress?.advanced(by: range.lowerBound), byte_count: range.count)
                }
            }
            return lists[0].withUnsafeBufferPointer { canonical in
                lists[1].withUnsafeBufferPointer { alias in
                    lists[2].withUnsafeBufferPointer { missing in
                        let input = MarkyProjectFavoriteReconciliation(
                            latest_canonical: MarkyProjectFavoritePaths(paths: canonical.baseAddress, count: canonical.count),
                            latest_alias: MarkyProjectFavoritePaths(paths: alias.baseAddress, count: alias.count),
                            confirmed_missing: MarkyProjectFavoritePaths(paths: missing.baseAddress, count: missing.count),
                            scan_state: scanState,
                            alias_is_authorized: authorizedAlias == nil ? 0 : 1
                        )
                        return marky_project_reconcile_favorites(input, nil, &result)
                    }
                }
            }
        }
        defer { marky_project_favorite_result_release(result) }
        guard status == MarkyStatus(MARKY_STATUS_OK), let result else { throw ProjectScanError.unavailable }
        let retained = (0..<marky_project_favorite_result_count(result)).map { index in
            let path = ProjectIndex.copyText(marky_project_favorite_result_path(result, index))
            return spellings[path] ?? path
        }.sorted()
        let migrated = marky_project_favorite_result_migrates_alias(result) != 0 ? authorizedAlias : nil
        saveReconciledPaths(retained, for: projectURL, migrating: migrated)
        return retained
    }
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

    func savedPaths(for projectURL: URL, authorizedAlias: URL?) -> (canonical: [String], alias: [String]) {
        let favorites = favoritesByProject
        let paths = favorites[projectURL.standardizedFileURL.path] ?? []
        let legacy = authorizedAlias.flatMap { favorites[$0.standardizedFileURL.path] } ?? []
        return (paths, legacy)
    }

    func saveReconciledPaths(_ paths: [String], for projectURL: URL, migrating alias: URL?) {
        let canonicalKey = projectURL.standardizedFileURL.path
        var favorites = favoritesByProject
        let aliasKey = alias?.standardizedFileURL.path
        if let aliasKey { favorites.removeValue(forKey: aliasKey) }
        favorites[canonicalKey] = paths.isEmpty ? nil : paths
        userDefaults.set(favorites, forKey: favoritesByProjectKey)
        if let aliasKey {
            var aliases = projectAliases
            aliases[aliasKey] = canonicalKey
            userDefaults.set(aliases, forKey: favoritesByProjectKey + ".Aliases")
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
