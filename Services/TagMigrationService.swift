//
//  TagMigrationService.swift
//  QuillStack
//
//  Phase 4.3 - Architecture refactoring: tag migration from strings to entities.
//  Migrates existing comma-separated tag strings to proper Tag Core Data entities.
//

import Foundation
import CoreData
import os.log

/// Service for migrating tags from comma-separated strings to Tag entities.
/// Call `migrateIfNeeded()` on app launch to ensure migration is performed.
@MainActor
final class TagMigrationService {

    // MARK: - Constants

    private static let migrationCompletedKey = "tagMigrationCompleted"
    private static let migrationVersionKey = "tagMigrationVersion"
    private static let currentMigrationVersion = 1

    // MARK: - Logging

    private let logger = Logger(subsystem: "com.quillstack", category: "TagMigration")

    // MARK: - Singleton

    static let shared = TagMigrationService()

    private init() {}

    // MARK: - Migration Status

    /// Whether the migration has been completed
    var isMigrationCompleted: Bool {
        UserDefaults.standard.bool(forKey: Self.migrationCompletedKey) &&
        UserDefaults.standard.integer(forKey: Self.migrationVersionKey) >= Self.currentMigrationVersion
    }

    /// Reset migration status (for testing or re-migration)
    func resetMigrationStatus() {
        UserDefaults.standard.removeObject(forKey: Self.migrationCompletedKey)
        UserDefaults.standard.removeObject(forKey: Self.migrationVersionKey)
        logger.info("Migration status reset")
    }

    // MARK: - Migration

    /// Migrate tags if not already migrated.
    /// - Parameter context: The managed object context to use
    /// - Returns: Migration result with statistics
    @discardableResult
    func migrateIfNeeded(context: NSManagedObjectContext) async throws -> MigrationResult {
        // Check if migration already done
        guard !isMigrationCompleted else {
            logger.debug("Tag migration already completed, skipping")
            return MigrationResult(skipped: true)
        }

        logger.info("Starting tag migration...")
        let startTime = Date()

        // Perform migration
        let result = try await performMigration(context: context)

        // Mark as completed
        UserDefaults.standard.set(true, forKey: Self.migrationCompletedKey)
        UserDefaults.standard.set(Self.currentMigrationVersion, forKey: Self.migrationVersionKey)

        let duration = Date().timeIntervalSince(startTime)
        logger.info("Tag migration completed in \(String(format: "%.2f", duration))s: \(result.notesProcessed) notes, \(result.tagsCreated) tags")

        return result
    }

    /// Force migration regardless of completion status.
    /// - Parameter context: The managed object context to use
    /// - Returns: Migration result with statistics
    @discardableResult
    func forceMigrate(context: NSManagedObjectContext) async throws -> MigrationResult {
        resetMigrationStatus()
        return try await migrateIfNeeded(context: context)
    }

    // MARK: - Private Migration Logic

