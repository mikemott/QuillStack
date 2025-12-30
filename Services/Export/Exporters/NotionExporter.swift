//
//  NotionExporter.swift
//  QuillStack
//
//  Created on 2025-12-18.
//

import Foundation
import UIKit

// MARK: - Notion Exporter

/// Exports notes to Notion via the REST API
class NotionExporter: ExportDestination {
    let type: ExportDestinationType = .notion

    private let apiClient = NotionAPIClient()

    // MARK: - Configuration

    func isConfigured() -> Bool {
        SettingsManager.shared.hasNotionAPIKey && SettingsManager.shared.hasNotionDatabase
    }

    func getMissingConfiguration() -> [String] {
        var missing: [String] = []

        if !SettingsManager.shared.hasNotionAPIKey {
            missing.append("API key not set")
        }

        if !SettingsManager.shared.hasNotionDatabase {
            missing.append("Default database not selected")
        }

        return missing
    }

    // MARK: - Export

    func export(request: ExportRequest) async throws -> ExportResult {
        guard let databaseId = SettingsManager.shared.notionDefaultDatabaseId else {
            throw ExportError.notionDatabaseNotFound
        }

        // Build page properties
        let properties = buildProperties(request: request)

        // Build page content blocks
        let children = buildContentBlocks(request: request)

        // Create page via API
        let pageUrl = try await apiClient.createPage(
            databaseId: databaseId,
            properties: properties,
            children: children
        )

        return .success(
            destination: .notion,
            path: pageUrl,
            message: "Created in Notion",
            openURL: URL(string: pageUrl)
        )
    }

    // MARK: - Property Building

    private func buildProperties(request: ExportRequest) -> [String: Any] {
        var properties: [String: Any] = [:]

        // Title property (required)
        properties["Name"] = [
            "title": [
                ["text": ["content": request.content.title]]
            ]
        ]

        // Type property (select)
        properties["Type"] = [
            "select": ["name": request.content.metadata.noteType.capitalized]
        ]

        // Tags property (multi-select)
        if !request.content.metadata.tags.isEmpty {
            properties["Tags"] = [
                "multi_select": request.content.metadata.tags.map { ["name": $0] }
            ]
        }

        // Created date
        let dateFormatter = ISO8601DateFormatter()
        properties["Created"] = [
            "date": ["start": dateFormatter.string(from: request.content.metadata.createdAt)]
        ]

        // OCR Confidence (number)
        if let confidence = request.content.metadata.ocrConfidence {
            properties["OCR Confidence"] = [
                "number": Double(confidence)
            ]
        }

        // Source
        properties["Source"] = [
            "rich_text": [
                ["text": ["content": "QuillStack"]]
            ]
        ]

        return properties
    }

    // MARK: - Content Block Building

    private func buildContentBlocks(request: ExportRequest) -> [[String: Any]] {
        var blocks: [[String: Any]] = []

        // Split content into paragraphs
        let paragraphs = request.content.plainBody.components(separatedBy: "\n\n")

        for paragraph in paragraphs {
            let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            // Check if it's a todo item
            if trimmed.hasPrefix("- [ ]") || trimmed.hasPrefix("- [x]") || trimmed.hasPrefix("\u{2610}") || trimmed.hasPrefix("\u{2611}") {
                blocks.append(contentsOf: buildTodoBlocks(from: paragraph))
            }
            // Check if it's a heading
            else if trimmed.hasPrefix("## ") {
                blocks.append(buildHeading2Block(String(trimmed.dropFirst(3))))
            } else if trimmed.hasPrefix("# ") {
                blocks.append(buildHeading1Block(String(trimmed.dropFirst(2))))
            }
            // Regular paragraph
            else {
                blocks.append(buildParagraphBlock(trimmed))
            }
        }

        return blocks
    }

    private func buildParagraphBlock(_ text: String) -> [String: Any] {
        [
            "object": "block",
            "type": "paragraph",
            "paragraph": [
                "rich_text": [
                    ["type": "text", "text": ["content": text]]
                ]
            ]
        ]
    }

