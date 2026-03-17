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
        }
        .modelContainer(container)
    }

    private func seedDefaultTags(in container: ModelContainer) {
        let context = container.mainContext
        let descriptor = FetchDescriptor<Tag>()
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0
        guard existingCount == 0 else { return }

        for tag in Tag.defaults {
            context.insert(Tag(name: tag.name, colorHex: tag.hex))
        }
        try? context.save()
    }
}
