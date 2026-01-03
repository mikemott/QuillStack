//
//  QuillStackApp.swift
//  QuillStack
//
//  Created on 2025-12-10.
//

import SwiftUI
import CoreData
import Sentry

@main
struct QuillStackApp: App {
    // Core Data stack initialization
    let coreDataStack = CoreDataStack.shared

    // Deep link manager
    @State private var deepLinkManager = DeepLinkManager()

    init() {
        // Initialize Sentry for crash reporting
        SentrySDK.start { options in
            options.dsn = "https://2b1c02a12b2cddac3d64fd412f5852be@o4510637025918976.ingest.us.sentry.io/4510641123426304"
            options.environment = "production"

            // Performance monitoring
            options.tracesSampleRate = 1.0 // 100% for beta, reduce to 0.1 for production

            // Capture breadcrumbs automatically
            options.enableAutoSessionTracking = true
            options.sessionTrackingIntervalMillis = 30000

            // Attach screenshots on crashes
            options.attachScreenshot = true
            options.attachViewHierarchy = true

            // Debug prints (disable in production)
            #if DEBUG
            options.debug = true
            #endif

            // Set app context - must match build script format: VERSION-BUILD
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
            let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
            options.releaseName = "\(version)-\(build)"
            options.dist = build
        }

        // Set user context
        SentrySDK.configureScope { scope in
            scope.setContext(value: [
                "device_model": UIDevice.current.model,
                "ios_version": UIDevice.current.systemVersion,
                "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
            ], key: "device_info")
        }

        // Register all built-in note type plugins
        NoteTypeRegistry.shared.registerBuiltInPlugins()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, coreDataStack.persistentContainer.viewContext)
                .environment(deepLinkManager)
                .onOpenURL { url in
                    deepLinkManager.handle(url: url)
                }
        }
    }
}
