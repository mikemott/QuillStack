//
//  ImageRetentionService.swift
//  QuillStack
//
//  Manages image retention policy and cleanup of original images.
//

import Foundation
import CoreData
import os.log

// MARK: - Image Retention Service

/// Manages the lifecycle of original images based on user-defined retention policies.
/// Preserves thumbnails for UI display while removing full-resolution originals.
@MainActor
final class ImageRetentionService {
    static let shared = ImageRetentionService()

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "QuillStack", category: "ImageRetention")

    private let context: NSManagedObjectContext

    private init() {
        self.context = CoreDataStack.shared.persistentContainer.viewContext
    }

    // MARK: - Public API

    /// Processes a note after OCR completion, applying the current retention policy
    /// - Parameter note: The note that just completed OCR processing
    func processAfterOCR(note: Note) async {
        let settings = SettingsManager.shared

        switch settings.imageRetentionPolicy {
        case .deleteAfterOCR:
            await clearOriginalImages(for: note)
            Self.logger.info("Cleared original images after OCR for note")

        case .deleteAfterDays:
            // Schedule for later deletion - handled by periodic cleanup
            Self.logger.debug("Note will be cleaned up after \(settings.imageRetentionDays) days")

        case .deleteAfterExport, .keepForever:
            // No action needed after OCR
            break
        }
    }

    /// Processes a note after export, applying the current retention policy
    /// - Parameter note: The note that was just exported
    func processAfterExport(note: Note) async {
        let settings = SettingsManager.shared

        if settings.imageRetentionPolicy == .deleteAfterExport {
            await clearOriginalImages(for: note)
            Self.logger.info("Cleared original images after export for note")
        }
    }

    /// Performs periodic cleanup of images based on retention days
    /// Should be called on app launch or periodically
    func performScheduledCleanup() async {
        let settings = SettingsManager.shared

        guard settings.imageRetentionPolicy == .deleteAfterDays else { return }

        let retentionDays = settings.imageRetentionDays
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date())!

        let cleaned = await cleanupNotesOlderThan(cutoffDate)
        if cleaned > 0 {
            Self.logger.info("Cleaned up original images from \(cleaned) notes older than \(retentionDays) days")
        }
    }

    /// Manually clears original images for a specific note
    /// - Parameter note: The note to clear images from
    func clearOriginalImages(for note: Note) async {
        await context.perform {
            // Clear single-page image
            if note.originalImageData != nil {
                note.originalImageData = nil
            }

            // Clear multi-page images
            if let pages = note.pages as? Set<NotePage> {
                for page in pages {
                    if page.imageData != nil {
                        page.imageData = nil
                    }
                }
            }

            note.updatedAt = Date()

            do {
                try self.context.save()
            } catch {
                Self.logger.error("Failed to clear original images: \(error.localizedDescription)")
            }
        }
    }

    /// Clears original images for all notes (bulk operation)
    /// - Returns: Number of notes processed
    @discardableResult
    func clearAllOriginalImages() async -> Int {
        return await context.perform {
            let noteRequest = NSFetchRequest<Note>(entityName: "Note")
            noteRequest.predicate = NSPredicate(format: "originalImageData != nil")

            let pageRequest = NSFetchRequest<NotePage>(entityName: "NotePage")
            pageRequest.predicate = NSPredicate(format: "imageData != nil")

            var count = 0

            do {
                let notes = try self.context.fetch(noteRequest)
                for note in notes {
                    note.originalImageData = nil
                    note.updatedAt = Date()
                    count += 1
                }

                let pages = try self.context.fetch(pageRequest)
                for page in pages {
                    page.imageData = nil
                }

                try self.context.save()
                Self.logger.info("Cleared original images from \(count) notes and \(pages.count) pages")
            } catch {
                Self.logger.error("Failed to clear all original images: \(error.localizedDescription)")
            }

            return count
        }
    }

    /// Calculates storage used by original images
    /// - Returns: Total bytes used by original images
    func calculateStorageUsed() async -> Int64 {
        return await context.perform {
            var totalBytes: Int64 = 0

            // Count Note.originalImageData
            let noteRequest = NSFetchRequest<Note>(entityName: "Note")
            noteRequest.predicate = NSPredicate(format: "originalImageData != nil")
            noteRequest.propertiesToFetch = ["originalImageData"]

            do {
                let notes = try self.context.fetch(noteRequest)
                for note in notes {
                    if let data = note.originalImageData {
                        totalBytes += Int64(data.count)
                    }
                }
            } catch {
                Self.logger.error("Failed to calculate note storage: \(error.localizedDescription)")
            }

            // Count NotePage.imageData
            let pageRequest = NSFetchRequest<NotePage>(entityName: "NotePage")
            pageRequest.predicate = NSPredicate(format: "imageData != nil")
            pageRequest.propertiesToFetch = ["imageData"]

            do {
                let pages = try self.context.fetch(pageRequest)
                for page in pages {
                    if let data = page.imageData {
                        totalBytes += Int64(data.count)
                    }
                }
            } catch {
                Self.logger.error("Failed to calculate page storage: \(error.localizedDescription)")
            }

            return totalBytes
        }
    }

    /// Returns the count of notes with original images
    func notesWithImagesCount() async -> Int {
        return await context.perform {
            let noteRequest = NSFetchRequest<Note>(entityName: "Note")
            noteRequest.predicate = NSPredicate(format: "originalImageData != nil")

            do {
                return try self.context.count(for: noteRequest)
            } catch {
                return 0
            }
        }
    }

    // MARK: - Private Helpers

    /// Cleans up notes older than the specified date
    private func cleanupNotesOlderThan(_ date: Date) async -> Int {
        return await context.perform {
            let request = NSFetchRequest<Note>(entityName: "Note")
            request.predicate = NSPredicate(
                format: "createdAt < %@ AND (originalImageData != nil)",
                date as CVarArg
            )

            var count = 0

            do {
                let notes = try self.context.fetch(request)
                for note in notes {
                    note.originalImageData = nil
                    note.updatedAt = Date()

                    // Also clear pages
                    if let pages = note.pages as? Set<NotePage> {
                        for page in pages {
                            page.imageData = nil
                        }
                    }

                    count += 1
                }

                if count > 0 {
                    try self.context.save()
                }
            } catch {
                Self.logger.error("Failed to cleanup old images: \(error.localizedDescription)")
            }

            return count
        }
    }
}

// MARK: - Formatting Helpers

extension ImageRetentionService {
    /// Formats bytes as human-readable storage size
    static func formatStorageSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
