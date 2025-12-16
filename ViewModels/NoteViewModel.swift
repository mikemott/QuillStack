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
        observeChanges()
    }

    func fetchNotes() {
        isLoading = true

        let fetchRequest = NSFetchRequest<Note>(entityName: "Note")
        fetchRequest.predicate = NSPredicate(format: "isArchived == NO")
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(key: "createdAt", ascending: false)
        ]

        do {
            notes = try context.fetch(fetchRequest)
            isLoading = false
        } catch {
            errorMessage = "Failed to load notes: \(error.localizedDescription)"
            isLoading = false
        }
    }

    func deleteNotes(at offsets: IndexSet) {
        offsets.forEach { index in
            let note = notes[index]
            context.delete(note)
        }

        do {
            try CoreDataStack.shared.saveViewContext()
            fetchNotes()
        } catch {
            errorMessage = "Failed to delete note: \(error.localizedDescription)"
        }
    }

    func deleteNote(_ note: Note) {
        context.delete(note)

        do {
            try CoreDataStack.shared.saveViewContext()
            fetchNotes()
        } catch {
            errorMessage = "Failed to delete note: \(error.localizedDescription)"
        }
    }

    func archiveNote(_ note: Note) {
        note.isArchived = true
        note.updatedAt = Date()

        do {
            try CoreDataStack.shared.saveViewContext()
            fetchNotes()
        } catch {
            errorMessage = "Failed to archive note: \(error.localizedDescription)"
        }
    }

    private func observeChanges() {
        // Observe Core Data changes
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.fetchNotes()
            }
            .store(in: &cancellables)
    }
}
