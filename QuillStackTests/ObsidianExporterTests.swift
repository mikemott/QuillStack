import Testing
import Foundation
@testable import QuillStack

@Suite("Obsidian Exporter")
struct ObsidianExporterTests {

    @Test("Daily note URL uses yyyy-MM-dd format and configured folder")
    func dailyNoteURL() {
        var exporter = makeExporter()
        exporter.dailyNoteFolder = "Journal"

        let date = fixedDate()
        let vault = URL(fileURLWithPath: "/vault")

        let url = exporter.dailyNoteURL(for: date, vaultURL: vault)
        #expect(url.path == "/vault/Journal/2026-03-24.md")
    }

    @Test("Markdown includes title, images, tags, location, and OCR blockquote")
    func markdownIncludesCaptureMetadata() {
        var exporter = makeExporter()
        exporter.includeOCRText = true

        let capture = makeCapture()
        capture.extractedTitle = "Lunch Receipt"
        capture.ocrText = "Line 1\nLine 2"
        capture.locationName = "Main St, Boston"
        capture.tags = [
            Tag(name: "Receipt", colorHex: "#D4FF00"),
            Tag(name: "Personal Note", colorHex: "#6B7280")
        ]

        let markdown = exporter.buildMarkdown(
            capture: capture,
            imageFilenames: ["capture-20260324-143000.jpg"]
        )

        #expect(markdown.contains("### Lunch Receipt"))
        #expect(markdown.contains("![[capture-20260324-143000.jpg]]"))
        #expect(markdown.contains("#receipt #personal-note"))
        #expect(markdown.contains("Main St, Boston"))
        #expect(markdown.contains("> Line 1\n> Line 2"))
    }

    @Test("Export writes images and creates a daily note")
    func exportWritesFiles() throws {
        var exporter = makeExporter()
        exporter.attachmentFolder = "attachments"
        exporter.dailyNoteFolder = ""
        exporter.includeOCRText = true

        let vault = temporaryVault()
        let capture = makeCapture()
        capture.extractedTitle = "Exported Capture"
        capture.ocrText = "Recognized text"
        capture.images = [
            CaptureImage(imageData: Data([0xFF, 0xD8, 0xFF]), pageIndex: 0),
            CaptureImage(imageData: Data([0xFF, 0xD8, 0xFE]), pageIndex: 1)
        ]

        try exporter.export(capture, to: vault)

        let dailyNote = vault.appendingPathComponent("2026-03-24.md")
        let attachmentDir = vault.appendingPathComponent("attachments")
        let dailyText = try String(contentsOf: dailyNote, encoding: .utf8)
        let imagePrefix = "capture-\(attachmentDateString(for: capture.createdAt))"

        #expect(dailyText.contains("# March 24, 2026"))
        #expect(dailyText.contains("### Exported Capture"))
        #expect(dailyText.contains("![[\(imagePrefix)-p1.jpg]]"))
        #expect(dailyText.contains("> Recognized text"))
        #expect(FileManager.default.fileExists(
            atPath: attachmentDir.appendingPathComponent("\(imagePrefix)-p1.jpg").path
        ))
        #expect(FileManager.default.fileExists(
            atPath: attachmentDir.appendingPathComponent("\(imagePrefix)-p2.jpg").path
        ))
    }

    @Test("Export appends to an existing daily note")
    func exportAppendsToExistingDailyNote() throws {
        var exporter = makeExporter()
        exporter.attachmentFolder = "attachments"
        exporter.dailyNoteFolder = ""

        let vault = temporaryVault()
        let dailyNote = vault.appendingPathComponent("2026-03-24.md")
        try "Existing note".write(to: dailyNote, atomically: true, encoding: .utf8)

        let capture = makeCapture()
        capture.extractedTitle = "Second Capture"
        capture.images = [CaptureImage(imageData: Data([1]), pageIndex: 0)]

        try exporter.export(capture, to: vault)

        let dailyText = try String(contentsOf: dailyNote, encoding: .utf8)
        #expect(dailyText.hasPrefix("Existing note\n\n### Second Capture"))
    }

    @Test("Configured export requires a selected vault")
    func configuredExportRequiresVaultBookmark() {
        let exporter = makeExporter()
        exporter.clearVault()
        let error = ObsidianExporter.ExportError.notConfigured

        #expect(throws: ObsidianExporter.ExportError.self) {
            try exporter.export(makeCapture())
        }
        #expect(error.errorDescription?.contains("vault") == true)
    }

    private func makeCapture() -> Capture {
        let capture = Capture()
        capture.createdAt = fixedDate()
        return capture
    }

    private func fixedDate() -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 2026
        components.month = 3
        components.day = 24
        components.hour = 14
        components.minute = 30
        return components.date!
    }

    private func attachmentDateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }

    private func temporaryVault() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("QuillStackTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeExporter() -> ObsidianExporter {
        let suiteName = "QuillStackTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return ObsidianExporter(userDefaults: defaults)
    }
}
