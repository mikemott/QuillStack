//
//  NoteViewModel.swift
//  QuillStack
//
//  Created on 2025-12-10.
//

import SwiftUI
import CoreData
import Combine

@MainActor
@Observable
final class NoteViewModel {
    private(set) var notes: [Note] = []
    private(set) var collections: [SmartCollection] = []
    private(set) var collectionNotes: [String: [Note]] = [:] // Collection ID -> Notes
    private(set) var isLoading = false
    var errorMessage: String?

    private let context = CoreDataStack.shared.persistentContainer.viewContext
    private lazy var collectionGenerator = SmartCollectionGenerator(context: context)
    private var cancellables = Set<AnyCancellable>()

    init() {
        fetchNotes()
        generateSmartCollections()
        observeExternalChanges()
    }

    // MARK: - Fetch

    func fetchNotes() {
        isLoading = true
        errorMessage = nil

        let fetchRequest = NSFetchRequest<Note>(entityName: "Note")
        fetchRequest.predicate = NSPredicate(format: "isArchived == NO")
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(key: "createdAt", ascending: false)
        ]

        do {
            notes = try context.fetch(fetchRequest)
        } catch {
            print("⚠️ NoteViewModel: Failed to fetch notes: \(error)")
            errorMessage = "Unable to load notes. Please try again."
        }

        isLoading = false
    }

    // MARK: - Smart Collections

    func generateSmartCollections() {
        // Generate all collections
        collections = collectionGenerator.generateCollections()

        // Fetch notes for each collection
        collectionNotes = [:]
        for collection in collections {
            let notes = collectionGenerator.fetchNotes(for: collection)
                .compactMap { $0 as? Note }
            collectionNotes[collection.id] = notes
        }
    }

    func notesForCollection(_ collectionId: String) -> [Note] {
        collectionNotes[collectionId] ?? []
    }

    // MARK: - Delete Operations

    func deleteNotes(at offsets: IndexSet) {
        errorMessage = nil

        // Get notes to delete before modifying array
        let notesToDelete = offsets.map { notes[$0] }

        // Update local array first (optimistic update)
        notes.remove(atOffsets: offsets)

        // Delete from Core Data
        for note in notesToDelete {
            context.delete(note)
        }

        do {
            try CoreDataStack.shared.saveViewContext()
        } catch {
            print("⚠️ NoteViewModel: Failed to delete note: \(error)")
            errorMessage = "Unable to delete note. Please try again."
            // Restore on failure
            fetchNotes()
        }
    }

    func deleteNote(_ note: Note) {
        errorMessage = nil

        // Update local array first
        notes.removeAll { $0.id == note.id }

        // Delete from Core Data
        context.delete(note)

        do {
            try CoreDataStack.shared.saveViewContext()
        } catch {
            print("⚠️ NoteViewModel: Failed to delete note: \(error)")
            errorMessage = "Unable to delete note. Please try again."
            fetchNotes()
        }
    }

    func deleteNotes(_ notesToDelete: Set<Note>) {
        errorMessage = nil

        let idsToDelete = Set(notesToDelete.map { $0.id })

        // Update local array first
        notes.removeAll { idsToDelete.contains($0.id) }

        // Delete from Core Data
        for note in notesToDelete {
            context.delete(note)
        }

        do {
            try CoreDataStack.shared.saveViewContext()
        } catch {
            print("⚠️ NoteViewModel: Failed to delete notes: \(error)")
            errorMessage = "Unable to delete notes. Please try again."
            fetchNotes()
        }
    }

    // MARK: - Archive Operations

    func archiveNote(_ note: Note) {
        errorMessage = nil

        // Update local array first
        notes.removeAll { $0.id == note.id }

        // Update in Core Data
        note.isArchived = true
        note.updatedAt = Date()

        do {
            try CoreDataStack.shared.saveViewContext()
        } catch {
            print("⚠️ NoteViewModel: Failed to archive note: \(error)")
            errorMessage = "Unable to archive note. Please try again."
            fetchNotes()
        }
    }

    func archiveNotes(_ notesToArchive: Set<Note>) {
        errorMessage = nil

        let idsToArchive = Set(notesToArchive.map { $0.id })

        // Update local array first
        notes.removeAll { idsToArchive.contains($0.id) }

        // Update in Core Data
        for note in notesToArchive {
            note.isArchived = true
            note.updatedAt = Date()
        }

        do {
            try CoreDataStack.shared.saveViewContext()
        } catch {
            print("⚠️ NoteViewModel: Failed to archive notes: \(error)")
            errorMessage = "Unable to archive notes. Please try again."
            fetchNotes()
        }
    }

    // MARK: - External Change Observation

    private func observeExternalChanges() {
        // Only refetch for changes from other contexts (background saves, sync, etc.)
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                // Only refresh if the save came from a different context
                guard let savedContext = notification.object as? NSManagedObjectContext,
                      savedContext !== self?.context else {
                    return
                }
                self?.fetchNotes()
                self?.generateSmartCollections()
            }
            .store(in: &cancellables)

        // Also observe note creation notifications
        NotificationCenter.default.publisher(for: AppConstants.Notifications.noteCreated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.fetchNotes()
                self?.generateSmartCollections()
            }
            .store(in: &cancellables)
    }
}
