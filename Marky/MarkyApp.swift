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
    @AppStorage(AppPreferenceKeys.appearanceMode)
    private var appearanceModeRawValue = AppAppearanceMode.system.rawValue

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
                #if os(macOS)
                .onAppear {
                    Self.applyAppAppearance(selectedAppearanceMode)
                }
                .onChange(of: appearanceModeRawValue) { _ in
                    Self.applyAppAppearance(selectedAppearanceMode)
                }
                #endif
        }
        .modelContainer(sharedModelContainer)
        #if os(macOS)
        .windowToolbarStyle(.unified(showsTitle: true))
        #endif

        #if os(macOS)
        Settings {
            MarkySettingsView()
        }
        #endif
    }

    private var selectedAppearanceMode: AppAppearanceMode {
        AppAppearanceMode(rawValue: appearanceModeRawValue) ?? .system
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

    #if os(macOS)
    private static func applyAppAppearance(_ mode: AppAppearanceMode) {
        let resolvedAppearance: NSAppearance?
        switch mode {
        case .system:
            resolvedAppearance = nil
        case .light:
            resolvedAppearance = NSAppearance(named: .aqua)
        case .dark:
            resolvedAppearance = NSAppearance(named: .darkAqua)
        }

        NSApplication.shared.appearance = resolvedAppearance
        for window in NSApplication.shared.windows {
            window.appearance = resolvedAppearance
            window.contentView?.needsLayout = true
            window.contentView?.needsDisplay = true
            window.invalidateShadow()
        }
    }
    #endif

}
