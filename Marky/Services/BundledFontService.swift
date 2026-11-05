import CoreText
import Foundation
import OSLog

/// Registers the app's packaged fonts regardless of whether Xcode flattens resource folders.
enum BundledFontService {
    enum Failure: Error, Equatable {
        case missingResources
        case registration(code: Int)
    }

    private static let logger = Logger(subsystem: "rocks.toodear.Marky", category: "BundledFonts")

    static func fontURLs(in bundle: Bundle) -> [URL] {
        let urls = [nil, "Fonts", "Resources/Fonts"].flatMap { directory in
            (bundle.urls(forResourcesWithExtension: "ttf", subdirectory: directory) ?? []).map { $0 as URL }
        }
        return Array(Set(urls.map { $0.standardizedFileURL })).sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    @discardableResult
    static func register(in bundle: Bundle = .main) -> [Failure] {
        register(fontURLs: fontURLs(in: bundle))
    }

    @discardableResult
    static func register(fontURLs: [URL]) -> [Failure] {
        guard !fontURLs.isEmpty else {
            logger.error("Bundled font resources are missing")
            return [.missingResources]
        }
        var failures: [Failure] = []
        for url in Set(fontURLs) {
            var registrationError: Unmanaged<CFError>?
            guard !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &registrationError) else { continue }
            let code = registrationError.map { CFErrorGetCode($0.takeRetainedValue()) } ?? -1
            // Registration is process-wide; app initialization and tests may register the same fonts.
            guard code != CTFontManagerError.alreadyRegistered.rawValue else { continue }
            logger.error("Bundled font registration failed (code: \(code, privacy: .public))")
            failures.append(.registration(code: code))
        }
        return failures
    }
}
