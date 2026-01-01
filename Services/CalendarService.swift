//
//  CalendarService.swift
//  QuillStack
//
//  Created on 2025-12-18.
//

import Foundation
import EventKit
import os.log

// MARK: - Calendar Service

/// Service for calendar integration via EventKit.
/// Conforms to CalendarServiceProtocol for testability and dependency injection.
final class CalendarService: CalendarServiceProtocol, @unchecked Sendable {
    static let shared = CalendarService()

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "QuillStack", category: "Calendar")

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
        let status = EKEventStore.authorizationStatus(for: .event)
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
            return .authorized // Write-only is sufficient for creating events
        @unknown default:
            return .denied
        }
    }

    func requestAccess() async -> Bool {
        do {
            // iOS 17+ uses requestFullAccessToEvents()
            if #available(iOS 17.0, *) {
                return try await eventStore.requestFullAccessToEvents()
            } else {
                return try await eventStore.requestAccess(to: .event)
            }
        } catch {
            Self.logger.error("Calendar access request failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Calendars

    /// Get all available calendars
    func getCalendars() -> [EKCalendar] {
        return eventStore.calendars(for: .event)
    }

    /// Get the default calendar
    func getDefaultCalendar() -> EKCalendar? {
        return eventStore.defaultCalendarForNewEvents
    }

    // MARK: - Create Event

    /// Create a calendar event from meeting details
    func createEvent(
        title: String,
        startDate: Date,
        duration: Int, // in minutes
        notes: String?,
        attendees: [String]?,
        location: String?,
        calendar: EKCalendar
    ) throws -> String {
        let event = EKEvent(eventStore: eventStore)
        event.calendar = calendar
        event.title = title
        event.startDate = startDate
        event.endDate = Calendar.current.date(byAdding: .minute, value: duration, to: startDate) ?? startDate
        event.notes = notes
        event.location = location

        // Add attendees as notes if provided (full attendee support requires email addresses)
        if let attendeeList = attendees, !attendeeList.isEmpty {
            let attendeeText = "Attendees: " + attendeeList.joined(separator: ", ")
            if let existingNotes = event.notes {
                event.notes = attendeeText + "\n\n" + existingNotes
            } else {
                event.notes = attendeeText
            }
        }

        try eventStore.save(event, span: .thisEvent)
        return event.eventIdentifier
    }

    /// Create event from Meeting entity
    func createEvent(from meeting: Meeting, calendar: EKCalendar) throws -> String {
        let startDate = meeting.meetingDate ?? Date()
        let duration = Int(meeting.duration)
        var notes: String?

        // Build notes from meeting content
        var notesParts: [String] = []
        if let agenda = meeting.agenda, !agenda.isEmpty {
            notesParts.append("Agenda:\n\(agenda)")
        }
        if let actionItems = meeting.actionItems, !actionItems.isEmpty {
            notesParts.append("Action Items:\n\(actionItems)")
        }
        if !notesParts.isEmpty {
            notes = notesParts.joined(separator: "\n\n")
        }

        return try createEvent(
            title: meeting.title,
            startDate: startDate,
            duration: duration,
            notes: notes,
            attendees: meeting.attendeesList,
            location: nil,
            calendar: calendar
        )
    }

    // MARK: - Fetch Events

    /// Fetch events for a date range
    func fetchEvents(from startDate: Date, to endDate: Date) -> [EKEvent] {
        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: nil
        )
        return eventStore.events(matching: predicate)
    }

    /// Fetch upcoming events (next 30 days)
    func fetchUpcomingEvents() -> [EKEvent] {
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: 30, to: startDate) ?? startDate
        return fetchEvents(from: startDate, to: endDate)
    }

    /// Get event by identifier
    func getEvent(identifier: String) -> EKEvent? {
        return eventStore.event(withIdentifier: identifier)
    }

    // MARK: - Link/Unlink

    /// Check if an event still exists
    func eventExists(identifier: String) -> Bool {
        return getEvent(identifier: identifier) != nil
    }

    /// Delete an event
    func deleteEvent(identifier: String) throws {
        guard let event = getEvent(identifier: identifier) else {
            throw CalendarError.eventNotFound
        }
        try eventStore.remove(event, span: .thisEvent)
    }

    /// Update event notes
    func updateEventNotes(identifier: String, notes: String) throws {
        guard let event = getEvent(identifier: identifier) else {
            throw CalendarError.eventNotFound
        }
        event.notes = notes
        try eventStore.save(event, span: .thisEvent)
    }

    /// Update an existing event (saves any modifications made to the event object)
    func updateEvent(_ event: EKEvent) throws {
        try eventStore.save(event, span: .thisEvent, commit: true)
    }
}

// MARK: - Errors

enum CalendarError: LocalizedError {
    case accessDenied
    case eventNotFound
    case createFailed(String)

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Access to Calendar was denied. Please enable access in Settings."
        case .eventNotFound:
            return "The calendar event could not be found."
        case .createFailed(let message):
            return "Failed to create event: \(message)"
        }
    }
}
