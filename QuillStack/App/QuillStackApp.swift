import SwiftUI
import SwiftData

@main
struct QuillStackApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([Capture.self, CaptureImage.self, Tag.self, PendingOCRRequest.self])
        let config = ModelConfiguration("QuillStack", isStoredInMemoryOnly: false)
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        seedDefaultTags(in: container)
        migrateUserDefaults()
        configureRemoteServer()
    }

    private func migrateUserDefaults() {
        // Migrate old macMiniHost key to remoteServerHost
        if let oldHost = UserDefaults.standard.string(forKey: "macMiniHost"),
           UserDefaults.standard.string(forKey: "remoteServerHost") == nil {
            UserDefaults.standard.set(oldHost, forKey: "remoteServerHost")
            UserDefaults.standard.removeObject(forKey: "macMiniHost")
        }
    }

    private func configureRemoteServer() {
        if let savedHost = UserDefaults.standard.string(forKey: "remoteServerHost") {
            Task {
                await RemoteOCRService.shared.setRemoteHost(savedHost)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    await processQueuePeriodically()
                }
        }
        .modelContainer(container)
    }

    private func processQueuePeriodically() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(30))

            if await RemoteOCRService.shared.checkAvailability() {
                await OCRQueueService.shared.processQueue(in: container.mainContext)
            }
        }
    }

    private func seedDefaultTags(in container: ModelContainer) {
        let context = container.mainContext
        let descriptor = FetchDescriptor<Tag>()
        let existing = (try? context.fetch(descriptor)) ?? []

        if existing.isEmpty {
            // First launch: create default tags
            for tag in Tag.defaults {
                context.insert(Tag(name: tag.name, colorHex: tag.hex))
            }
            UserDefaults.standard.set(true, forKey: "hasSeededDefaultTags")
        } else {
            // Only sync colors if we haven't done so for this install
            // This preserves user customizations after initial setup
            let hasEverSynced = UserDefaults.standard.bool(forKey: "hasSeededDefaultTags")
            if !hasEverSynced {
                let defaultsByName = Dictionary(uniqueKeysWithValues: Tag.defaults.map { ($0.name, $0.hex) })
                for tag in existing {
                    if let expectedHex = defaultsByName[tag.name], tag.colorHex != expectedHex {
                        tag.colorHex = expectedHex
                    }
                }
                UserDefaults.standard.set(true, forKey: "hasSeededDefaultTags")
            }
        }
        try? context.save()
    }
}
