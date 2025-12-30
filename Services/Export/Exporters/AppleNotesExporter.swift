//
//  AppleNotesExporter.swift
//  QuillStack
//
//  Created on 2025-12-18.
//

import Foundation
import UIKit

// MARK: - Apple Notes Exporter

/// Exports notes to Apple Notes by copying to clipboard and opening the Notes app
class AppleNotesExporter: ExportDestination {
    let type: ExportDestinationType = .appleNotes

    // MARK: - Configuration

    func isConfigured() -> Bool {
        // Apple Notes is always available on iOS
        true
    }

    func getMissingConfiguration() -> [String] {
        // No configuration needed
        []
    }

    // MARK: - Export

    func export(request: ExportRequest) async throws -> ExportResult {
        // Build the content
        let textContent = buildShareText(request: request)

        // Copy to clipboard
        await copyToClipboard(text: textContent, image: request.options.includeOriginalImage ? request.note.originalImageData : nil)

        // Open Notes app
        let opened = await openNotesApp()

        if opened {
            return .success(
                destination: .appleNotes,
                message: "Copied! Paste into a new note"
            )
        } else {
            // Even if Notes didn't open, content is copied
            return .success(
                destination: .appleNotes,
                message: "Copied to clipboard"
            )
        }
    }

    // MARK: - Private Helpers

    private func buildShareText(request: ExportRequest) -> String {
        var lines: [String] = []

        // Title
        lines.append(request.content.title)
        lines.append("")

        // Body content
        lines.append(request.content.plainBody)

        // Add metadata footer if enabled
        if request.options.includeMetadata {
            lines.append("")
            lines.append("---")
            lines.append("Captured: \(formatDate(request.content.metadata.createdAt))")
            if !request.content.metadata.tags.isEmpty {
                lines.append("Tags: \(request.content.metadata.tags.map { "#\($0)" }.joined(separator: " "))")
            }
            lines.append("Source: QuillStack")
        }

        return lines.joined(separator: "\n")
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    @MainActor
    private func copyToClipboard(text: String, image imageData: Data?) {
        let pasteboard = UIPasteboard.general

        if let imageData = imageData, let image = UIImage(data: imageData) {
            // Copy both text and image
            pasteboard.items = [
                ["public.utf8-plain-text": text],
                ["public.jpeg": image]
            ]
        } else {
            // Copy just text
            pasteboard.string = text
        }
    }

    @MainActor
    private func openNotesApp() async -> Bool {
        // Try the Notes URL scheme
        guard let notesURL = URL(string: "mobilenotes://") else {
            return false
        }

        if UIApplication.shared.canOpenURL(notesURL) {
            await UIApplication.shared.open(notesURL)
            return true
        }

        return false
    }
}

// MARK: - Rich Text Builder for Apple Notes

extension AppleNotesExporter {

    /// Build NSAttributedString for richer Notes formatting
    func buildRichText(request: ExportRequest) -> NSAttributedString {
        let result = NSMutableAttributedString()

        // Title with bold formatting
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 20),
            .foregroundColor: UIColor.label
        ]
        result.append(NSAttributedString(string: request.content.title + "\n\n", attributes: titleAttributes))

        // Body - use the attributed body if available
        result.append(request.content.attributedBody)

        // Metadata footer
        if request.options.includeMetadata {
            let footerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.secondaryLabel
            ]

            var footer = "\n\n---\n"
            footer += "Captured: \(formatDate(request.content.metadata.createdAt))\n"
            if !request.content.metadata.tags.isEmpty {
                footer += "Tags: \(request.content.metadata.tags.map { "#\($0)" }.joined(separator: " "))\n"
            }
            footer += "Source: QuillStack"

            result.append(NSAttributedString(string: footer, attributes: footerAttributes))
        }

        return result
    }
}
