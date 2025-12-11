//
//  QuillStackApp.swift
//  QuillStack
//
//  Created by mike on 12/11/25.
//

import SwiftUI
import CoreData

@main
struct QuillStackApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
