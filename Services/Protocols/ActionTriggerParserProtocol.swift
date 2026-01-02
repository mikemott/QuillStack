//
//  ActionTriggerParserProtocol.swift
//  QuillStack
//
//  Phase A.2 - Trigger Parser
//  Protocol for parsing inline action triggers from OCR text.
//

import Foundation

/// Protocol defining action trigger parsing capabilities.
/// Implement this protocol to provide alternative parsing strategies or mocks for testing.
@MainActor
protocol ActionTriggerParserProtocol {
    /// Parses text content to extract inline action triggers.
    /// - Parameter text: The OCR text content to parse
    /// - Returns: Parse result containing actions, cleaned content, and divider info
    func parse(_ text: String) -> TriggerParseResult
}

/// Result of parsing action triggers from text.
struct TriggerParseResult: Equatable, Sendable {
    /// Extracted action triggers as NoteAction objects
    let actions: [NoteAction]
    /// Content with trigger syntax removed
    let cleanedContent: String
    /// Whether a `---` divider was found in the content
    let hasDivider: Bool

    /// Creates an empty result with no actions.
    static var empty: TriggerParseResult {
        TriggerParseResult(actions: [], cleanedContent: "", hasDivider: false)
    }
}
