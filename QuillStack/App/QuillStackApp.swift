import SwiftUI
import SwiftData
import BackgroundTasks

@main
struct QuillStackApp: App {
    @Environment(\.scenePhase) private var scenePhase

    let container: ModelContainer

    private static let bgTaskID = "com.quillstack.ocr-queue-processing"

    static let isUITesting = CommandLine.arguments.contains("--uitesting")

    init() {
        if !Self.isUITesting {
            CrashReporting.start()
        }
        let schema = Schema([Capture.self, CaptureImage.self, Tag.self, PendingOCRRequest.self])
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
            // CloudKit setup can fail even with an iCloud account (e.g. container
            // not yet provisioned). Fall back to local-only storage.
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
            configureMacMini()
            registerBackgroundTask()
        }
    }

    private func configureMacMini() {
        // Migrate stale Qwen model name to Chandra 2
        if UserDefaults.standard.string(forKey: "ollamaModel") == "qwen3-vl:8b" {
            UserDefaults.standard.set("chandra-ocr-2", forKey: "ollamaModel")
        }

        Task {
            if let savedHost = UserDefaults.standard.string(forKey: "macMiniHost") {
                await RemoteOCRService.shared.setMacMiniHost(savedHost)
            }
            if let savedModel = UserDefaults.standard.string(forKey: "ollamaModel") {
                await RemoteOCRService.shared.setModelName(savedModel)
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
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                deduplicateTags(in: container.mainContext)
                Task {
                    await OCRQueueService.shared.processQueue(in: container.mainContext)
                }
            case .background:
                scheduleBackgroundProcessing()
            default:
                break
            }
        }
    }

    // MARK: - Foreground Polling

    private func processQueuePeriodically() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(30))

            let pendingCount = OCRQueueService.shared.getPendingCount(in: container.mainContext)
            guard pendingCount > 0 else { continue }

            if await RemoteOCRService.shared.checkAvailability() {
                await OCRQueueService.shared.processQueue(in: container.mainContext)
            }
        }
    }

    // MARK: - Background Task

    private func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.bgTaskID,
            using: nil
        ) { task in
            guard let processingTask = task as? BGProcessingTask else { return }
            self.handleBackgroundProcessing(processingTask)
        }
    }

    private func scheduleBackgroundProcessing() {
        let hasPending = OCRQueueService.shared.getPendingCount(in: container.mainContext) > 0
        guard hasPending else { return }

        let request = BGProcessingTaskRequest(identifier: Self.bgTaskID)
        request.requiresNetworkConnectivity = true
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Background scheduling can fail silently — not critical
        }
    }

    private func handleBackgroundProcessing(_ task: BGProcessingTask) {
        let workTask = Task {
            await OCRQueueService.shared.processQueue(in: container.mainContext)
        }

        task.expirationHandler = {
            workTask.cancel()
        }

        Task {
            await workTask.value
            task.setTaskCompleted(success: true)
            scheduleBackgroundProcessing()
        }
    }

    // MARK: - Tag Deduplication

    private func deduplicateTags(in context: ModelContext) {
        let descriptor = FetchDescriptor<Tag>(sortBy: [SortDescriptor(\.createdAt)])
        guard let tags = try? context.fetch(descriptor) else { return }

        var seen: [String: Tag] = [:]
        for tag in tags {
            let key = tag.name.lowercased()
            if let existing = seen[key] {
                // Move captures from duplicate to the original
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
            // Rename old tags — captures follow automatically via the relationship
            let renames = ["Note": "Project", "Document": "Reference", "Travel": "Ticket", "Inspiration": "To-Do"]
            for tag in existing {
                if let newName = renames[tag.name] {
                    tag.name = newName
                }
            }

            // Add any missing default tags
            let existingNames = Set(existing.map(\.name)).union(renames.values)
            for tag in Tag.defaults where !existingNames.contains(tag.name) {
                context.insert(Tag(name: tag.name, colorHex: tag.hex))
            }

            // Sync colors to latest defaults
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
