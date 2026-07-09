import SwiftUI
import SwiftData
#if DEBUG
import UIKit
#endif

enum StoreState {
    case ready(ModelContainer)
    /// Diagnostic text for on-device display only — never transmitted.
    case unavailable(String)
}

@main
struct QuillStackApp: App {
    @State private var store: StoreState

    static let isUITesting = CommandLine.arguments.contains("--uitesting")

    #if DEBUG
    /// Only honoured under --uitesting, where the store is in-memory.
    static let shouldSeedSampleCapture = CommandLine.arguments.contains("--seed-ocr-capture")
    /// Forces the store to fail to load, so the recovery path is testable.
    static let shouldFailStore = CommandLine.arguments.contains("--fail-store")
    /// Seeds a capture whose OCR failed with a retryable code.
    static let shouldSeedOCRFailure = CommandLine.arguments.contains("--seed-ocr-failure")
    /// Seeds a capture where Vision found no text — an outcome, not an error.
    static let shouldSeedNoText = CommandLine.arguments.contains("--seed-no-text")
    #endif

    init() {
        if !Self.isUITesting {
            CrashReporting.start()
            // Registered before the container is built, or the `setup` event —
            // the one that carries container/entitlement failures — is missed.
            MainActor.assumeIsolated { CloudKitSyncMonitor.shared.start() }
        }
        _store = State(initialValue: Self.loadStore())
    }

    /// Never falls back to an in-memory container on failure: the app would look
    /// healthy while every new capture vanished on quit. Never deletes the store
    /// either — an unopenable store may still be recoverable.
    private static func loadStore() -> StoreState {
        #if DEBUG
        if shouldFailStore {
            return .unavailable("Simulated store failure (--fail-store)")
        }
        #endif

        let schema = Schema([Capture.self, CaptureImage.self, Tag.self])
        let inMemory = isUITesting

        if !inMemory {
            let cloudConfig = ModelConfiguration(
                "QuillStack", isStoredInMemoryOnly: false, cloudKitDatabase: .automatic
            )
            do {
                return .ready(prepared(try ModelContainer(for: schema, configurations: [cloudConfig])))
            } catch {
                // CloudKit unhappy; local-only still serves the user's data.
                CrashReporting.storeLoadFailed(stage: "cloudkit")
            }
        }

        let localConfig = ModelConfiguration(
            "QuillStack", isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none
        )
        do {
            return .ready(prepared(try ModelContainer(for: schema, configurations: [localConfig])))
        } catch {
            CrashReporting.storeUnavailable()
            return .unavailable(String(describing: error))
        }
    }

    private static func prepared(_ container: ModelContainer) -> ModelContainer {
        seedDefaultTags(in: container)
        deduplicateTags(in: container.mainContext)
        resetStaleProcessingFlags(in: container.mainContext)
        #if DEBUG
        if isUITesting && shouldSeedSampleCapture {
            seedSampleCapture(in: container.mainContext)
        }
        if isUITesting && shouldSeedOCRFailure {
            seedFailedCapture(in: container.mainContext, code: .unexpected)
        }
        if isUITesting && shouldSeedNoText {
            seedFailedCapture(in: container.mainContext, code: .noTextFound)
        }
        #endif
        return container
    }

    // MARK: - Stale Processing Flags

    /// `isProcessingOCR` is persisted before the OCR task runs. If the app is
    /// killed mid-OCR the flag survives forever, permanently suppressing that
    /// capture's action icons. Nothing else ever clears it.
    private static func resetStaleProcessingFlags(in context: ModelContext) {
        let descriptor = FetchDescriptor<Capture>(predicate: #Predicate { $0.isProcessingOCR })
        guard let stuck = try? context.fetch(descriptor), !stuck.isEmpty else { return }
        for capture in stuck {
            capture.isProcessingOCR = false
            // OCR never completed, and nothing recorded why. Mark it retryable
            // so the user gets a Retry affordance instead of a dead capture.
            if capture.ocrText == nil && capture.ocrFailureCode == nil {
                capture.ocrFailureCode = OCRFailureCode.unexpected.rawValue
            }
        }
        try? context.save()
    }

    #if DEBUG
    private static func placeholderImageData() -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 600))
        let image = renderer.image { ctx in
            UIColor.darkGray.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 400, height: 600))
        }
        return image.jpegData(compressionQuality: 0.8) ?? Data()
    }

    /// Test-only fixture: an already-processed capture, so UI tests can drive
    /// surfaces that would otherwise require the camera.
    private static func seedSampleCapture(in context: ModelContext) {
        let data = placeholderImageData()
        let capture = Capture()
        capture.extractedTitle = "Meeting notes"
        capture.ocrText = "Meeting notes Thursday\nbuy milk and coffee\ncall Sarah about the lease"
        capture.images = [CaptureImage(imageData: data, pageIndex: 0, thumbnailData: data)]
        context.insert(capture)
        try? context.save()
    }

    /// Test-only fixture: a capture whose OCR failed, for driving the status UI.
    private static func seedFailedCapture(in context: ModelContext, code: OCRFailureCode) {
        let data = placeholderImageData()
        let capture = Capture()
        capture.ocrFailureCode = code.rawValue
        capture.images = [CaptureImage(imageData: data, pageIndex: 0, thumbnailData: data)]
        context.insert(capture)
        try? context.save()
    }
    #endif

    var body: some Scene {
        WindowGroup {
            switch store {
            case .ready(let container):
                ContentView()
                    .modelContainer(container)
            case .unavailable(let detail):
                StorageUnavailableView(detail: detail) {
                    store = Self.loadStore()
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active, case .ready(let container) = store {
                Self.deduplicateTags(in: container.mainContext)
            }
        }
    }

    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Tag Deduplication

    private static func deduplicateTags(in context: ModelContext) {
        let descriptor = FetchDescriptor<Tag>(sortBy: [SortDescriptor(\.createdAt)])
        guard let tags = try? context.fetch(descriptor) else { return }

        var seen: [String: Tag] = [:]
        for tag in tags {
            let key = tag.name.lowercased()
            if let existing = seen[key] {
                // Reassign captures from the owning side to avoid corrupting SwiftData's inverse tracking
                let capturesToReassign = tag.captures ?? []
                for capture in capturesToReassign
                where !(existing.captures ?? []).contains(where: { $0.id == capture.id }) {
                    var updated = (capture.tags ?? []).filter { $0.id != tag.id }
                    updated.append(existing)
                    capture.tags = updated
                }
                context.delete(tag)
            } else {
                seen[key] = tag
            }
        }
        try? context.save()
    }

    // MARK: - Seed Tags

    private static func seedDefaultTags(in container: ModelContainer) {
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
