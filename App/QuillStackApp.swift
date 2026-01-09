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

        // Warm up expensive OCR dependencies off the main thread to avoid launch stalls
        ServicePrewarmer.warmHeavyServices()

        // Initialize offline mode support
        Task { @MainActor in
            // Start network monitoring
            _ = NetworkMonitor.shared

            // Process any pending notes from previous sessions
            let queue = ProcessingQueue.shared
            await queue.updatePendingCount()
            if queue.pendingCount > 0 {
                print("📱 Found \(queue.pendingCount) pending notes from previous session")
                await queue.processAllPending()
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, coreDataStack.persistentContainer.viewContext)
        }
    }
}
