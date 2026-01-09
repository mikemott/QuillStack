//
//  ProcessingQueue.swift
//  QuillStack
//
//  Created on 2026-01-09.
//

import Foundation
import CoreData
import Observation

/// Manages the queue of notes pending LLM enhancement and processes them when online
@Observable
@MainActor
final class ProcessingQueue {
    /// Shared instance for app-wide access
    static let shared = ProcessingQueue()

    /// Current number of notes pending processing
    private(set) var pendingCount: Int = 0

    /// Whether the queue is currently processing notes
    private(set) var isProcessing: Bool = false

    /// Core Data context for background processing
    private let context: NSManagedObjectContext

    /// LLM service for enhancement
    private let llmService: LLMService

    /// Network monitor for connectivity
    private let networkMonitor: NetworkMonitor

    /// Task for auto-processing when online
    private var autoProcessTask: Task<Void, Never>?

    private init(
        context: NSManagedObjectContext = CoreDataStack.shared.backgroundContext,
        llmService: LLMService = LLMService.shared,
        networkMonitor: NetworkMonitor = NetworkMonitor.shared
    ) {
        self.context = context
        self.llmService = llmService
        self.networkMonitor = networkMonitor

        // Start observing network changes
        setupNetworkObserver()

        // Update pending count
        Task {
            await updatePendingCount()
        }
    }

    /// Set up observer for network connectivity changes
    private func setupNetworkObserver() {
        NotificationCenter.default.addObserver(
            forName: NetworkMonitor.connectivityDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let isConnected = notification.userInfo?["isConnected"] as? Bool,
                  isConnected else { return }

            // When we come online, process pending notes
            Task {
                await self.processAllPending()
            }
        }
    }

    /// Update the count of pending notes
    func updatePendingCount() async {
        await context.perform { [weak self] in
            guard let self = self else { return }

            let request = Note.fetchRequest()
            request.predicate = NSPredicate(
                format: "processingStateRaw == %@",
                NoteProcessingState.pendingEnhancement.rawValue
            )

            do {
                let count = try self.context.count(for: request)
                Task { @MainActor in
                    self.pendingCount = count
                }
            } catch {
                print("Error counting pending notes: \(error)")
            }
        }
    }

    /// Process all pending notes in the queue
    func processAllPending() async {
        // Check if already processing or offline
        guard !isProcessing, networkMonitor.isConnected else { return }

        isProcessing = true
        defer { isProcessing = false }

        // Fetch pending notes
        let noteIDs: [UUID] = await context.perform { [weak self] in
            guard let self = self else { return [] }

            let request = Note.fetchRequest()
            request.predicate = NSPredicate(
                format: "processingStateRaw == %@",
                NoteProcessingState.pendingEnhancement.rawValue
            )
            request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]

            do {
                let pendingNotes = try self.context.fetch(request)
                return pendingNotes.map { $0.id }
            } catch {
                print("Error fetching pending notes: \(error)")
                return []
            }
        }

        // Process each note sequentially (not concurrently) to avoid API call storm
        for noteID in noteIDs {
            // Check if still connected before each note
            guard networkMonitor.isConnected else {
                print("Lost connection, stopping queue processing")
                break
            }
            await processNote(noteID: noteID)
        }

        await updatePendingCount()
    }

    /// Process a single note by ID (thread-safe)
    private func processNote(noteID: UUID) async {
        // Get note content and type in background context
        let noteData: (content: String, noteType: String)? = await context.perform { [weak self] in
            guard let self = self else { return nil }

            let request = Note.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", noteID as CVarArg)
            request.fetchLimit = 1

            guard let note = try? self.context.fetch(request).first else {
                return nil
            }

            // Update state to processing
            note.processingState = .processing
            try? self.context.save()

            return (content: note.content, noteType: note.noteType)
        }

        guard let (content, noteType) = noteData else { return }

        // Perform LLM enhancement (outside CoreData context)
        do {
            let enhanced = try await llmService.enhanceOCRText(content, noteType: noteType)

            // Update note with enhanced text
            await context.perform { [weak self] in
                guard let self = self else { return }

                let request = Note.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", noteID as CVarArg)
                request.fetchLimit = 1

                guard let note = try? self.context.fetch(request).first else { return }

                note.content = enhanced.enhancedText
                note.processingState = .enhanced
                note.updatedAt = Date()
                try? self.context.save()
            }
        } catch {
            print("Error enhancing note: \(error)")

            // Mark as failed
            await context.perform { [weak self] in
                guard let self = self else { return }

                let request = Note.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", noteID as CVarArg)
                request.fetchLimit = 1

                guard let note = try? self.context.fetch(request).first else { return }

                note.processingState = .failed
                try? self.context.save()
            }
        }
    }

    /// Manually retry failed notes
    func retryFailed() async {
        await context.perform { [weak self] in
            guard let self = self else { return }

            let request = Note.fetchRequest()
            request.predicate = NSPredicate(
                format: "processingStateRaw == %@",
                NoteProcessingState.failed.rawValue
            )

            do {
                let failedNotes = try self.context.fetch(request)
                for note in failedNotes {
                    note.processingState = .pendingEnhancement
                }
                try self.context.save()
            } catch {
                print("Error retrying failed notes: \(error)")
            }
        }

        await processAllPending()
    }

    deinit {
        autoProcessTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }
}
