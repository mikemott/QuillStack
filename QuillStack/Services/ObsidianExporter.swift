import Foundation
import UIKit

struct ObsidianExporter {
    private static let vaultBookmarkKey = "obsidianVaultBookmark"
    private static let vaultDisplayNameKey = "obsidianVaultDisplayName"
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var attachmentFolder: String {
        get { userDefaults.string(forKey: "obsidianAttachmentFolder") ?? "attachments" }
        set { userDefaults.set(newValue, forKey: "obsidianAttachmentFolder") }
    }

    var dailyNoteFolder: String {
        get { userDefaults.string(forKey: "obsidianDailyNoteFolder") ?? "" }
        set { userDefaults.set(newValue, forKey: "obsidianDailyNoteFolder") }
    }

    var includeOCRText: Bool {
        get { userDefaults.bool(forKey: "obsidianIncludeOCR") }
        set { userDefaults.set(newValue, forKey: "obsidianIncludeOCR") }
    }

    var vaultDisplayName: String {
        userDefaults.string(forKey: Self.vaultDisplayNameKey) ?? ""
    }

    var isConfigured: Bool {
        userDefaults.data(forKey: Self.vaultBookmarkKey) != nil
    }

    func configureVault(url: URL) throws {
        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let bookmark = try url.bookmarkData(options: [.minimalBookmark], includingResourceValuesForKeys: nil)
        userDefaults.set(bookmark, forKey: Self.vaultBookmarkKey)
        userDefaults.set(url.lastPathComponent, forKey: Self.vaultDisplayNameKey)
    }

    func clearVault() {
        userDefaults.removeObject(forKey: Self.vaultBookmarkKey)
        userDefaults.removeObject(forKey: Self.vaultDisplayNameKey)
    }

    func export(_ capture: Capture) throws {
        guard isConfigured else { throw ExportError.notConfigured }

        let vaultURL = try resolvedVaultURL()
        let didStartAccess = vaultURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                vaultURL.stopAccessingSecurityScopedResource()
            }
        }

        try export(capture, to: vaultURL)
    }

    func export(_ capture: Capture, to vaultURL: URL) throws {
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

    private func resolvedVaultURL() throws -> URL {
        guard let bookmark = userDefaults.data(forKey: Self.vaultBookmarkKey) else {
            throw ExportError.notConfigured
        }

        var isStale = false
        let url = try URL(
            resolvingBookmarkData: bookmark,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )

        if isStale {
            try configureVault(url: url)
        }

        return url
    }

    enum ExportError: LocalizedError {
        case notConfigured

        var errorDescription: String? {
            switch self {
            case .notConfigured: "Obsidian vault folder not selected. Choose it in Settings."
            }
        }
    }
}
