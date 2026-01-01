//
//  QuillStackApp.swift
//  QuillStack
//
//  Created on 2025-12-10.
//

import SwiftUI
import CoreData

@main
struct QuillStackApp: App {
    // Core Data stack initialization
    let coreDataStack = CoreDataStack.shared

    init() {
        // Register all built-in note type plugins
        NoteTypeRegistry.shared.registerBuiltInPlugins()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, coreDataStack.persistentContainer.viewContext)
        }
    }
}
