//
//  OCRNormalizer.swift
//  QuillStack
//
//  Created on 2026-01-06.
//  Part of QUI-146: Note Type Visual Themes & Formatting
//

import Foundation

/// Cleans up common OCR artifacts and normalizes text formatting.
///
/// OCR often misinterprets handwritten checkboxes, bullets, and other symbols.
/// This utility normalizes these artifacts into proper Unicode characters for
/// consistent display across all note types.
///
/// **Key transformations:**
/// - Checkboxes: `[ ]` → `☐`, `[x]` → `☑`
/// - Bullets: `l ` → `• `, `- ` → `• `
/// - Hollow bullets: `( )` → `○`
///
/// **Usage:**
/// ```swift
/// let cleanedText = OCRNormalizer.cleanText(ocrOutput)
/// ```
@MainActor
final class OCRNormalizer {

    // MARK: - Public API

    /// Cleans OCR text by normalizing common artifacts and formatting issues.
    ///
    /// - Parameter text: Raw OCR text that may contain artifacts
    /// - Returns: Cleaned text with normalized symbols
    static func cleanText(_ text: String) -> String {
        var cleaned = text

        // Fix checkbox artifacts (most common OCR issue)
        cleaned = normalizeCheckboxes(cleaned)

        // Fix bullet artifacts (OCR often mistakes lowercase "l" or "I" for bullets)
        cleaned = normalizeBullets(cleaned)

        // Fix spacing issues
        cleaned = normalizeSpacing(cleaned)

        return cleaned
    }

    // MARK: - Private Helpers

    /// Normalizes checkbox symbols to proper Unicode characters
    private static func normalizeCheckboxes(_ text: String) -> String {
        var result = text

        // Unchecked boxes: [ ], [  ], []
        result = result.replacingOccurrences(of: "[  ]", with: "☐")
        result = result.replacingOccurrences(of: "[ ]", with: "☐")
        result = result.replacingOccurrences(of: "[]", with: "☐")

        // Checked boxes: [x], [X]
        result = result.replacingOccurrences(of: "[x]", with: "☑")
        result = result.replacingOccurrences(of: "[X]", with: "☑")

        // Alternative checkbox styles: ( ), (x), (X)
        result = result.replacingOccurrences(of: "( )", with: "☐")
        result = result.replacingOccurrences(of: "(x)", with: "☑")
        result = result.replacingOccurrences(of: "(X)", with: "☑")

        return result
    }

    /// Normalizes bullet symbols to proper Unicode bullet point
    private static func normalizeBullets(_ text: String) -> String {
        var result = text

        // Common OCR mistakes: lowercase "l" or capital "I" at start of line
        // These patterns only match when followed by a space (bullet context)
        result = result.replacingOccurrences(of: "\nl ", with: "\n• ")
        result = result.replacingOccurrences(of: "\nI ", with: "\n• ")

        // Handle case where it's the first line
        if result.hasPrefix("l ") {
            result = "• " + result.dropFirst(2)
        }
        if result.hasPrefix("I ") {
            result = "• " + result.dropFirst(2)
        }

        // Normalize dash and asterisk bullets to proper bullet point
        result = result.replacingOccurrences(of: "\n- ", with: "\n• ")
        result = result.replacingOccurrences(of: "\n* ", with: "\n• ")

        // Handle case where it's the first line
        if result.hasPrefix("- ") {
            result = "• " + result.dropFirst(2)
        }
        if result.hasPrefix("* ") {
            result = "• " + result.dropFirst(2)
        }

        // Normalize hollow bullets (often from OCR of circles)
        result = result.replacingOccurrences(of: "\n() ", with: "\n○ ")
        result = result.replacingOccurrences(of: "\n○ ", with: "\n• ")  // Or keep as hollow bullet if preferred

        return result
    }

    /// Normalizes spacing issues from OCR
    private static func normalizeSpacing(_ text: String) -> String {
        var result = text

        // Remove excessive whitespace (multiple spaces → single space)
        // But preserve intentional double newlines for paragraph breaks
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }

        // Clean up multiple newlines (more than 2 → 2)
        while result.contains("\n\n\n") {
            result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }

        // Trim leading/trailing whitespace but preserve internal structure
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        return result
    }
}
