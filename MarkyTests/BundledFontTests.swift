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

    @Test(arguments: ["", "Fonts", "Resources/Fonts"])
    func discoverySupportsPackagedResourceLayouts(subdirectory: String) throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let bundleURL = folder.appendingPathComponent("Fonts.bundle")
        let resources = bundleURL.appendingPathComponent("Contents/Resources")
        let destination = subdirectory.isEmpty ? resources : resources.appendingPathComponent(subdirectory)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let info = ["CFBundleIdentifier": "rocks.toodear.Marky.font-fixture.\(UUID().uuidString)", "CFBundlePackageType": "BNDL"]
        let plist = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        try plist.write(to: bundleURL.appendingPathComponent("Contents/Info.plist"))
        let fontURL = destination.appendingPathComponent("Fixture.ttf")
        try Data("font discovery fixture".utf8).write(to: fontURL)
        let bundle = try #require(Bundle(url: bundleURL))
        let discovered = BundledFontService.fontURLs(in: bundle)
        #expect(discovered.count == 1)
        #expect(discovered.first?.resolvingSymlinksInPath() == fontURL.resolvingSymlinksInPath())
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
