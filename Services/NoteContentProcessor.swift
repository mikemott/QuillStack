//
//  NoteContentProcessor.swift
//  QuillStack
//
//  Created on 2026-01-06.
//  Part of QUI-146: Note Type Visual Themes & Formatting
//

import Foundation
import SwiftUI

/// Orchestrates the complete content processing pipeline for notes.
///
/// Combines OCR cleanup, title extraction, and type-specific formatting
/// into a single, easy-to-use service. This is the main entry point for
/// applying QUI-146 visual enhancements to note content.
///
/// **Processing pipeline:**
/// 1. OCR cleanup: Remove artifacts, normalize symbols
/// 2. Title extraction: Generate smart title based on note type
/// 3. Content formatting: Apply type-specific visual styling
/// 4. Metadata extraction: Extract progress, participants, etc.
///
/// **Usage:**
/// ```swift
/// let processor = NoteContentProcessor()
/// let result = processor.process(note: myNote)
///
/// // Use in view:
/// Text(result.title)
/// Text(result.formattedContent)
/// Text(result.metadata["progress"] as? String ?? "")
/// ```
@MainActor
final class NoteContentProcessor {

    // MARK: - Public API

    /// Complete processing result with cleaned content, title, and metadata
    struct ProcessingResult {
        /// Smart-extracted title (or fallback)
        let title: String

        /// Cleaned content (OCR artifacts removed)
        let cleanedContent: String

        /// Formatted content with type-specific styling
        let formattedContent: AttributedString

        /// Extracted metadata (progress, participants, etc.)
        let metadata: [String: Any]

        /// The note type used for processing
        let noteType: NoteType
    }

    /// Processes a note through the complete enhancement pipeline.
    ///
    /// - Parameter note: The note to process
    /// - Returns: Processing result with enhanced title, content, and metadata
    func process(note: Note) -> ProcessingResult {
        let noteType = note.type
        let rawContent = note.content ?? ""

        // Step 1: Clean OCR artifacts
        let cleanedContent = OCRNormalizer.cleanText(rawContent)

        // Step 2: Extract smart title
        let title = TitleExtractor.extractTitle(from: cleanedContent, type: noteType)

        // Step 3: Format content with type-specific styling
        let formatter = FormatterRegistry.shared.formatter(for: noteType)
        let formattedContent = formatter.format(content: cleanedContent)

        // Step 4: Extract metadata
        let metadata = formatter.extractMetadata(from: cleanedContent)

        return ProcessingResult(
            title: title,
            cleanedContent: cleanedContent,
            formattedContent: formattedContent,
            metadata: metadata,
            noteType: noteType
        )
    }

    /// Processes just the title (useful for list views)
    ///
    /// - Parameter note: The note to extract title from
    /// - Returns: Smart-extracted title
    func extractTitle(from note: Note) -> String {
        let noteType = note.type
        let rawContent = note.content ?? ""
        let cleanedContent = OCRNormalizer.cleanText(rawContent)
        return TitleExtractor.extractTitle(from: cleanedContent, type: noteType)
    }

    /// Cleans content without formatting (useful for export/sharing)
    ///
    /// - Parameter note: The note to clean
    /// - Returns: Content with OCR artifacts removed
    func cleanContent(from note: Note) -> String {
        OCRNormalizer.cleanText(note.content ?? "")
    }
}

// MARK: - Note Extension

extension Note {
    /// Convenience property for processed content
    @MainActor
    var processedContent: NoteContentProcessor.ProcessingResult {
        NoteContentProcessor().process(note: self)
    }

    /// Convenience property for smart title
    @MainActor
    var smartTitle: String {
        NoteContentProcessor().extractTitle(from: self)
    }

    /// Convenience property for cleaned content
    @MainActor
    var cleanContent: String {
        NoteContentProcessor().cleanContent(from: self)
    }
}
