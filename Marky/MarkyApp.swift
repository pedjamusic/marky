//
//  MarkyApp.swift
//  Marky
//
//  Created by Predrag Drljaca on 3/5/26.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

@main
struct MarkyApp: App {
    @AppStorage(AppPreferenceKeys.appearanceMode)
    private var appearanceModeRawValue = AppAppearanceMode.system.rawValue

    init() {
        BundledFontService.register()
        Self.applyDockIconFallbackIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                #if os(macOS)
                .onAppear {
                    Self.applyAppAppearance(selectedAppearanceMode)
                }
                .onChange(of: appearanceModeRawValue) {
                    Self.applyAppAppearance(selectedAppearanceMode)
                }
                #endif
        }
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

        if NSApplication.shared.appearance == resolvedAppearance {
            return
        }

        NSApplication.shared.appearance = resolvedAppearance
        for window in NSApplication.shared.windows {
            if window.appearance != resolvedAppearance {
                window.appearance = resolvedAppearance
                window.invalidateShadow()
            }
        }
    }
    #endif

}
