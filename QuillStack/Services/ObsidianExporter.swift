import Foundation
import UIKit

struct ObsidianExporter {
    var vaultPath: String {
        get { UserDefaults.standard.string(forKey: "obsidianVaultPath") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "obsidianVaultPath") }
    }

    var attachmentFolder: String {
        get { UserDefaults.standard.string(forKey: "obsidianAttachmentFolder") ?? "attachments" }
        set { UserDefaults.standard.set(newValue, forKey: "obsidianAttachmentFolder") }
    }

    var dailyNoteFolder: String {
        get { UserDefaults.standard.string(forKey: "obsidianDailyNoteFolder") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "obsidianDailyNoteFolder") }
    }

    var includeOCRText: Bool {
        get { UserDefaults.standard.bool(forKey: "obsidianIncludeOCR") }
        set { UserDefaults.standard.set(newValue, forKey: "obsidianIncludeOCR") }
    }

    var isConfigured: Bool { !vaultPath.isEmpty }

    func export(_ capture: Capture) throws {
        guard isConfigured else { throw ExportError.notConfigured }

        let vaultURL = URL(fileURLWithPath: vaultPath)
        let attachmentURL = vaultURL.appendingPathComponent(attachmentFolder)
        let fm = FileManager.default

        try fm.createDirectory(at: attachmentURL, withIntermediateDirectories: true)

        // Save images
        var imageFilenames: [String] = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd-HHmmss"
        let dateString = dateFormatter.string(from: capture.createdAt)

        for (index, image) in capture.sortedImages.enumerated() {
            let suffix = capture.isStack ? "-p\(index + 1)" : ""
            let filename = "capture-\(dateString)\(suffix).jpg"
            let fileURL = attachmentURL.appendingPathComponent(filename)
            try image.imageData.write(to: fileURL)
            imageFilenames.append(filename)
        }

        // Build markdown
        let markdown = buildMarkdown(capture: capture, imageFilenames: imageFilenames)

        // Write to daily note
        let dailyNoteURL = dailyNoteURL(for: capture.createdAt, vaultURL: vaultURL)
        try fm.createDirectory(
            at: dailyNoteURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        if fm.fileExists(atPath: dailyNoteURL.path) {
            let existing = try String(contentsOf: dailyNoteURL, encoding: .utf8)
            try (existing + "\n\n" + markdown).write(to: dailyNoteURL, atomically: true, encoding: .utf8)
        } else {
            let header = "# \(headerDate(capture.createdAt))\n\n"
            try (header + markdown).write(to: dailyNoteURL, atomically: true, encoding: .utf8)
        }
    }

    func buildMarkdown(capture: Capture, imageFilenames: [String]) -> String {
        var lines: [String] = []

        // Heading
        let title = capture.extractedTitle ?? "Capture"
        lines.append("### \(title)")

        // Images
        for filename in imageFilenames {
            lines.append("![[\(filename)]]")
        }

        // Tags
        if !capture.tags.isEmpty {
            let tags = capture.tags.map { "#\($0.name.lowercased().replacingOccurrences(of: " ", with: "-"))" }
            lines.append(tags.joined(separator: " "))
        }

        // Location
        if let location = capture.locationName {
            lines.append("📍 \(location)")
        }

        // OCR text
        if includeOCRText, let text = capture.ocrText, !text.isEmpty {
            lines.append("")
            lines.append("> \(text.replacingOccurrences(of: "\n", with: "\n> "))")
        }

        return lines.joined(separator: "\n")
    }

    func dailyNoteURL(for date: Date, vaultURL: URL) -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let filename = formatter.string(from: date) + ".md"

        if dailyNoteFolder.isEmpty {
            return vaultURL.appendingPathComponent(filename)
        }
        return vaultURL
            .appendingPathComponent(dailyNoteFolder)
            .appendingPathComponent(filename)
    }

    private func headerDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: date)
    }

    enum ExportError: LocalizedError {
        case notConfigured

        var errorDescription: String? {
            switch self {
            case .notConfigured: "Obsidian vault path not configured. Set it in Settings."
            }
        }
    }
}
