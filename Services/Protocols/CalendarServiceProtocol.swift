//
//  CalendarServiceProtocol.swift
//  QuillStack
//
//  Architecture refactoring: protocol abstraction for calendar service.
//  Enables dependency injection and testability for calendar integration.
//

import Foundation
import EventKit

/// Protocol defining calendar service capabilities.
/// Implement this protocol to provide alternative calendar implementations or mocks for testing.
protocol CalendarServiceProtocol: AnyObject, Sendable {
    /// Current authorization status for calendar access
    var authorizationStatus: CalendarService.AuthorizationStatus { get }

    /// Request access to the user's calendar
    /// - Returns: True if access was granted
    func requestAccess() async -> Bool

    /// Get all available calendars
    /// - Returns: Array of EKCalendar objects
    func getCalendars() -> [EKCalendar]

    /// Get the default calendar for new events
    /// - Returns: The default calendar, or nil if none set
    func getDefaultCalendar() -> EKCalendar?

    /// Create a calendar event
    /// - Parameters:
    ///   - title: Event title
    ///   - startDate: Event start date and time
    ///   - duration: Duration in minutes
    ///   - notes: Optional event notes
    ///   - attendees: Optional list of attendee names
    ///   - location: Optional location string
    ///   - calendar: Target calendar to create event in
    /// - Returns: The created event's identifier
    /// - Throws: CalendarError on failure
    func createEvent(
        title: String,
        startDate: Date,
        duration: Int,
        notes: String?,
        attendees: [String]?,
        location: String?,
        calendar: EKCalendar
    ) throws -> String

    /// Create event from Meeting entity
    /// - Parameters:
    ///   - meeting: The meeting to create an event from
    ///   - calendar: Target calendar
    /// - Returns: The created event's identifier
    /// - Throws: CalendarError on failure
    func createEvent(from meeting: Meeting, calendar: EKCalendar) throws -> String

    /// Create event from ExtractedEvent
    /// - Parameters:
    ///   - extractedEvent: The extracted event data
    ///   - calendar: Target calendar to create event in
    /// - Returns: The created event's identifier
    /// - Throws: CalendarError on failure
    func createEvent(from extractedEvent: ExtractedEvent, calendar: EKCalendar) throws -> String

    /// Fetch events within a date range
    /// - Parameters:
    ///   - startDate: Range start
    ///   - endDate: Range end
    /// - Returns: Array of events in the range
    func fetchEvents(from startDate: Date, to endDate: Date) -> [EKEvent]

    /// Fetch upcoming events (next 30 days)
    /// - Returns: Array of upcoming events
    func fetchUpcomingEvents() -> [EKEvent]

    /// Get event by identifier
    /// - Parameter identifier: The event identifier
    /// - Returns: The event, or nil if not found
    func getEvent(identifier: String) -> EKEvent?

    /// Check if an event still exists
    /// - Parameter identifier: The event identifier
    /// - Returns: True if the event exists
    func eventExists(identifier: String) -> Bool

    /// Delete an event
    /// - Parameter identifier: The event identifier
    /// - Throws: CalendarError.eventNotFound if not found
    func deleteEvent(identifier: String) throws

    /// Update event notes
    /// - Parameters:
    ///   - identifier: The event identifier
    ///   - notes: New notes content
    /// - Throws: CalendarError.eventNotFound if not found
    func updateEventNotes(identifier: String, notes: String) throws

    /// Update an existing event
    /// - Parameter event: The modified event to save
    /// - Throws: EventKit error on failure
    func updateEvent(_ event: EKEvent) throws
}
