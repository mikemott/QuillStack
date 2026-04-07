import SwiftUI
import SwiftData

@main
struct QuillStackApp: App {
    let container: ModelContainer

    static let isUITesting = CommandLine.arguments.contains("--uitesting")

    init() {
        if !Self.isUITesting {
            CrashReporting.start()
        }
        let schema = Schema([Capture.self, CaptureImage.self, Tag.self])
        let inMemory = Self.isUITesting
        let useCloud = !inMemory

        let config = ModelConfiguration(
            "QuillStack",
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: useCloud ? .automatic : .none
        )
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            let fallback = ModelConfiguration(
                "QuillStack",
                isStoredInMemoryOnly: inMemory,
                cloudKitDatabase: .none
            )
            do {
                container = try ModelContainer(for: schema, configurations: [fallback])
            } catch {
                fatalError("Failed to create ModelContainer: \(error)")
            }
        }
        seedDefaultTags(in: container)
        deduplicateTags(in: container.mainContext)
        if !Self.isUITesting {
            configureDatalabAPI()
        }
    }

    private func configureDatalabAPI() {
        if let apiKey = Bundle.main.infoDictionary?["DATALAB_API_KEY"] as? String,
           !apiKey.isEmpty {
            Task {
                await DatalabOCRService.shared.setAPIKey(apiKey)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                deduplicateTags(in: container.mainContext)
            }
        }
    }

    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Tag Deduplication

    private func deduplicateTags(in context: ModelContext) {
        let descriptor = FetchDescriptor<Tag>(sortBy: [SortDescriptor(\.createdAt)])
        guard let tags = try? context.fetch(descriptor) else { return }

        var seen: [String: Tag] = [:]
        for tag in tags {
            let key = tag.name.lowercased()
            if let existing = seen[key] {
                let capturesToMove = tag.captures.filter { capture in
                    !existing.captures.contains(where: { $0.id == capture.id })
                }
                for capture in capturesToMove {
                    existing.captures.append(capture)
                }
                context.delete(tag)
            } else {
                seen[key] = tag
            }
        }
        try? context.save()
    }

    // MARK: - Seed Tags

    private func seedDefaultTags(in container: ModelContainer) {
        let context = container.mainContext
        let descriptor = FetchDescriptor<Tag>()
        let existing = (try? context.fetch(descriptor)) ?? []

        if existing.isEmpty {
            for tag in Tag.defaults {
                context.insert(Tag(name: tag.name, colorHex: tag.hex))
            }
        } else {
            let renames = ["Note": "Project", "Document": "Reference", "Travel": "Ticket", "Inspiration": "To-Do"]
            for tag in existing {
                if let newName = renames[tag.name] {
                    tag.name = newName
                }
            }

            let existingNames = Set(existing.map(\.name)).union(renames.values)
            for tag in Tag.defaults where !existingNames.contains(tag.name) {
                context.insert(Tag(name: tag.name, colorHex: tag.hex))
            }

            let defaultsByName = Dictionary(uniqueKeysWithValues: Tag.defaults.map { ($0.name, $0.hex) })
            for tag in existing {
                if let expectedHex = defaultsByName[tag.name], tag.colorHex != expectedHex {
                    tag.colorHex = expectedHex
                }
            }
        }
        try? context.save()
    }
}
