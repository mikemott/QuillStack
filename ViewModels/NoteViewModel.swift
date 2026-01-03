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
class NoteViewModel: ObservableObject {
    @Published private(set) var notes: [Note] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let context = CoreDataStack.shared.persistentContainer.viewContext
    private var cancellables = Set<AnyCancellable>()

    init() {
        fetchNotes()
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
            errorMessage = "Failed to load notes: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Delete Operations

    func deleteNotes(at offsets: IndexSet) {
        errorMessage = nil

        // Get notes to delete before modifying array
        let notesToDelete = offsets.map { notes[$0] }
        let objectIDs = notesToDelete.map { $0.objectID }

        // Update local array first (optimistic update)
        notes.remove(atOffsets: offsets)

        // Delete from Core Data on background context
        let backgroundContext = CoreDataStack.shared.newBackgroundContext()
        backgroundContext.perform {
            do {
                // Fetch notes in the background context
                for objectID in objectIDs {
                    if let noteToDelete = try? backgroundContext.existingObject(with: objectID) as? Note {
                        backgroundContext.delete(noteToDelete)
                    }
                }
                try CoreDataStack.shared.save(context: backgroundContext)
            } catch {
                // If background delete fails, restore on main thread
                Task { @MainActor in
                    self.errorMessage = "Failed to delete note: \(error.localizedDescription)"
                    self.fetchNotes() // Restore the notes
                }
            }
        }
    }

    func deleteNote(_ note: Note) {
        errorMessage = nil

        // Get note ID before deleting (needed for background context)
        let noteId = note.id

        // Update local array first (optimistic update)
        notes.removeAll { $0.id == noteId }

        // Delete from Core Data on background context
        let backgroundContext = CoreDataStack.shared.newBackgroundContext()
        backgroundContext.perform {
            do {
                // Fetch the note in the background context
                let noteToDelete = try backgroundContext.existingObject(with: note.objectID) as? Note
                if let noteToDelete = noteToDelete {
                    backgroundContext.delete(noteToDelete)
                    try CoreDataStack.shared.save(context: backgroundContext)
                }
            } catch {
                // If background delete fails, restore on main thread
                Task { @MainActor in
                    self.errorMessage = "Failed to delete note: \(error.localizedDescription)"
                    self.fetchNotes() // Restore the note
                }
            }
        }
    }

    func deleteNotes(_ notesToDelete: Set<Note>) {
        errorMessage = nil

        let idsToDelete = Set(notesToDelete.map { $0.id })
        let objectIDs = notesToDelete.map { $0.objectID }

        // Update local array first (optimistic update)
        notes.removeAll { idsToDelete.contains($0.id) }

        // Delete from Core Data on background context
        let backgroundContext = CoreDataStack.shared.newBackgroundContext()
        backgroundContext.perform {
            do {
                // Fetch notes in the background context
                for objectID in objectIDs {
                    if let noteToDelete = try? backgroundContext.existingObject(with: objectID) as? Note {
                        backgroundContext.delete(noteToDelete)
                    }
                }
                try CoreDataStack.shared.save(context: backgroundContext)
            } catch {
                // If background delete fails, restore on main thread
                Task { @MainActor in
                    self.errorMessage = "Failed to delete notes: \(error.localizedDescription)"
                    self.fetchNotes() // Restore the notes
                }
            }
        }
    }

    // MARK: - Archive Operations

    func archiveNote(_ note: Note) {
        errorMessage = nil

        let noteId = note.id
        let objectID = note.objectID

        // Update local array first (optimistic update)
        notes.removeAll { $0.id == noteId }

        // Update in Core Data on background context
        let backgroundContext = CoreDataStack.shared.newBackgroundContext()
        backgroundContext.perform {
            do {
                if let noteToArchive = try? backgroundContext.existingObject(with: objectID) as? Note {
                    noteToArchive.isArchived = true
                    noteToArchive.updatedAt = Date()
                    try CoreDataStack.shared.save(context: backgroundContext)
                }
            } catch {
                // If background archive fails, restore on main thread
                Task { @MainActor in
                    self.errorMessage = "Failed to archive note: \(error.localizedDescription)"
                    self.fetchNotes() // Restore the note
                }
            }
        }
    }

    func archiveNotes(_ notesToArchive: Set<Note>) {
        errorMessage = nil

        let idsToArchive = Set(notesToArchive.map { $0.id })
        let objectIDs = notesToArchive.map { $0.objectID }

        // Update local array first (optimistic update)
        notes.removeAll { idsToArchive.contains($0.id) }

        // Update in Core Data on background context
        let backgroundContext = CoreDataStack.shared.newBackgroundContext()
        backgroundContext.perform {
            do {
                for objectID in objectIDs {
                    if let noteToArchive = try? backgroundContext.existingObject(with: objectID) as? Note {
                        noteToArchive.isArchived = true
                        noteToArchive.updatedAt = Date()
                    }
                }
                try CoreDataStack.shared.save(context: backgroundContext)
            } catch {
                // If background archive fails, restore on main thread
                Task { @MainActor in
                    self.errorMessage = "Failed to archive notes: \(error.localizedDescription)"
                    self.fetchNotes() // Restore the notes
                }
            }
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
            }
            .store(in: &cancellables)

        // Also observe note creation notifications
        NotificationCenter.default.publisher(for: AppConstants.Notifications.noteCreated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.fetchNotes()
            }
            .store(in: &cancellables)
    }
}
