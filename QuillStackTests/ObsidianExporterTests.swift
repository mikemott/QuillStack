import Testing
import Foundation
@testable import QuillStack

@Suite("Obsidian Exporter")
struct ObsidianExporterTests {

    // MARK: - Daily note URL

    @Test("Daily note URL uses yyyy-MM-dd format")
    func dailyNoteFilename() {
        let exporter = ObsidianExporter()
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 24
        let date = Calendar.current.date(from: components)!
        let vault = URL(fileURLWithPath: "/vault")

        let url = exporter.dailyNoteURL(for: date, vaultURL: vault)
        #expect(url.lastPathComponent == "2026-03-24.md")
    }

    @Test("Daily note URL uses .md extension")
    func dailyNoteExtension() {
        let exporter = ObsidianExporter()
        let date = Date()
        let vault = URL(fileURLWithPath: "/vault")

        let url = exporter.dailyNoteURL(for: date, vaultURL: vault)
        #expect(url.pathExtension == "md")
    }

    @Test("Daily note URL for Jan 1 formats correctly")
    func dailyNoteJanuary() {
        let exporter = ObsidianExporter()
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 1
        let date = Calendar.current.date(from: components)!
        let vault = URL(fileURLWithPath: "/vault")

        let url = exporter.dailyNoteURL(for: date, vaultURL: vault)
        #expect(url.lastPathComponent == "2026-01-01.md")
    }

    // MARK: - Tag normalization (testing the pattern used in buildMarkdown)

    @Test("Tags are lowercased and spaces replaced with hyphens")
    func tagNormalization() {
        let tagNames = ["Receipt", "Work", "Personal Note"]
        let normalized = tagNames.map { "#\($0.lowercased().replacingOccurrences(of: " ", with: "-"))" }
        #expect(normalized == ["#receipt", "#work", "#personal-note"])
    }

    @Test("Single-word tags are just lowercased")
    func singleWordTag() {
        let tag = "Event"
        let normalized = "#\(tag.lowercased().replacingOccurrences(of: " ", with: "-"))"
        #expect(normalized == "#event")
    }

    @Test("Tag with multiple spaces normalizes correctly")
    func multiSpaceTag() {
        let tag = "My Custom Tag"
        let normalized = "#\(tag.lowercased().replacingOccurrences(of: " ", with: "-"))"
        #expect(normalized == "#my-custom-tag")
    }

    // MARK: - OCR blockquote formatting (testing the pattern used in buildMarkdown)

    @Test("OCR text newlines become blockquote continuations")
    func ocrBlockquote() {
        let text = "Line 1\nLine 2\nLine 3"
        let formatted = "> \(text.replacingOccurrences(of: "\n", with: "\n> "))"
        #expect(formatted == "> Line 1\n> Line 2\n> Line 3")
    }

    @Test("Single-line OCR text is a simple blockquote")
    func singleLineOcr() {
        let text = "Just one line"
        let formatted = "> \(text.replacingOccurrences(of: "\n", with: "\n> "))"
        #expect(formatted == "> Just one line")
    }

    @Test("Empty OCR text produces empty blockquote")
    func emptyOcr() {
        let text = ""
        let formatted = "> \(text.replacingOccurrences(of: "\n", with: "\n> "))"
        #expect(formatted == "> ")
    }

    // MARK: - Image filename pattern

    @Test("Single image filename has no page suffix")
    func singleImageFilename() {
        let dateString = "20260324-143000"
        let isStack = false
        let suffix = isStack ? "-p1" : ""
        let filename = "capture-\(dateString)\(suffix).jpg"
        #expect(filename == "capture-20260324-143000.jpg")
    }

    @Test("Stack images have page suffixes")
    func stackImageFilenames() {
        let dateString = "20260324-143000"
        let filenames = (0..<3).map { index in
            "capture-\(dateString)-p\(index + 1).jpg"
        }
        #expect(filenames == [
            "capture-20260324-143000-p1.jpg",
            "capture-20260324-143000-p2.jpg",
            "capture-20260324-143000-p3.jpg"
        ])
    }

    // MARK: - Obsidian image embed syntax

    @Test("Image embed uses wiki-link syntax")
    func imageEmbed() {
        let filename = "capture-20260324-143000.jpg"
        let embed = "![[\(filename)]]"
        #expect(embed == "![[capture-20260324-143000.jpg]]")
    }

    // MARK: - Export error

    @Test("ExportError has descriptive message")
    func errorDescription() {
        let error = ObsidianExporter.ExportError.notConfigured
        #expect(error.errorDescription?.contains("vault") == true)
    }
}
