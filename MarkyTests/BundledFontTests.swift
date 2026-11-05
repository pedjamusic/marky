import AppKit
import CoreText
import Foundation
import Testing
@testable import Marky

@MainActor
struct BundledFontTests {
    @Test
    func packagedFontsAreDiscoveredAndRegisterTheirActualFamilies() throws {
        let urls = BundledFontService.fontURLs(in: .main)
        #expect(urls.count == 3)
        #expect(BundledFontService.register(fontURLs: urls).isEmpty)
        // A repeated registration must be harmless, including duplicate discovery URLs.
        #expect(BundledFontService.register(fontURLs: urls + urls).isEmpty)
        for family in ["Fraunces", "Literata"] {
            let font = try #require(NSFont(name: family, size: 18))
            #expect(font.familyName == family)
        }
    }

    @Test
    func missingResourcesAreReported() {
        #expect(BundledFontService.register(fontURLs: []) == [.missingResources])
    }

    @Test
    func invalidFontReturnsTypedRegistrationFailure() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("invalid.ttf")
        try Data("invalid font".utf8).write(to: url)
        let failures = BundledFontService.register(fontURLs: [url])
        #expect(failures.count == 1)
        guard let failure = failures.first else { return }
        if case .registration = failure {} else {
            Issue.record("Expected a typed registration failure")
        }
    }
}
