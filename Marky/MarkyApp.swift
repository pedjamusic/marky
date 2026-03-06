//
//  MarkyApp.swift
//  Marky
//
//  Created by Predrag Drljaca on 3/5/26.
//

import SwiftUI
import SwiftData
import CoreText
#if os(macOS)
import AppKit
#endif

@main
struct MarkyApp: App {
    private static func makeModelContainer() -> ModelContainer {
        let schema = Schema([
            Item.self,
        ])
        let persistentConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [persistentConfiguration])
        } catch {
            assertionFailure("Persistent ModelContainer init failed: \(error). Falling back to in-memory store.")
            let inMemoryConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(for: schema, configurations: [inMemoryConfiguration])
            } catch {
                fatalError("Could not create in-memory ModelContainer fallback: \(error)")
            }
        }
    }

    var sharedModelContainer: ModelContainer = Self.makeModelContainer()

    init() {
        Self.registerBundledFontsIfNeeded()
        Self.applyDockIconFallbackIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
        #if os(macOS)
        .windowToolbarStyle(.unified(showsTitle: true))
        #endif
    }

    private static func registerBundledFontsIfNeeded() {
        guard let fontURL = Bundle.main.url(
            forResource: "Fraunces[SOFT,WONK,opsz,wght]",
            withExtension: "ttf"
        ) else {
            return
        }

        var registrationError: Unmanaged<CFError>?
        CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &registrationError)
    }

    private static func applyDockIconFallbackIfNeeded() {
        #if os(macOS)
        if let iconImage = NSImage(named: "AppIcon") ?? Bundle.main.image(forResource: "AppIcon") {
            NSApplication.shared.applicationIconImage = iconImage
        }
        #endif
    }

}
