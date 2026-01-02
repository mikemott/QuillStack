//
//  TextClassifierProtocol.swift
//  QuillStack
//
//  Architecture refactoring: protocol abstraction for text classification.
//  Enables dependency injection and testability.
//

import Foundation

/// Represents a section of content with a specific note type
struct NoteSection {
    let noteType: NoteType
    let content: String
    let tagRange: Range<String.Index>
}

/// Protocol defining text classification capabilities.
/// Implement this protocol to provide alternative classification strategies or mocks for testing.
@MainActor
protocol TextClassifierProtocol {
    /// Classifies the type of note based on content.
    /// Priority: explicit hashtag triggers > business card detection > content analysis
    /// - Parameter content: The text content to classify
    /// - Returns: The detected NoteType
    func classifyNote(content: String) -> NoteType

    /// Extracts the first trigger tag from content.
    /// - Parameter content: The text content to search
    /// - Returns: Tuple of (tag, cleanedContent) or nil if no tag found
    func extractTriggerTag(from content: String) -> (tag: String, cleanedContent: String)?

    /// Removes ALL occurrences of matched trigger tags from content.
    /// - Parameters:
    ///   - content: The text content to clean
    ///   - noteType: The note type whose triggers should be removed
    /// - Returns: The cleaned content with all matching tags stripped
    func extractAllTriggerTags(from content: String, for noteType: NoteType) -> String

    /// Detects all tags in content and splits into multiple sections.
    /// - Parameter content: The text content to split
    /// - Returns: Array of NoteSection for each detected section. If no tags found, returns single section with classified type.
    func splitIntoSections(content: String) -> [NoteSection]
}
