//
//  MarkyApp.swift
//  Marky
//
//  Created by Predrag Drljaca on 3/5/26.
//

import SwiftUI
import SwiftData

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

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
        #if os(macOS)
        .windowToolbarStyle(.unified(showsTitle: true))
        #endif
    }
}
