//
//  ExportService.swift
//  QuillStack
//
//  Created on 2025-12-18.
//

import Foundation
import UIKit

// MARK: - Export Service

/// Main coordinator for exporting notes to external apps
class ExportService {
    static let shared = ExportService()

    private let tagRouter = TagRouter()
    private let appleNotesExporter = AppleNotesExporter()
    private lazy var obsidianExporter = ObsidianExporter()
    private lazy var notionExporter = NotionExporter()

    private init() {}

    // MARK: - Public API

    /// Export a note to the specified destination
    func export(note: Note, to destination: ExportDestinationType, options: ExportOptions = ExportOptions()) async throws -> ExportResult {
        let exporter = getExporter(for: destination)

        // Check configuration
        guard exporter.isConfigured() else {
            throw ExportError.destinationNotConfigured(destination)
        }

        // Format the content
        let formatter = getFormatter(for: note.noteType)
        let content = formatter.format(note: note, options: options)

        // Resolve target path from tags
        let tags = tagRouter.extractTags(from: note.content)
        let targetPath = tagRouter.resolvePath(tags: tags, for: destination)

        // Build request
        let request = ExportRequest(
            note: note,
            content: content,
            targetPath: targetPath.isEmpty ? nil : targetPath,
            options: options
        )

        // Execute export
        return try await exporter.export(request: request)
    }

    /// Export multiple notes to the specified destination
    func exportMultiple(notes: [Note], to destination: ExportDestinationType, options: ExportOptions = ExportOptions()) async throws -> [ExportResult] {
        var results: [ExportResult] = []

        for note in notes {
            do {
                let result = try await export(note: note, to: destination, options: options)
                results.append(result)
            } catch {
                results.append(.failure(destination: destination, message: error.localizedDescription))
            }
        }

        return results
    }

    /// Check if a destination is properly configured
    func canExport(to destination: ExportDestinationType) -> Bool {
        getExporter(for: destination).isConfigured()
    }

    /// Get list of what's missing for a destination
    func getMissingConfiguration(for destination: ExportDestinationType) -> [String] {
        getExporter(for: destination).getMissingConfiguration()
    }

    /// Get all available destinations with their configuration status
    func getAvailableDestinations() -> [(type: ExportDestinationType, configured: Bool)] {
        ExportDestinationType.allCases.map { type in
            (type: type, configured: canExport(to: type))
        }
    }

    // MARK: - Private Helpers

    private func getExporter(for destination: ExportDestinationType) -> ExportDestination {
        switch destination {
        case .appleNotes:
            return appleNotesExporter
        case .obsidian:
            return obsidianExporter
        case .notion:
            return notionExporter
        }
    }

    private func getFormatter(for noteType: String) -> ExportFormatter {
        switch noteType.lowercased() {
        case "todo":
            return TodoExportFormatter()
        case "meeting":
            return MeetingExportFormatter()
        case "email":
            return EmailExportFormatter()
        default:
            return GeneralExportFormatter()
        }
    }
}

// MARK: - Export Formatter Protocol

protocol ExportFormatter {
    func format(note: Note, options: ExportOptions) -> FormattedExportContent
}

// MARK: - General Note Formatter

class GeneralExportFormatter: ExportFormatter {
    func format(note: Note, options: ExportOptions) -> FormattedExportContent {
        let title = extractTitle(from: note.content)
        let body = cleanContent(note.content)
        let tags = TagRouter().extractTags(from: note.content)
        let metadata = ExportMetadata(from: note, tags: tags)

        var attachments: [ExportAttachment] = []
        if options.includeOriginalImage, let imageData = note.originalImageData {
            attachments.append(.image(imageData))
        }

        return FormattedExportContent(
            title: title,
            plainBody: body,
            markdownBody: body,
            metadata: metadata,
            attachments: attachments
        )
    }

    func extractTitle(from content: String) -> String {
        // Get first line, remove hashtags, limit length
        let firstLine = content.components(separatedBy: .newlines).first ?? "Untitled Note"
        let cleaned = firstLine
            .replacingOccurrences(of: "#\\w+#", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)

        if cleaned.isEmpty {
            return "Untitled Note"
        }

        // Truncate if too long
        if cleaned.count > 50 {
            return String(cleaned.prefix(47)) + "..."
        }

        return cleaned
    }

