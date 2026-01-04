//
//  EventExtractor.swift
//  QuillStack
//
//  Phase 2.3 - Event Extraction
//  Extracts event information from text (flyers, invitations, etc.) using LLM.
//

import Foundation

/// Service for extracting event information from text content
struct EventExtractor {
    
    // MARK: - LLM-Powered Extraction
    
    /// Extract event information from text using LLM
    /// - Parameter content: The text content to extract from
    /// - Returns: Extracted event data
    /// - Throws: EventExtractionError if extraction fails
    static func extract(_ content: String) async throws -> ExtractedEvent {
        let prompt = """
        Extract event information from this text (flyer, invitation, announcement, etc.).
        Return valid JSON only, no other text.
        
        Format:
        {
            "title": "Event name/title",
            "date": "2024-12-25" or "Friday, December 25" or "tomorrow" or null,
            "time": "2:00 PM" or "14:00" or null,
            "location": "Venue name and address",
            "description": "Event description or details",
            "organizer": "Organizer name",
            "contactInfo": "Phone or email",
            "isRecurring": false,
            "recurrencePattern": "daily" or "weekly" or "monthly" or null
        }
        
        Rules:
        - Extract title from first line or prominent text
        - Parse dates in natural language ("tomorrow", "next Friday") or standard formats
        - Extract time if mentioned
        - Include full location/venue information
        - Set isRecurring=true if event repeats
        - If information is missing, use null
        
        Text:
        \(content)
        """
        
        let settings = await SettingsManager.shared
        guard let apiKey = await settings.claudeAPIKey, !apiKey.isEmpty else {
            throw EventExtractionError.noAPIKey
        }
        
        let response = try await LLMService.shared.performAPIRequest(
            prompt: prompt,
            maxTokens: 300
        )
        
        // Parse JSON response
        let cleanedResponse = cleanJSONResponse(response)
        guard let jsonData = cleanedResponse.data(using: .utf8) else {
            throw EventExtractionError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        let extractionResult = try decoder.decode(EventExtractionJSON.self, from: jsonData)
        
        // Convert to ExtractedEvent
        return ExtractedEvent(
            title: extractionResult.title,
            date: extractionResult.date,
            time: extractionResult.time,
            location: extractionResult.location,
            description: extractionResult.description,
            organizer: extractionResult.organizer,
            contactInfo: extractionResult.contactInfo,
            isRecurring: extractionResult.isRecurring ?? false,
            recurrencePattern: extractionResult.recurrencePattern
        )
    }
    
    /// Hybrid approach: Try LLM first, fall back to MeetingParser heuristics
    static func extractHybrid(_ content: String) async -> ExtractedEvent? {
        // Try LLM first
        if let llmEvent = try? await extract(content),
           llmEvent.hasMinimumData {
            return llmEvent
        }
        
        // Fall back to MeetingParser for basic extraction
        // Note: MeetingParser is for meetings, but can extract basic event info
        // This is a simple fallback - could be enhanced
        return extractFromHeuristics(content)
    }
    
    /// Extract event using heuristics (fallback)
    private static func extractFromHeuristics(_ content: String) -> ExtractedEvent? {
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        guard let firstLine = lines.first else { return nil }
        
        // Basic extraction
        var title = firstLine
        var date: String? = nil
        var time: String? = nil
        var location: String? = nil
        
        // Look for date patterns
        let datePattern = #"\d{1,2}/\d{1,2}/\d{2,4}"#
        if let regex = try? NSRegularExpression(pattern: datePattern),
           let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
           let range = Range(match.range, in: content) {
            date = String(content[range])
        }
        
        // Look for time patterns
        let timePattern = #"\d{1,2}:\d{2}\s*(AM|PM|am|pm)"#
        if let regex = try? NSRegularExpression(pattern: timePattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
           let range = Range(match.range, in: content) {
            time = String(content[range])
        }
        
        // Look for location keywords
        let locationKeywords = ["at", "location", "venue", "address"]
        for (index, line) in lines.enumerated() {
            let lowercased = line.lowercased()
            if locationKeywords.contains(where: { lowercased.contains($0) }) && index + 1 < lines.count {
                location = lines[index + 1]
                break
            }
        }
        
        return ExtractedEvent(
            title: title,
            date: date,
            time: time,
            location: location
        )
    }
    
    /// Clean JSON response by removing markdown code blocks
    private static func cleanJSONResponse(_ response: String) -> String {
        var cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove markdown code blocks
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }
        
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Errors
    
    enum EventExtractionError: LocalizedError {
        case noAPIKey
        case invalidResponse
        case parsingFailed
        
        var errorDescription: String? {
            switch self {
            case .noAPIKey:
                return "No API key configured for LLM extraction"
            case .invalidResponse:
                return "Invalid response from LLM"
            case .parsingFailed:
                return "Failed to parse event extraction result"
            }
        }
    }
}

