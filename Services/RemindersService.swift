//
//  RemindersService.swift
//  QuillStack
//
//  Created on 2025-12-18.
//

import Foundation
import EventKit
import os.log

// MARK: - Reminders Service

class RemindersService {
    static let shared = RemindersService()

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "QuillStack", category: "Reminders")

    private let eventStore = EKEventStore()

    private init() {}

    // MARK: - Authorization

    enum AuthorizationStatus {
        case authorized
        case denied
        case notDetermined
        case restricted
    }

    var authorizationStatus: AuthorizationStatus {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        switch status {
        case .authorized, .fullAccess:
            return .authorized
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .writeOnly:
            return .authorized // Write-only is sufficient for our needs
        @unknown default:
            return .denied
        }
    }

    func requestAccess() async -> Bool {
        do {
            // iOS 17+ uses requestFullAccessToReminders()
            if #available(iOS 17.0, *) {
                return try await eventStore.requestFullAccessToReminders()
            } else {
                return try await eventStore.requestAccess(to: .reminder)
            }
        } catch {
            Self.logger.error("Reminders access request failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Reminder Lists

    /// Get all available reminder lists
    func getReminderLists() -> [EKCalendar] {
        return eventStore.calendars(for: .reminder)
    }

    /// Get the default reminder list
    func getDefaultReminderList() -> EKCalendar? {
        return eventStore.defaultCalendarForNewReminders()
    }

    // MARK: - Export Tasks

    /// Export a single task to Reminders
    func exportTask(_ task: ParsedTask, toList list: EKCalendar) async throws -> String {
        let reminder = EKReminder(eventStore: eventStore)
        reminder.calendar = list
        reminder.title = task.text
        reminder.isCompleted = task.isCompleted

        try eventStore.save(reminder, commit: true)
        return reminder.calendarItemIdentifier
    }

    /// Export a TodoItem to Reminders
    func exportTodoItem(_ item: TodoItem, toList list: EKCalendar) async throws -> String {
        let reminder = EKReminder(eventStore: eventStore)
        reminder.calendar = list
        reminder.title = item.text
        reminder.isCompleted = item.isCompleted

        // Set due date if available
        if let dueDate = item.dueDate {
            let calendar = Calendar.current
            var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
            components.timeZone = TimeZone.current
            reminder.dueDateComponents = components
        }

        // Set priority
        switch item.priority.lowercased() {
        case "high":
            reminder.priority = 1
        case "medium":
            reminder.priority = 5
        default:
            reminder.priority = 0
        }

        try eventStore.save(reminder, commit: true)
        return reminder.calendarItemIdentifier
    }

    /// Export multiple tasks to Reminders
    func exportTasks(_ tasks: [ParsedTask], toList list: EKCalendar) async throws -> [ReminderExportResult] {
        var results: [ReminderExportResult] = []

        for task in tasks {
            do {
                let identifier = try await exportTask(task, toList: list)
                results.append(ReminderExportResult(task: task.text, success: true, identifier: identifier))
            } catch {
                results.append(ReminderExportResult(task: task.text, success: false, error: error.localizedDescription))
            }
        }

        return results
    }

    /// Check if a reminder still exists (for synced items)
    func reminderExists(identifier: String) -> Bool {
        guard let item = eventStore.calendarItem(withIdentifier: identifier) else {
            return false
        }
        return item is EKReminder
    }

    /// Update a reminder's completion status
    func updateReminderCompletion(identifier: String, isCompleted: Bool) throws {
        guard let item = eventStore.calendarItem(withIdentifier: identifier) as? EKReminder else {
            throw RemindersError.reminderNotFound
        }
        item.isCompleted = isCompleted
        try eventStore.save(item, commit: true)
    }

    /// Delete a reminder
    func deleteReminder(identifier: String) throws {
        guard let item = eventStore.calendarItem(withIdentifier: identifier) as? EKReminder else {
            throw RemindersError.reminderNotFound
        }
        try eventStore.remove(item, commit: true)
    }
}

// MARK: - Reminder Export Result

struct ReminderExportResult: Identifiable {
    let id = UUID()
    let task: String
    let success: Bool
    var identifier: String?
    var error: String?

    init(task: String, success: Bool, identifier: String? = nil, error: String? = nil) {
        self.task = task
        self.success = success
        self.identifier = identifier
        self.error = error
    }
}

// MARK: - Errors

enum RemindersError: LocalizedError {
    case accessDenied
    case reminderNotFound
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Access to Reminders was denied. Please enable access in Settings."
        case .reminderNotFound:
            return "The reminder could not be found."
        case .exportFailed(let message):
            return "Export failed: \(message)"
        }
    }
}
