import SwiftUI
import SwiftData

@main
struct QuillStackApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([Capture.self, CaptureImage.self, Tag.self])
        let config = ModelConfiguration("QuillStack", isStoredInMemoryOnly: false)
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        seedDefaultTags(in: container)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    do {
                        try await VLMService.shared.loadModel()
                    } catch {
                        print("VLM load error: \(error)")
                        VLMStatus.shared.state = .failed(error.localizedDescription)
                    }
                }
        }
        .modelContainer(container)
    }

    private func seedDefaultTags(in container: ModelContainer) {
        let context = container.mainContext
        let descriptor = FetchDescriptor<Tag>()
        let existing = (try? context.fetch(descriptor)) ?? []

        if existing.isEmpty {
            for tag in Tag.defaults {
                context.insert(Tag(name: tag.name, colorHex: tag.hex))
            }
        } else {
            // Sync colors for existing default tags
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
