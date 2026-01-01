//
//  RemindersServiceProtocol.swift
//  QuillStack
//
//  Architecture refactoring: protocol abstraction for reminders service.
//  Enables dependency injection and testability for reminders integration.
//

import Foundation
import EventKit

/// Protocol defining reminders service capabilities.
/// Implement this protocol to provide alternative reminders implementations or mocks for testing.
protocol RemindersServiceProtocol: AnyObject, Sendable {
    /// Current authorization status for reminders access
    var authorizationStatus: RemindersService.AuthorizationStatus { get }

    /// Request access to the user's reminders
    /// - Returns: True if access was granted
    func requestAccess() async -> Bool

    /// Get all available reminder lists
    /// - Returns: Array of EKCalendar objects (reminder lists)
    func getReminderLists() -> [EKCalendar]

    /// Get the default reminder list for new reminders
    /// - Returns: The default list, or nil if none set
    func getDefaultReminderList() -> EKCalendar?

    /// Export a single parsed task to Reminders
    /// - Parameters:
    ///   - task: The task to export
    ///   - list: Target reminder list
    /// - Returns: The created reminder's identifier
    /// - Throws: RemindersError on failure
    func exportTask(_ task: ParsedTask, toList list: EKCalendar) async throws -> String

    /// Export a TodoItem to Reminders
    /// - Parameters:
    ///   - item: The TodoItem to export
    ///   - list: Target reminder list
    /// - Returns: The created reminder's identifier
    /// - Throws: RemindersError on failure
    func exportTodoItem(_ item: TodoItem, toList list: EKCalendar) async throws -> String

    /// Export multiple tasks to Reminders
    /// - Parameters:
    ///   - tasks: Array of tasks to export
    ///   - list: Target reminder list
    /// - Returns: Array of export results (success/failure for each)
    /// - Throws: RemindersError on failure
    func exportTasks(_ tasks: [ParsedTask], toList list: EKCalendar) async throws -> [ReminderExportResult]

    /// Check if a reminder still exists
    /// - Parameter identifier: The reminder identifier
    /// - Returns: True if the reminder exists
    func reminderExists(identifier: String) -> Bool

    /// Update a reminder's completion status
    /// - Parameters:
    ///   - identifier: The reminder identifier
    ///   - isCompleted: New completion status
    /// - Throws: RemindersError.reminderNotFound if not found
    func updateReminderCompletion(identifier: String, isCompleted: Bool) throws

    /// Delete a reminder
    /// - Parameter identifier: The reminder identifier
    /// - Throws: RemindersError.reminderNotFound if not found
    func deleteReminder(identifier: String) throws
}