    func cleanContent(_ content: String) -> String {
        // Remove type trigger hashtags but keep content hashtags
        let triggers = ["#todo#", "#to-do#", "#tasks#", "#task#", "#email#", "#mail#", "#meeting#", "#notes#", "#minutes#"]
        var cleaned = content

        for trigger in triggers {
            cleaned = cleaned.replacingOccurrences(of: trigger, with: "", options: .caseInsensitive)
        }

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Todo Export Formatter

class TodoExportFormatter: ExportFormatter {
    func format(note: Note, options: ExportOptions) -> FormattedExportContent {
        let baseFormatter = GeneralExportFormatter()
        let title = baseFormatter.extractTitle(from: note.content)
        let tags = TagRouter().extractTags(from: note.content)
        let metadata = ExportMetadata(from: note, tags: tags)

        // Get todo items from relationship
        let todoItems = (note.todoItems?.allObjects as? [TodoItem]) ?? []
        let sortedItems = todoItems.sorted { $0.sortOrder < $1.sortOrder }

        // Build plain text with unicode checkboxes
        var plainLines: [String] = []
        var markdownLines: [String] = []

        for item in sortedItems {
            let plainCheckbox = item.isCompleted ? "\u{2611}" : "\u{2610}"  // ☑ or ☐
            let mdCheckbox = item.isCompleted ? "- [x]" : "- [ ]"

            plainLines.append("\(plainCheckbox) \(item.text)")
            markdownLines.append("\(mdCheckbox) \(item.text)")
        }

        // If no parsed items, fall back to content
        let plainBody = plainLines.isEmpty ? baseFormatter.cleanContent(note.content) : plainLines.joined(separator: "\n")
        let markdownBody = markdownLines.isEmpty ? baseFormatter.cleanContent(note.content) : markdownLines.joined(separator: "\n")

        // Build attributed string with checklist formatting
        let attributedBody = buildAttributedTodoList(items: sortedItems, fallback: plainBody)

        var attachments: [ExportAttachment] = []
        if options.includeOriginalImage, let imageData = note.originalImageData {
            attachments.append(.image(imageData))
        }

        return FormattedExportContent(
            title: title,
            plainBody: plainBody,
            markdownBody: markdownBody,
            attributedBody: attributedBody,
            metadata: metadata,
            attachments: attachments
        )
    }

    private func buildAttributedTodoList(items: [TodoItem], fallback: String) -> NSAttributedString {
        guard !items.isEmpty else {
            return NSAttributedString(string: fallback)
        }

        let result = NSMutableAttributedString()
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4

        for (index, item) in items.enumerated() {
            let checkbox = item.isCompleted ? "\u{2611} " : "\u{2610} "
            let line = checkbox + item.text

            var attributes: [NSAttributedString.Key: Any] = [
                .paragraphStyle: paragraphStyle,
                .font: UIFont.systemFont(ofSize: 16)
            ]

            if item.isCompleted {
                attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
                attributes[.foregroundColor] = UIColor.secondaryLabel
            }

            result.append(NSAttributedString(string: line, attributes: attributes))

            if index < items.count - 1 {
                result.append(NSAttributedString(string: "\n"))
            }
        }

        return result
    }
}

// MARK: - Meeting Export Formatter

class MeetingExportFormatter: ExportFormatter {
    func format(note: Note, options: ExportOptions) -> FormattedExportContent {
        let baseFormatter = GeneralExportFormatter()
        let tags = TagRouter().extractTags(from: note.content)
        let metadata = ExportMetadata(from: note, tags: tags)

        // Get meeting entity if available
        let meeting = note.meeting

        let title = meeting?.title ?? baseFormatter.extractTitle(from: note.content)

        // Build structured content
        var plainLines: [String] = []
        var markdownLines: [String] = []

        // Add meeting metadata
        if let meetingDate = meeting?.meetingDate {
            let dateStr = formatDate(meetingDate)
            plainLines.append("Date: \(dateStr)")
            markdownLines.append("**Date:** \(dateStr)")
        }

        if let attendees = meeting?.attendees, !attendees.isEmpty {
            plainLines.append("Attendees: \(attendees)")
            markdownLines.append("**Attendees:** \(attendees)")
        }

        if !plainLines.isEmpty {
            plainLines.append("")
            markdownLines.append("")
        }

        // Add agenda
        if let agenda = meeting?.agenda, !agenda.isEmpty {
            plainLines.append("Agenda:")
            plainLines.append(agenda)
            plainLines.append("")

            markdownLines.append("## Agenda")
            markdownLines.append(agenda)
            markdownLines.append("")
        }

        // Add action items
        if let actionItems = meeting?.actionItems, !actionItems.isEmpty {
            plainLines.append("Action Items:")
            plainLines.append(actionItems)

            markdownLines.append("## Action Items")
            for item in actionItems.components(separatedBy: .newlines) where !item.isEmpty {
                markdownLines.append("- [ ] \(item.trimmingCharacters(in: .whitespaces))")
            }
        }

        // Fallback to note content if no structured data
        let plainBody = plainLines.isEmpty ? baseFormatter.cleanContent(note.content) : plainLines.joined(separator: "\n")
        let markdownBody = markdownLines.isEmpty ? baseFormatter.cleanContent(note.content) : markdownLines.joined(separator: "\n")

        var attachments: [ExportAttachment] = []
        if options.includeOriginalImage, let imageData = note.originalImageData {
            attachments.append(.image(imageData))
        }

        return FormattedExportContent(
            title: title,
            plainBody: plainBody,
            markdownBody: markdownBody,
            metadata: metadata,
            attachments: attachments
        )
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Email Export Formatter

class EmailExportFormatter: ExportFormatter {
    func format(note: Note, options: ExportOptions) -> FormattedExportContent {
        let tags = TagRouter().extractTags(from: note.content)
        let metadata = ExportMetadata(from: note, tags: tags)

        // Parse email fields from content
        let (to, subject, body) = parseEmailContent(note.content)

        let title = subject.isEmpty ? "Email Draft" : subject

        var plainLines: [String] = []
        if !to.isEmpty {
            plainLines.append("To: \(to)")
        }
        if !subject.isEmpty {
            plainLines.append("Subject: \(subject)")
        }
        if !plainLines.isEmpty {
            plainLines.append("")
        }
        plainLines.append(body)

        let plainBody = plainLines.joined(separator: "\n")

        var attachments: [ExportAttachment] = []
        if options.includeOriginalImage, let imageData = note.originalImageData {
            attachments.append(.image(imageData))
        }

        return FormattedExportContent(
            title: title,
            plainBody: plainBody,
            markdownBody: plainBody,
            metadata: metadata,
            attachments: attachments
        )
    }

    private func parseEmailContent(_ content: String) -> (to: String, subject: String, body: String) {
        let lines = content.components(separatedBy: .newlines)
        var to = ""
        var subject = ""
        var bodyLines: [String] = []
        var inBody = false

        for line in lines {
            let lowercased = line.lowercased().trimmingCharacters(in: .whitespaces)

            // Skip trigger tags
            if lowercased.contains("#email#") || lowercased.contains("#mail#") {
                continue
            }

            if lowercased.hasPrefix("to:") {
                to = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            } else if lowercased.hasPrefix("subject:") || lowercased.hasPrefix("subj:") || lowercased.hasPrefix("re:") {
                let prefixLength = lowercased.hasPrefix("subject:") ? 8 : (lowercased.hasPrefix("subj:") ? 5 : 3)
                subject = String(line.dropFirst(prefixLength)).trimmingCharacters(in: .whitespaces)
                inBody = true
            } else if inBody || (!to.isEmpty && subject.isEmpty && !lowercased.hasPrefix("to:")) {
                inBody = true
                bodyLines.append(line)
            } else if to.isEmpty && subject.isEmpty {
                // Content before any headers becomes body
                bodyLines.append(line)
            }
        }

        let body = bodyLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return (to, subject, body)
    }
}
