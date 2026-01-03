//
//  NotesTimelineProvider.swift
//  QuillStackWidget
//
//  Created on 2026-01-02.
//

import WidgetKit
import SwiftUI
import CoreData

struct NotesEntry: TimelineEntry {
    let date: Date
    let recentNotes: [WidgetNote]
    let todayStats: DailyStats
}

struct NotesTimelineProvider: TimelineProvider {
    typealias Entry = NotesEntry

    func placeholder(in context: Context) -> NotesEntry {
        NotesEntry(
            date: Date(),
            recentNotes: placeholderNotes(),
            todayStats: DailyStats(totalNotes: 5, todoCount: 2, meetingCount: 1)
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (NotesEntry) -> Void) {
        let entry = NotesEntry(
            date: Date(),
            recentNotes: context.isPreview ? placeholderNotes() : fetchRecentNotes(),
            todayStats: context.isPreview ? DailyStats(totalNotes: 5, todoCount: 2, meetingCount: 1) : fetchTodayStats()
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NotesEntry>) -> Void) {
        let currentDate = Date()
        let entry = NotesEntry(
            date: currentDate,
            recentNotes: fetchRecentNotes(),
            todayStats: fetchTodayStats()
        )

        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))

        completion(timeline)
    }

    // MARK: - Core Data Fetching

    private func fetchRecentNotes(limit: Int = 8) -> [WidgetNote] {
        guard let container = getSharedContainer() else {
            print("❌ Widget: Failed to get shared container")
            return []
        }

        let context = container.viewContext
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Note")
        fetchRequest.predicate = NSPredicate(format: "isArchived == NO")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        fetchRequest.fetchLimit = limit

        do {
            let results = try context.fetch(fetchRequest)
            let notes = results.compactMap { object -> WidgetNote? in
                guard let id = object.value(forKey: "id") as? UUID,
                      let content = object.value(forKey: "content") as? String,
                      let noteType = object.value(forKey: "noteType") as? String,
                      let createdAt = object.value(forKey: "createdAt") as? Date else {
                    return nil
                }

                return WidgetNote(
                    id: id,
                    content: content,
                    noteType: noteType,
                    createdAt: createdAt
                )
            }

            print("📊 Widget: Fetched \(notes.count) notes")
            return notes
        } catch {
            print("❌ Widget: Failed to fetch notes: \(error)")
            return []
        }
    }

    private func fetchTodayStats() -> DailyStats {
        guard let container = getSharedContainer() else {
            return DailyStats(totalNotes: 0, todoCount: 0, meetingCount: 0)
        }

        let context = container.viewContext
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())

        // Total notes today
        let totalFetch = NSFetchRequest<NSManagedObject>(entityName: "Note")
        totalFetch.predicate = NSPredicate(
            format: "isArchived == NO AND createdAt >= %@",
            startOfDay as NSDate
        )

        // Todo count
        let todoFetch = NSFetchRequest<NSManagedObject>(entityName: "Note")
        todoFetch.predicate = NSPredicate(
            format: "isArchived == NO AND createdAt >= %@ AND noteType == %@",
            startOfDay as NSDate,
            "todo"
        )

        // Meeting count
        let meetingFetch = NSFetchRequest<NSManagedObject>(entityName: "Note")
        meetingFetch.predicate = NSPredicate(
            format: "isArchived == NO AND createdAt >= %@ AND noteType == %@",
            startOfDay as NSDate,
            "meeting"
        )

        do {
            let totalCount = try context.count(for: totalFetch)
            let todoCount = try context.count(for: todoFetch)
            let meetingCount = try context.count(for: meetingFetch)

            return DailyStats(
                totalNotes: totalCount,
                todoCount: todoCount,
                meetingCount: meetingCount
            )
        } catch {
            print("❌ Widget: Failed to fetch stats: \(error)")
            return DailyStats(totalNotes: 0, todoCount: 0, meetingCount: 0)
        }
    }

    private func getSharedContainer() -> NSPersistentContainer? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.quillstack.app.shared"
        ) else {
            print("❌ Widget: Failed to get App Group container URL")
            return nil
        }

        let storeURL = containerURL.appendingPathComponent("QuillStack.sqlite")

        let container = NSPersistentContainer(name: "QuillStack")
        let description = NSPersistentStoreDescription(url: storeURL)
        description.setOption(true as NSNumber, forKey: NSReadOnlyPersistentStoreOption)
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            if let error = error {
                loadError = error
                print("❌ Widget: Failed to load Core Data store: \(error)")
            } else {
                print("✅ Widget: Loaded shared Core Data store at \(storeURL.path)")
            }
        }

        return loadError == nil ? container : nil
    }

    // MARK: - Placeholder Data

    private func placeholderNotes() -> [WidgetNote] {
        [
            WidgetNote(
                id: UUID(),
                content: "Meeting with Sarah about Q1 planning",
                noteType: "meeting",
                createdAt: Date().addingTimeInterval(-120)
            ),
            WidgetNote(
                id: UUID(),
                content: "Buy groceries: milk, eggs, bread",
                noteType: "todo",
                createdAt: Date().addingTimeInterval(-900)
            ),
            WidgetNote(
                id: UUID(),
                content: "App idea: fitness tracker with AI coaching",
                noteType: "idea",
                createdAt: Date().addingTimeInterval(-3600)
            )
        ]
    }
}
