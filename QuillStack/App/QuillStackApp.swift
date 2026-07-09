import SwiftUI
import SwiftData
#if DEBUG
import UIKit
#endif

@main
struct QuillStackApp: App {
    let container: ModelContainer

    static let isUITesting = CommandLine.arguments.contains("--uitesting")

    #if DEBUG
    /// Only honoured under --uitesting, where the store is in-memory.
    static let shouldSeedSampleCapture = CommandLine.arguments.contains("--seed-ocr-capture")
    #endif

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
        #if DEBUG
        if Self.isUITesting && Self.shouldSeedSampleCapture {
            Self.seedSampleCapture(in: container.mainContext)
        }
        #endif
    }

    #if DEBUG
    /// Test-only fixture: an already-processed capture, so UI tests can drive
    /// surfaces that would otherwise require the camera.
    private static func seedSampleCapture(in context: ModelContext) {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 600))
        let image = renderer.image { ctx in
            UIColor.darkGray.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 400, height: 600))
        }
        let data = image.jpegData(compressionQuality: 0.8) ?? Data()

        let capture = Capture()
        capture.extractedTitle = "Meeting notes"
        capture.ocrText = "Meeting notes Thursday\nbuy milk and coffee\ncall Sarah about the lease"
        capture.images = [CaptureImage(imageData: data, pageIndex: 0, thumbnailData: data)]
        context.insert(capture)
        try? context.save()
    }
    #endif

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
                // Reassign captures from the owning side to avoid corrupting SwiftData's inverse tracking
                let capturesToReassign = tag.captures ?? []
                for capture in capturesToReassign {
                    if !(existing.captures ?? []).contains(where: { $0.id == capture.id }) {
                        var updated = (capture.tags ?? []).filter { $0.id != tag.id }
                        updated.append(existing)
                        capture.tags = updated
                    }
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
