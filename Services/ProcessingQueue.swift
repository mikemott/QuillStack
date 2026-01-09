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

        await context.perform { [weak self] in
            guard let self = self else { return }

            let request = Note.fetchRequest()
            request.predicate = NSPredicate(
                format: "processingStateRaw == %@",
                NoteProcessingState.pendingEnhancement.rawValue
            )
            request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]

            do {
                let pendingNotes = try self.context.fetch(request)

                // Process each note sequentially
                for note in pendingNotes {
                    Task {
                        await self.processNote(note)
                    }
                }
            } catch {
                print("Error fetching pending notes: \(error)")
            }
        }

        await updatePendingCount()
    }

    /// Process a single note
    private func processNote(_ note: Note) async {
        await context.perform { [weak self] in
            guard let self = self else { return }

            // Update state to processing
            note.processingState = .processing

            do {
                try self.context.save()
            } catch {
                print("Error updating note state to processing: \(error)")
                return
            }
        }

        // Perform LLM enhancement
        do {
            let enhanced = try await llmService.enhanceOCRText(
                note.content,
                noteType: note.noteType
            )

            await context.perform { [weak self] in
                guard let self = self else { return }

                // Update note with enhanced text
                note.content = enhanced.enhancedText
                note.processingState = .enhanced
                note.updatedAt = Date()

                do {
                    try self.context.save()
                } catch {
                    print("Error saving enhanced note: \(error)")
                }
            }
        } catch {
            print("Error enhancing note: \(error)")

            await context.perform { [weak self] in
                guard let self = self else { return }

                // Mark as failed
                note.processingState = .failed

                do {
                    try self.context.save()
                } catch {
                    print("Error updating failed note: \(error)")
                }
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
