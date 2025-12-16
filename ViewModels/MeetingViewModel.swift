//
//  MeetingViewModel.swift
//  QuillStack
//
//  Created on 2025-12-10.
//

import SwiftUI
import CoreData
import Combine

@MainActor
class MeetingViewModel: ObservableObject {
    @Published private(set) var meetings: [Meeting] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let context = CoreDataStack.shared.persistentContainer.viewContext
    private var cancellables = Set<AnyCancellable>()

    init() {
        fetchMeetings()
        observeChanges()
    }

    func fetchMeetings() {
        isLoading = true

        let fetchRequest = NSFetchRequest<Meeting>(entityName: "Meeting")
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(key: "meetingDate", ascending: false),
            NSSortDescriptor(key: "createdAt", ascending: false)
        ]

        do {
            meetings = try context.fetch(fetchRequest)
            isLoading = false
        } catch {
            errorMessage = "Failed to load meetings: \(error.localizedDescription)"
            isLoading = false
        }
    }

    func deleteMeeting(_ meeting: Meeting) {
        context.delete(meeting)

        do {
            try CoreDataStack.shared.saveViewContext()
            fetchMeetings()
        } catch {
            errorMessage = "Failed to delete meeting: \(error.localizedDescription)"
        }
    }

    private func observeChanges() {
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.fetchMeetings()
            }
            .store(in: &cancellables)
    }
}
