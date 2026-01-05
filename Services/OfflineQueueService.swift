//
//  OfflineQueueService.swift
//  QuillStack
//
//  Created on 2025-12-30.
//

import Foundation
import Network
import CoreData
import Combine
import os.log

// MARK: - Offline Queue Service

/// Manages offline queuing of LLM enhancement requests
/// When offline, requests are stored in Core Data and processed when connectivity returns
@MainActor
@Observable
final class OfflineQueueService {
    static let shared = OfflineQueueService()

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "QuillStack", category: "OfflineQueue")

    private(set) var pendingCount: Int = 0
    private(set) var isOnline: Bool = true
    private(set) var isProcessing: Bool = false

    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "network.monitor.queue")
    private var isMonitoring = false

    // Retry configuration
    private let maxRetries: Int16 = 3
    private let retryDelaySeconds: [Double] = [5, 30, 120]  // Exponential backoff

    private init() {
        startNetworkMonitoring()
        Task {
            await refreshPendingCount()
        }
    }

    // MARK: - Network Monitoring

    private func startNetworkMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self else { return }
                let wasOffline = !self.isOnline
                self.isOnline = path.status == .satisfied

                // If we just came online, process the queue
                if wasOffline && self.isOnline {
                    Self.logger.info("Network restored - processing offline queue")
                    await self.processQueue()
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }

    private func stopNetworkMonitoring() {
        monitor.cancel()
        isMonitoring = false
    }

    // MARK: - Queue Management

    /// Enqueues an enhancement request to be processed when online
    func enqueue(noteId: UUID, text: String, noteType: String) async {
        let context = CoreDataStack.shared.newBackgroundContext()

        await context.perform {
            let queuedItem = NSEntityDescription.insertNewObject(
                forEntityName: "QueuedEnhancement",
                into: context
            )

            queuedItem.setValue(UUID(), forKey: "id")
            queuedItem.setValue(noteId, forKey: "noteId")
            queuedItem.setValue(text, forKey: "originalText")
            queuedItem.setValue(noteType, forKey: "noteType")
            queuedItem.setValue(Date(), forKey: "createdAt")
            queuedItem.setValue("pending", forKey: "status")
            queuedItem.setValue(Int16(0), forKey: "retryCount")

            do {
                try context.save()
                Self.logger.info("Queued enhancement for note \(noteId.uuidString, privacy: .private)")
            } catch {
                Self.logger.error("Failed to queue enhancement: \(error.localizedDescription)")
            }
        }

        await refreshPendingCount()

        // If we're online, try to process immediately
        if isOnline {
            await processQueue()
        }
    }

    /// Processes all pending items in the queue
    func processQueue() async {
        guard isOnline && !isProcessing else { return }
        isProcessing = true

        defer {
            Task { @MainActor in
                self.isProcessing = false
            }
        }

        let context = CoreDataStack.shared.newBackgroundContext()

        // Fetch pending items
        let pendingItems = await fetchPendingItems(in: context)

        for item in pendingItems {
            guard isOnline else {
                Self.logger.info("Lost connectivity - pausing queue processing")
                break
            }

            await processItem(item, in: context)
        }

        await refreshPendingCount()
    }

    /// Checks if a note has a pending enhancement in the queue
    func hasPendingEnhancement(for noteId: UUID) async -> Bool {
        let context = CoreDataStack.shared.persistentContainer.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: "QueuedEnhancement")
        request.predicate = NSPredicate(
            format: "noteId == %@ AND (status == %@ OR status == %@)",
            noteId as CVarArg, "pending", "processing"
        )
        request.fetchLimit = 1

        do {
            let count = try context.count(for: request)
            return count > 0
        } catch {
            return false
        }
    }

    // MARK: - Private Helpers

    private func fetchPendingItems(in context: NSManagedObjectContext) async -> [NSManagedObject] {
        await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "QueuedEnhancement")
            request.predicate = NSPredicate(format: "status == %@", "pending")
            request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]

            do {
                return try context.fetch(request)
            } catch {
                Self.logger.error("Failed to fetch pending items: \(error.localizedDescription)")
                return []
            }
        }
    }

    private func processItem(_ item: NSManagedObject, in context: NSManagedObjectContext) async {
        guard let noteId = item.value(forKey: "noteId") as? UUID,
              let originalText = item.value(forKey: "originalText") as? String,
              let noteType = item.value(forKey: "noteType") as? String else {
            await markItemFailed(item, in: context)
            return
        }

        // Mark as processing
        await context.perform {
            item.setValue("processing", forKey: "status")
            item.setValue(Date(), forKey: "lastAttemptAt")
            try? context.save()
        }

        Self.logger.info("Processing queued enhancement for note \(noteId.uuidString, privacy: .private)")

        do {
            // Call LLM service
            let result = try await LLMService.shared.enhanceOCRText(originalText, noteType: noteType)

            // Update the note with enhanced text
            await updateNote(noteId: noteId, with: result.enhancedText)

            // Remove from queue (success)
            await context.perform {
                context.delete(item)
                try? context.save()
            }

            Self.logger.info("Successfully processed queued enhancement for note \(noteId.uuidString, privacy: .private)")

        } catch {
            Self.logger.warning("Enhancement failed for note \(noteId.uuidString, privacy: .private): \(error.localizedDescription)")
            await handleRetry(item, in: context, error: error)
        }
    }

    private func updateNote(noteId: UUID, with enhancedText: String) async {
        let context = CoreDataStack.shared.newBackgroundContext()

        await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "Note")
            request.predicate = NSPredicate(format: "id == %@", noteId as CVarArg)
            request.fetchLimit = 1

            do {
                if let note = try context.fetch(request).first {
                    note.setValue(enhancedText, forKey: "content")
                    note.setValue(Date(), forKey: "updatedAt")
                    try context.save()

                    // Post notification for UI refresh
                    Task { @MainActor in
                        NotificationCenter.default.post(
                            name: NSNotification.Name("NoteEnhancementCompleted"),
                            object: nil,
                            userInfo: ["noteId": noteId]
                        )
                    }
                }
            } catch {
                Self.logger.error("Failed to update note: \(error.localizedDescription)")
            }
        }
    }

    private func handleRetry(_ item: NSManagedObject, in context: NSManagedObjectContext, error: Error) async {
        await context.perform {
            let currentRetries = item.value(forKey: "retryCount") as? Int16 ?? 0

            if currentRetries < self.maxRetries {
                // Schedule retry
                item.setValue(currentRetries + 1, forKey: "retryCount")
                item.setValue("pending", forKey: "status")
                try? context.save()
                Self.logger.info("Will retry enhancement (attempt \(currentRetries + 1)/\(self.maxRetries))")
            } else {
                // Max retries exceeded - mark as failed
                item.setValue("failed", forKey: "status")
                try? context.save()
                Self.logger.error("Max retries exceeded - marking enhancement as failed")
            }
        }
    }

    private func markItemFailed(_ item: NSManagedObject, in context: NSManagedObjectContext) async {
        await context.perform {
            item.setValue("failed", forKey: "status")
            try? context.save()
        }
    }

    private func refreshPendingCount() async {
        let context = CoreDataStack.shared.persistentContainer.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: "QueuedEnhancement")
        request.predicate = NSPredicate(format: "status == %@ OR status == %@", "pending", "processing")

        do {
            let count = try context.count(for: request)
            self.pendingCount = count
        } catch {
            self.pendingCount = 0
        }
    }

    /// Retries all failed items (can be called from UI)
    func retryFailed() async {
        let context = CoreDataStack.shared.newBackgroundContext()

        await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "QueuedEnhancement")
            request.predicate = NSPredicate(format: "status == %@", "failed")

            do {
                let failedItems = try context.fetch(request)
                for item in failedItems {
                    item.setValue("pending", forKey: "status")
                    item.setValue(Int16(0), forKey: "retryCount")
                }
                try context.save()
                Self.logger.info("Reset \(failedItems.count) failed items for retry")
            } catch {
                Self.logger.error("Failed to reset failed items: \(error.localizedDescription)")
            }
        }

        await refreshPendingCount()

        if isOnline {
            await processQueue()
        }
    }

    /// Clears all items from the queue (for testing/debugging)
    func clearQueue() async {
        let context = CoreDataStack.shared.newBackgroundContext()

        await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "QueuedEnhancement")

            do {
                let items = try context.fetch(request)
                for item in items {
                    context.delete(item)
                }
                try context.save()
                Self.logger.info("Cleared \(items.count) items from queue")
            } catch {
                Self.logger.error("Failed to clear queue: \(error.localizedDescription)")
            }
        }

        await refreshPendingCount()
    }
}
