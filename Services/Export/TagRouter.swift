//
//  TagRouter.swift
//  QuillStack
//
//  Created on 2025-12-18.
//

import Foundation

// MARK: - Tag Router

/// Routes notes to folders/databases based on hashtag content
/// Supports hierarchical paths: #work# #project-acme# → Work/Projects/Acme
class TagRouter {

    // Type triggers to ignore (these classify note type, not destination)
    private let typeTriggers: Set<String> = [
        "todo", "to-do", "tasks", "task",
        "email", "mail",
        "meeting", "notes", "minutes"
    ]

    // MARK: - Public API

    /// Extract routing tags from content (excludes type triggers)
    func extractTags(from content: String) -> [String] {
        let pattern = "#([a-zA-Z0-9_-]+)#"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return []
        }

        let range = NSRange(content.startIndex..., in: content)
        let matches = regex.matches(in: content, options: [], range: range)

        var tags: [String] = []

        for match in matches {
            if let tagRange = Range(match.range(at: 1), in: content) {
                let tag = String(content[tagRange]).lowercased()

                // Skip type triggers
                if !typeTriggers.contains(tag) {
                    tags.append(tag)
                }
            }
        }

        return tags
    }

    /// Resolve tags to a hierarchical path for the given destination
    /// Example: ["work", "project-acme"] → "Work/Projects/Acme"
    func resolvePath(tags: [String], for destination: ExportDestinationType) -> String {
        guard !tags.isEmpty else {
            return defaultPath(for: destination)
        }

        var pathComponents: [String] = []

        for tag in tags {
            // Check for user-configured mapping
            if let mappedPath = getMappedPath(for: tag, destination: destination) {
                // If mapped path has slashes, add all components
                let components = mappedPath.components(separatedBy: "/")
                pathComponents.append(contentsOf: components)
            } else {
                // Use tag as-is, with title case
                pathComponents.append(formatTagForPath(tag))
            }
        }

        return pathComponents.joined(separator: pathSeparator(for: destination))
    }

    /// Get the default path/folder for a destination
    func defaultPath(for destination: ExportDestinationType) -> String {
        switch destination {
        case .appleNotes:
            return "" // Apple Notes uses default folder
        case .obsidian:
            return SettingsManager.shared.obsidianDefaultFolder
        case .notion:
            return "" // Notion uses default database
        case .pdf:
            return "" // PDF exports directly to share sheet
        }
    }

    // MARK: - Tag Mapping

    /// Get user-configured mapping for a tag
    func getMappedPath(for tag: String, destination: ExportDestinationType) -> String? {
        let mappings = SettingsManager.shared.exportTagMappings
        let key = "\(destination.rawValue):\(tag.lowercased())"
        return mappings[key] ?? mappings[tag.lowercased()]
    }

    /// Set a tag mapping
    func setMapping(tag: String, path: String, for destination: ExportDestinationType) {
        var mappings = SettingsManager.shared.exportTagMappings
        let key = "\(destination.rawValue):\(tag.lowercased())"
        mappings[key] = path
        SettingsManager.shared.exportTagMappings = mappings
    }

    /// Remove a tag mapping
    func removeMapping(tag: String, for destination: ExportDestinationType) {
        var mappings = SettingsManager.shared.exportTagMappings
        let key = "\(destination.rawValue):\(tag.lowercased())"
        mappings.removeValue(forKey: key)
        SettingsManager.shared.exportTagMappings = mappings
    }

    /// Get all mappings for a destination
    func getMappings(for destination: ExportDestinationType) -> [String: String] {
        let prefix = "\(destination.rawValue):"
        let allMappings = SettingsManager.shared.exportTagMappings

        var result: [String: String] = [:]
        for (key, value) in allMappings {
            if key.hasPrefix(prefix) {
                let tag = String(key.dropFirst(prefix.count))
                result[tag] = value
            } else if !key.contains(":") {
                // Global mapping (applies to all destinations)
                result[key] = value
            }
        }
        return result
    }

    // MARK: - Private Helpers

    private func pathSeparator(for destination: ExportDestinationType) -> String {
        switch destination {
        case .obsidian:
            return "/"
        case .notion:
            return "/" // Notion doesn't use paths, but we can use for display
        case .appleNotes:
            return "/" // Apple Notes folders
        case .pdf:
            return "/" // Not used for PDF but included for completeness
        }
    }

    private func formatTagForPath(_ tag: String) -> String {
        // Convert kebab-case or snake_case to Title Case
        let words = tag
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .components(separatedBy: " ")

        return words
            .map { $0.capitalized }
            .joined(separator: " ")
    }
}

// MARK: - Tag Mapping Model

struct TagMapping: Identifiable, Codable {
    let id: UUID
    var tag: String
    var path: String
    var destination: String? // nil = applies to all

    init(id: UUID = UUID(), tag: String, path: String, destination: ExportDestinationType? = nil) {
        self.id = id
        self.tag = tag
        self.path = path
        self.destination = destination?.rawValue
    }
}
