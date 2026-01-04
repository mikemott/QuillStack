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
    var parsedDateTime: Date? {
        guard let dateString = date else { return nil }
        
        // Try ISO 8601 first
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: dateString) {
            return applyTime(to: date)
        }
        
        // Try without fractional seconds
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: dateString) {
            return applyTime(to: date)
        }
        
        // Try common date formats
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        let dateFormats = [
            "yyyy-MM-dd",
            "MM/dd/yyyy",
            "MM/dd/yy",
            "MMMM dd, yyyy",
            "MMM dd, yyyy",
            "EEEE, MMMM dd, yyyy"
        ]
        
        for format in dateFormats {
            formatter.dateFormat = format
            if let date = formatter.date(from: dateString) {
                return applyTime(to: date)
            }
        }
        
        // Try natural language parsing
        let calendar = Calendar.current
        let now = Date()
        let lowercased = dateString.lowercased()
        
        if lowercased.contains("tomorrow") {
            return applyTime(to: calendar.date(byAdding: .day, value: 1, to: now) ?? now)
        } else if lowercased.contains("next week") {
            return applyTime(to: calendar.date(byAdding: .weekOfYear, value: 1, to: now) ?? now)
        } else if lowercased.contains("today") {
            return applyTime(to: now)
        }
        
        return nil
    }
    
    /// Apply time string to a date
    private func applyTime(to date: Date) -> Date {
        guard let timeString = time else { return date }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        let timeFormats = [
            "h:mm a",      // 2:00 PM
            "HH:mm",       // 14:00
            "h:mma",       // 2:00PM
            "h:mm a zzz",  // 2:00 PM PST
        ]
        
        for format in timeFormats {
            formatter.dateFormat = format
            if let timeOnly = formatter.date(from: timeString) {
                let calendar = Calendar.current
                let timeComponents = calendar.dateComponents([.hour, .minute], from: timeOnly)
                return calendar.date(bySettingHour: timeComponents.hour ?? 0, minute: timeComponents.minute ?? 0, second: 0, of: date) ?? date
            }
        }
        
        return date
    }
    
    /// Check if event has minimum required data
    var hasMinimumData: Bool {
        !title.isEmpty && (date != nil || time != nil)
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

