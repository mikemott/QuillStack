//
//  LLMServiceProtocol.swift
//  QuillStack
//
//  Architecture refactoring: protocol abstraction for LLM service.
//  Enables dependency injection and testability for AI features.
//

import Foundation
import UIKit

/// Protocol defining LLM service capabilities.
/// Implement this protocol to provide alternative LLM implementations or mocks for testing.
protocol LLMServiceProtocol: Sendable {
    /// Recognizes text from an image using Claude Vision API.
    /// Provides superior handwriting recognition compared to Apple Vision OCR.
    /// - Parameter image: The image containing handwritten text
    /// - Returns: OCRResult compatible with existing pipeline
    /// - Throws: LLMService.LLMError on failure
    func recognizeTextFromImage(_ image: UIImage) async throws -> OCRResult

    /// Validates an API key by making a minimal test request.
    /// - Parameter apiKey: The API key to validate
    /// - Returns: True if the API key is valid
    func validateAPIKey(_ apiKey: String) async -> Bool

    /// Clean up OCR text using Claude API.
    /// - Parameters:
    ///   - text: The OCR text to enhance
    ///   - noteType: The type of note for context-aware enhancement
    /// - Returns: EnhancedTextResult with original, enhanced text, and changes
    /// - Throws: LLMService.LLMError on failure
    func enhanceOCRText(_ text: String, noteType: String) async throws -> EnhancedTextResult

    /// Extract structured meeting details from text using LLM.
    /// - Parameter text: The meeting note text to parse
    /// - Returns: MeetingDetails with subject, attendees, date, time, location, notes
    /// - Throws: LLMService.LLMError on failure
    func extractMeetingDetails(from text: String) async throws -> MeetingDetails

    /// Generate a summary of the note content.
    /// - Parameters:
    ///   - content: The note content to summarize
    ///   - noteType: The type of note for context-aware summarization
    ///   - length: The desired summary length
    /// - Returns: The generated summary text
    /// - Throws: LLMService.LLMError on failure
    func summarizeNote(_ content: String, noteType: String, length: SummaryLength) async throws -> String

    /// Expand an idea into a more detailed explanation.
    /// - Parameter idea: The brief idea to expand
    /// - Returns: The expanded explanation text
    /// - Throws: LLMService.LLMError on failure
    func expandIdea(_ idea: String) async throws -> String

    /// Perform a raw API request with a custom prompt.
    /// This allows other services to leverage the LLM for custom operations.
    /// - Parameters:
    ///   - prompt: The prompt to send to the LLM
    ///   - maxTokens: Maximum tokens in the response (default 2048)
    /// - Returns: The raw text response from the LLM
    /// - Throws: LLMService.LLMError on failure
    func performRequest(prompt: String, maxTokens: Int) async throws -> String
}

// MARK: - Default Parameter Values

extension LLMServiceProtocol {
    /// Convenience method with default maxTokens
    func performRequest(prompt: String) async throws -> String {
        try await performRequest(prompt: prompt, maxTokens: 2048)
    }
}
