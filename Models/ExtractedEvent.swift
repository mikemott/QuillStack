//
//  ExtractedEvent.swift
//  QuillStack
//
//  Phase 2.3 - Event Extraction
//  Represents an event extracted from text using LLM.
//

import Foundation

/// Represents an event extracted from text content (flyers, invitations, etc.)
struct ExtractedEvent: Codable, Identifiable, Sendable, Equatable {
    let id: UUID
    let title: String
    let date: String? // ISO 8601 date string or natural language
    let time: String? // Time string (e.g., "2:00 PM", "14:00")
    let location: String?
    let description: String?
    let organizer: String?
    let contactInfo: String? // Phone or email
    let isRecurring: Bool
    let recurrencePattern: String? // "daily", "weekly", "monthly", etc.
    
    init(
        id: UUID = UUID(),
        title: String,
        date: String? = nil,
        time: String? = nil,
        location: String? = nil,
        description: String? = nil,
        organizer: String? = nil,
        contactInfo: String? = nil,
        isRecurring: Bool = false,
        recurrencePattern: String? = nil
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.time = time
        self.location = location
        self.description = description
        self.organizer = organizer
        self.contactInfo = contactInfo
        self.isRecurring = isRecurring
        self.recurrencePattern = recurrencePattern
    }
    
    /// Parse date and time strings into a combined Date object
    /// Uses DateParsingService for robust date/time extraction via NSDataDetector
    var parsedDateTime: Date? {
        guard let dateString = date else { return nil }
        return DateParsingService.parse(dateString: dateString, timeString: time)
    }
    
    /// Check if event has minimum required data
    /// Validates that title exists and date/time can be successfully parsed
    var hasMinimumData: Bool {
        !title.isEmpty && parsedDateTime != nil
    }
}

/// JSON response structure from LLM for event extraction
struct EventExtractionJSON: Codable {
    let title: String
    let date: String?
    let time: String?
    let location: String?
    let description: String?
    let organizer: String?
    let contactInfo: String?
    let isRecurring: Bool?
    let recurrencePattern: String?
}