    private func performMigration(context: NSManagedObjectContext) async throws -> MigrationResult {
        var result = MigrationResult()

        // Fetch all notes with non-empty tags
        let request = NSFetchRequest<Note>(entityName: "Note")
        request.predicate = NSPredicate(format: "tags != nil AND tags != ''")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Note.createdAt, ascending: true)]

        let notes: [Note]
        do {
            notes = try context.fetch(request)
        } catch {
            logger.error("Failed to fetch notes: \(error.localizedDescription)")
            throw MigrationError.fetchFailed(underlying: error)
        }

        if notes.isEmpty {
            logger.info("No notes with tags to migrate")
            return result
        }

        logger.info("Found \(notes.count) notes with tags to migrate")

        // Build tag map for deduplication
        var tagMap: [String: Tag] = [:]

        // First, load existing tags
        let existingTags = try loadExistingTags(context: context)
        for tag in existingTags {
            tagMap[tag.name.lowercased()] = tag
        }
        logger.debug("Loaded \(existingTags.count) existing tags")

        // Process each note
        for note in notes {
            guard let tagsString = note.tags, !tagsString.isEmpty else {
                continue
            }

            let tagNames = parseTagString(tagsString)

            for name in tagNames {
                let normalizedName = name.lowercased()

                // Get or create tag
                let tag: Tag
                if let existing = tagMap[normalizedName] {
                    tag = existing
                } else {
                    tag = Tag.create(in: context, name: name)
                    tagMap[normalizedName] = tag
                    result.tagsCreated += 1
                }

                // Add relationship if not already present
                if !(note.tagEntities?.contains(tag) ?? false) {
                    note.addToTagEntities(tag)
                    result.relationshipsCreated += 1
                }
            }

            result.notesProcessed += 1
        }

        // Save changes
        if context.hasChanges {
            do {
                try context.save()
                logger.debug("Saved migration changes")
            } catch {
                logger.error("Failed to save migration: \(error.localizedDescription)")
                throw MigrationError.saveFailed(underlying: error)
            }
        }

        return result
    }

    private func loadExistingTags(context: NSManagedObjectContext) throws -> [Tag] {
        let request = NSFetchRequest<Tag>(entityName: "Tag")
        return try context.fetch(request)
    }

    private func parseTagString(_ string: String) -> [String] {
        string
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Sync Tags String

    /// Sync the legacy tags string from Tag entities.
    /// Use this to keep the string field in sync for backwards compatibility.
    /// - Parameter note: The note to sync
    func syncTagsString(for note: Note) {
        let tagNames = note.tagEntityNames
        note.tags = tagNames.isEmpty ? nil : tagNames.joined(separator: ", ")
    }

    /// Sync tag entities from the legacy tags string.
    /// Use this when the string is modified directly.
    /// - Parameters:
    ///   - note: The note to sync
    ///   - context: The managed object context
    func syncTagEntities(for note: Note, context: NSManagedObjectContext) {
        guard let tagsString = note.tags else {
            // Clear tag entities if string is empty
            if let existingTags = note.tagEntities, !existingTags.isEmpty {
                note.removeFromTagEntities(existingTags)
            }
            return
        }

        let tagNames = Set(parseTagString(tagsString).map { $0.lowercased() })
        let existingTags = note.tagEntities ?? []
        let existingNames = Set(existingTags.map { $0.name.lowercased() })

        // Remove tags not in string
        for tag in existingTags {
            if !tagNames.contains(tag.name.lowercased()) {
                note.removeFromTagEntities(tag)
            }
        }

        // Add tags from string
        for name in parseTagString(tagsString) {
            if !existingNames.contains(name.lowercased()) {
                let tag = Tag.findOrCreate(name: name, in: context)
                note.addToTagEntities(tag)
            }
        }
    }
}

// MARK: - Migration Result

/// Result of a tag migration operation.
struct MigrationResult: Sendable {
    /// Number of notes processed
    var notesProcessed: Int = 0

    /// Number of new Tag entities created
    var tagsCreated: Int = 0

    /// Number of note-tag relationships created
    var relationshipsCreated: Int = 0

    /// Whether migration was skipped (already completed)
    var skipped: Bool = false

    /// Summary description
    var summary: String {
        if skipped {
            return "Migration skipped (already completed)"
        }
        return "Processed \(notesProcessed) notes, created \(tagsCreated) tags, \(relationshipsCreated) relationships"
    }
}

// MARK: - Migration Error

/// Errors that can occur during tag migration.
enum MigrationError: Error, LocalizedError {
    case fetchFailed(underlying: Error)
    case saveFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .fetchFailed(let underlying):
            return "Failed to fetch notes for migration: \(underlying.localizedDescription)"
        case .saveFailed(let underlying):
            return "Failed to save migration changes: \(underlying.localizedDescription)"
        }
    }
}

// MARK: - App Integration

extension TagMigrationService {
    /// Convenience method for app launch migration.
    /// Call this in your App's onAppear or task modifier.
    static func performAppLaunchMigration() async {
        let context = await CoreDataStack.shared.persistentContainer.viewContext
        do {
            try await shared.migrateIfNeeded(context: context)
        } catch {
            // Log but don't crash - migration is not critical
            Logger(subsystem: "com.quillstack", category: "TagMigration")
                .error("Tag migration failed: \(error.localizedDescription)")
        }
    }
}
