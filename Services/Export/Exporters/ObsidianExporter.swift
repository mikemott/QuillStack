//
//  ObsidianExporter.swift
//  QuillStack
//
//  Created on 2025-12-18.
//

import Foundation
import UIKit

// MARK: - Obsidian Exporter

/// Exports notes as Markdown files to an Obsidian vault
class ObsidianExporter: ExportDestination {
    let type: ExportDestinationType = .obsidian

    private let fileManager = FileManager.default
    private let markdownBuilder = MarkdownBuilder()

    // MARK: - Configuration

    func isConfigured() -> Bool {
        guard let vaultPath = SettingsManager.shared.obsidianVaultPath,
              !vaultPath.isEmpty else {
            return false
        }

        // Check if path exists and is accessible
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: vaultPath, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    func getMissingConfiguration() -> [String] {
        var missing: [String] = []

        if SettingsManager.shared.obsidianVaultPath == nil {
            missing.append("Vault path not set")
        } else if !isConfigured() {
            missing.append("Vault path is not accessible")
        }

        return missing
    }

    // MARK: - Export

    func export(request: ExportRequest) async throws -> ExportResult {
        guard let vaultPath = SettingsManager.shared.obsidianVaultPath else {
            throw ExportError.vaultPathInvalid("No vault path configured")
        }

        // Build destination folder path
        let folderPath = buildFolderPath(vaultPath: vaultPath, targetPath: request.targetPath)

        // Ensure folder exists
        try createFolderIfNeeded(at: folderPath)

        // Generate filename
        let filename = generateFilename(title: request.content.title)
        let filePath = (folderPath as NSString).appendingPathComponent(filename)

        // Build markdown content
        let markdown = markdownBuilder.build(request: request)

        // Write file
        do {
            try markdown.write(toFile: filePath, atomically: true, encoding: .utf8)
        } catch {
            throw ExportError.fileWriteFailed(error.localizedDescription)
        }

        // Handle image attachment
        if request.options.includeOriginalImage,
           let imageData = request.note.originalImageData {
            try saveImageAttachment(imageData: imageData, notePath: filePath, vaultPath: vaultPath)
        }

        // Build open URL
        let openURL = buildObsidianURL(filePath: filePath, vaultPath: vaultPath)

        // Optionally open in Obsidian
        if request.options.openAfterExport, let url = openURL {
            await openInObsidian(url: url)
        }

        return .success(
            destination: .obsidian,
            path: filePath,
            message: "Saved to Obsidian vault",
            openURL: openURL
        )
    }

    // MARK: - Private Helpers

    private func buildFolderPath(vaultPath: String, targetPath: String?) -> String {
        var path = vaultPath

        if let target = targetPath, !target.isEmpty {
            path = (path as NSString).appendingPathComponent(target)
        } else {
            let defaultFolder = SettingsManager.shared.obsidianDefaultFolder
            if !defaultFolder.isEmpty {
                path = (path as NSString).appendingPathComponent(defaultFolder)
            }
        }

        return path
    }

    private func createFolderIfNeeded(at path: String) throws {
        var isDirectory: ObjCBool = false

        if !fileManager.fileExists(atPath: path, isDirectory: &isDirectory) {
            try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true)
        } else if !isDirectory.boolValue {
            throw ExportError.vaultPathInvalid("Path exists but is not a folder: \(path)")
        }
    }

    private func generateFilename(title: String) -> String {
        // Clean title for filename
        let cleaned = title
            .replacingOccurrences(of: "[^a-zA-Z0-9\\s-]", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "\\s+", with: "-", options: .regularExpression)
            .lowercased()

        // Add timestamp for uniqueness
        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "T", with: "-")

        let slug = cleaned.isEmpty ? "note" : String(cleaned.prefix(40))

        return "\(slug)-\(timestamp.prefix(16)).md"
    }

    private func saveImageAttachment(imageData: Data, notePath: String, vaultPath: String) throws {
        // Create attachments folder
        let attachmentsPath = (vaultPath as NSString).appendingPathComponent("attachments")
        try createFolderIfNeeded(at: attachmentsPath)

        // Generate image filename
        let noteFilename = (notePath as NSString).lastPathComponent
        let imageName = noteFilename.replacingOccurrences(of: ".md", with: ".jpg")
        let imagePath = (attachmentsPath as NSString).appendingPathComponent(imageName)

        // Write image
        try imageData.write(to: URL(fileURLWithPath: imagePath))
    }

    private func buildObsidianURL(filePath: String, vaultPath: String) -> URL? {
        // Get vault name from path
        let vaultName = (vaultPath as NSString).lastPathComponent

        // Get relative file path
        let relativePath = filePath.replacingOccurrences(of: vaultPath + "/", with: "")

        // Build obsidian:// URL
        var components = URLComponents()
        components.scheme = "obsidian"
        components.host = "open"
        components.queryItems = [
            URLQueryItem(name: "vault", value: vaultName),
            URLQueryItem(name: "file", value: relativePath)
        ]

        return components.url
    }

    @MainActor
    private func openInObsidian(url: URL) async {
        if UIApplication.shared.canOpenURL(url) {
            await UIApplication.shared.open(url)
        }
    }
}

// MARK: - Markdown Builder

class MarkdownBuilder {

    func build(request: ExportRequest) -> String {
        var lines: [String] = []

        // YAML frontmatter
        lines.append(contentsOf: buildFrontmatter(request: request))

        // Title
        lines.append("# \(request.content.title)")
        lines.append("")

        // Body
        lines.append(request.content.markdownBody)

        // Image embed if included
        if request.options.includeOriginalImage, request.note.originalImageData != nil {
            let noteFilename = generateImageFilename(title: request.content.title)
            lines.append("")
            lines.append("## Original")
            lines.append("![[attachments/\(noteFilename)]]")
        }

        return lines.joined(separator: "\n")
    }

    private func buildFrontmatter(request: ExportRequest) -> [String] {
        var lines: [String] = ["---"]

        // Created date
        let dateFormatter = ISO8601DateFormatter()
        lines.append("created: \(dateFormatter.string(from: request.content.metadata.createdAt))")

        // Note type
        lines.append("type: \(request.content.metadata.noteType)")

        // Tags
        if !request.content.metadata.tags.isEmpty {
            let tagList = request.content.metadata.tags.joined(separator: ", ")
            lines.append("tags: [\(tagList)]")
        }

        // OCR confidence
        if let confidence = request.content.metadata.ocrConfidence {
            lines.append("ocr_confidence: \(String(format: "%.2f", confidence))")
        }

        // Source
        lines.append("source: \(request.content.metadata.source)")

        lines.append("---")
        lines.append("")

        return lines
    }

    private func generateImageFilename(title: String) -> String {
        let cleaned = title
            .replacingOccurrences(of: "[^a-zA-Z0-9\\s-]", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "\\s+", with: "-", options: .regularExpression)
            .lowercased()

        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "T", with: "-")

        let slug = cleaned.isEmpty ? "note" : String(cleaned.prefix(40))

        return "\(slug)-\(timestamp.prefix(16)).jpg"
    }
}
