//
//  DateParsingService.swift
//  QuillStack
//
//  Service for parsing dates and times from natural language and various formats.
//  Uses NSDataDetector for robust date/time extraction.
//

import Foundation

/// Service for parsing dates and times from various formats and natural language
struct DateParsingService {
    
    /// Parse a date string, optionally combined with a time string
    /// - Parameters:
    ///   - dateString: The date string (ISO 8601, natural language, or common formats)
    ///   - timeString: Optional time string (e.g., "2:00 PM", "14:00")
    /// - Returns: Parsed Date object, or nil if parsing fails
    static func parse(dateString: String, timeString: String? = nil) -> Date? {
        // Combine date and time strings for better detection
        let fullString: String
        if let timeString = timeString, !timeString.isEmpty {
            fullString = "\(dateString) \(timeString)"
        } else {
            fullString = dateString
        }
        
        // Use NSDataDetector for robust date/time extraction
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
            return nil
        }
        
        let range = NSRange(location: 0, length: fullString.utf16.count)
        guard let match = detector.firstMatch(in: fullString, options: [], range: range) else {
            // Fallback to manual parsing if NSDataDetector fails
            return parseManually(dateString: dateString, timeString: timeString)
        }
        
        guard let detectedDate = match.date else {
            return parseManually(dateString: dateString, timeString: timeString)
        }
        
        // NSDataDetector may have detected a date range, use the start date
        var parsedDate = detectedDate
        
        // If time was provided separately and NSDataDetector didn't include it, apply it manually
        if let timeString = timeString, !timeString.isEmpty {
            // Check if the detected date already has the correct time
            let calendar = Calendar.current
            let detectedComponents = calendar.dateComponents([.hour, .minute], from: detectedDate)
            
            // If no time was detected, try to parse and apply the time string
            if detectedComponents.hour == 0 && detectedComponents.minute == 0 {
                if let timeDate = parseTimeString(timeString) {
                    let timeComponents = calendar.dateComponents([.hour, .minute], from: timeDate)
                    parsedDate = calendar.date(bySettingHour: timeComponents.hour ?? 0, 
                                              minute: timeComponents.minute ?? 0, 
                                              second: 0, 
                                              of: detectedDate) ?? detectedDate
                }
            }
        }
        
        return parsedDate
    }
    
    /// Manual parsing fallback when NSDataDetector fails
    private static func parseManually(dateString: String, timeString: String?) -> Date? {
        // Try ISO 8601 first
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: dateString) {
            return applyTime(timeString, to: date)
        }
        
        // Try without fractional seconds
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: dateString) {
            return applyTime(timeString, to: date)
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
                return applyTime(timeString, to: date)
            }
        }
        
        // Try natural language parsing
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let lowercased = dateString.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch lowercased {
        case "tomorrow":
            return applyTime(timeString, to: calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now)
        case "today":
            return applyTime(timeString, to: startOfToday)
        default:
            if lowercased.contains("next week") {
                return applyTime(timeString, to: calendar.date(byAdding: .weekOfYear, value: 1, to: startOfToday) ?? now)
            } else if lowercased.contains("next month") {
                return applyTime(timeString, to: calendar.date(byAdding: .month, value: 1, to: startOfToday) ?? now)
            }
        }
        
        return nil
    }
    
    /// Parse a time string into a Date object (time only, date will be ignored)
    private static func parseTimeString(_ timeString: String) -> Date? {
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
            if let timeDate = formatter.date(from: timeString) {
                return timeDate
            }
        }
        
        return nil
    }
    
    /// Apply a time string to an existing date
    private static func applyTime(_ timeString: String?, to date: Date) -> Date {
        guard let timeString = timeString, !timeString.isEmpty else {
            return date
        }
        
        guard let timeDate = parseTimeString(timeString) else {
            return date
        }
        
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: timeDate)
        return calendar.date(bySettingHour: timeComponents.hour ?? 0, 
                            minute: timeComponents.minute ?? 0, 
                            second: 0, 
                            of: date) ?? date
    }
}