    private func buildHeading1Block(_ text: String) -> [String: Any] {
        [
            "object": "block",
            "type": "heading_1",
            "heading_1": [
                "rich_text": [
                    ["type": "text", "text": ["content": text]]
                ]
            ]
        ]
    }

    private func buildHeading2Block(_ text: String) -> [String: Any] {
        [
            "object": "block",
            "type": "heading_2",
            "heading_2": [
                "rich_text": [
                    ["type": "text", "text": ["content": text]]
                ]
            ]
        ]
    }

    private func buildTodoBlocks(from text: String) -> [[String: Any]] {
        let lines = text.components(separatedBy: .newlines)
        var blocks: [[String: Any]] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            var isChecked = false
            var taskText = trimmed

            // Parse checkbox state
            if trimmed.hasPrefix("- [x]") || trimmed.hasPrefix("- [X]") {
                isChecked = true
                taskText = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("- [ ]") {
                isChecked = false
                taskText = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("\u{2611}") {
                isChecked = true
                taskText = String(trimmed.dropFirst(1)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("\u{2610}") {
                isChecked = false
                taskText = String(trimmed.dropFirst(1)).trimmingCharacters(in: .whitespaces)
            } else {
                // Not a todo, skip
                continue
            }

            blocks.append([
                "object": "block",
                "type": "to_do",
                "to_do": [
                    "rich_text": [
                        ["type": "text", "text": ["content": taskText]]
                    ],
                    "checked": isChecked
                ]
            ])
        }

        return blocks
    }
}

// MARK: - Notion API Client

class NotionAPIClient {
    private let baseURL = "https://api.notion.com/v1"
    private let apiVersion = "2022-06-28"

    /// Create a page in a database
    func createPage(databaseId: String, properties: [String: Any], children: [[String: Any]]) async throws -> String {
        guard let apiKey = SettingsManager.shared.notionAPIKey else {
            throw ExportError.notionAPIKeyMissing
        }

        let url = URL(string: "\(baseURL)/pages")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(apiVersion, forHTTPHeaderField: "Notion-Version")

        let body: [String: Any] = [
            "parent": ["database_id": databaseId],
            "properties": properties,
            "children": children
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ExportError.notionAPIError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = parseErrorMessage(from: data) ?? "Status \(httpResponse.statusCode)"
            throw ExportError.notionAPIError(errorMessage)
        }

        // Parse page URL from response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let url = json["url"] as? String else {
            throw ExportError.notionAPIError("Could not parse response")
        }

        return url
    }

    /// List databases the integration has access to
    func listDatabases() async throws -> [NotionDatabase] {
        guard let apiKey = SettingsManager.shared.notionAPIKey else {
            throw ExportError.notionAPIKeyMissing
        }

        let url = URL(string: "\(baseURL)/search")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(apiVersion, forHTTPHeaderField: "Notion-Version")

        let body: [String: Any] = [
            "filter": ["property": "object", "value": "database"]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ExportError.notionAPIError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = parseErrorMessage(from: data) ?? "Status \(httpResponse.statusCode)"
            throw ExportError.notionAPIError(errorMessage)
        }

        // Parse databases from response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]] else {
            throw ExportError.notionAPIError("Could not parse response")
        }

        var databases: [NotionDatabase] = []

        for result in results {
            guard let id = result["id"] as? String,
                  let titleArray = result["title"] as? [[String: Any]],
                  let firstTitle = titleArray.first,
                  let textObj = firstTitle["text"] as? [String: Any],
                  let name = textObj["content"] as? String else {
                continue
            }

            databases.append(NotionDatabase(id: id, name: name))
        }

        return databases
    }

    private func parseErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = json["message"] as? String else {
            return nil
        }
        return message
    }
}

// MARK: - Notion Models

struct NotionDatabase: Identifiable, Codable {
    let id: String
    let name: String
}
