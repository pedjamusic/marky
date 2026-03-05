//
//  MarkyApp.swift
//  Marky
//
//  Created by Predrag Drljaca on 3/5/26.
//

import SwiftUI
import SwiftData
#if os(macOS)
import AppKit
#endif

@main
struct MarkyApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                #if os(macOS)
                .background(WindowChromeConfigurator())
                #endif
        }
        .modelContainer(sharedModelContainer)
    }
}
#if os(macOS)
private struct WindowChromeConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configureWindow(from: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configureWindow(from: nsView)
        }
    }

    private func configureWindow(from view: NSView) {
        guard let window = view.window else { return }
        window.styleMask.insert(.fullSizeContentView)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.toolbarStyle = .unified
        window.toolbar?.showsBaselineSeparator = false
        window.isOpaque = false
        window.backgroundColor = NSColor(calibratedWhite: 0.1, alpha: 1.0)
    }
}
#endif
