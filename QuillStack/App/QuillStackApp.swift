import SwiftUI
import SwiftData
import BackgroundTasks

@main
struct QuillStackApp: App {
    @Environment(\.scenePhase) private var scenePhase

    let container: ModelContainer

    private static let bgTaskID = "com.quillstack.ocr-queue-processing"

    init() {
        CrashReporting.start()
        let schema = Schema([Capture.self, CaptureImage.self, Tag.self, PendingOCRRequest.self])
        let config = ModelConfiguration("QuillStack", isStoredInMemoryOnly: false)
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        seedDefaultTags(in: container)
        configureMacMini()
        registerBackgroundTask()
    }

    private func configureMacMini() {
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
            let renames = ["Note": "Project", "Document": "Reference", "Travel": "Ticket"]
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
