import Foundation
import OSLog

/// Extracts structured shopping list data from note content using LLM with heuristic fallback.
struct ShoppingExtractor {

    private static let logger = Logger(subsystem: "com.quillstack", category: "ShoppingExtraction")

    /// Extracts shopping list data from note content
    static func extractShoppingList(from content: String) async throws -> ExtractedShoppingList {
        // Try LLM extraction first if API key is available
        let settings = await SettingsManager.shared
        if let apiKey = await settings.claudeAPIKey, !apiKey.isEmpty {
            do {
                return try await extractWithLLM(from: content)
            } catch {
                logger.info("LLM extraction failed, falling back to heuristic")
            }
        }

        // Fall back to heuristic extraction
        return extractWithHeuristics(from: content)
    }

    // MARK: - LLM Extraction

    private static func extractWithLLM(from content: String) async throws -> ExtractedShoppingList {
        let prompt = """
        Extract shopping list information from this handwritten note. Return valid JSON with this exact structure:
        {
            "storeName": "store name or null",
            "items": [
                {
                    "name": "item name",
                    "quantity": "quantity or null",
                    "isChecked": false,
                    "category": "category or null"
                }
            ],
            "notes": "additional notes or null"
        }

        Guidelines:
        - Extract store name if mentioned (e.g., "Costco list", "Whole Foods")
        - Parse each item with quantity if provided (e.g., "2 apples", "1 gallon milk")
        - Detect checked items: [x], ✓, checkmark
        - Categorize items: produce, dairy, meat, bakery, pantry, frozen, household, other
        - Include any notes or reminders

        Note content:
        \(content)
        """

        let response = try await LLMService.shared.performRequest(prompt: prompt, maxTokens: 500)
        let cleanedResponse = cleanJSONResponse(response)
        guard let jsonData = cleanedResponse.data(using: .utf8) else {
            throw ShoppingExtractionError.invalidResponse
        }

        let decoder = JSONDecoder()
        return try decoder.decode(ExtractedShoppingList.self, from: jsonData)
    }

    /// Clean JSON response by removing markdown code blocks
    private static func cleanJSONResponse(_ response: String) -> String {
        var cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)

        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }

        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Heuristic Extraction

    private static func extractWithHeuristics(from content: String) -> ExtractedShoppingList {
        let lines = content.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }

        var storeName: String?
        var items: [ExtractedShoppingItem] = []
        var notes: [String] = []

        for line in lines where !line.isEmpty {
            let lowercased = line.lowercased()

            // Extract store name (first line with store keywords)
            if storeName == nil {
                let storeKeywords = ["costco", "walmart", "target", "whole foods", "trader joe", "safeway", "kroger", "store", "market", "shop"]
                for keyword in storeKeywords {
                    if lowercased.contains(keyword) {
                        storeName = line.trimmingCharacters(in: CharacterSet(charactersIn: ":#-"))
                        break
                    }
                }
                if storeName != nil {
                    continue
                }
            }

            // Check if line is an item (has checkbox or bullet)
            if isItemLine(line) {
                if let item = parseItem(from: line) {
                    items.append(item)
                }
            } else if !items.isEmpty {
                // Collect notes after items start
                notes.append(line)
            }
        }

        return ExtractedShoppingList(
            storeName: storeName,
            items: items,
            notes: notes.isEmpty ? nil : notes.joined(separator: "\n")
        )
    }

    // MARK: - Helpers

    private static func isItemLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Check for checkboxes
        if trimmed.hasPrefix("[ ]") || trimmed.hasPrefix("[x]") || trimmed.hasPrefix("[X]") ||
           trimmed.hasPrefix("☐") || trimmed.hasPrefix("☑") || trimmed.hasPrefix("✓") ||
           trimmed.hasPrefix("✔") {
            return true
        }

        // Check for bullet points
        if trimmed.hasPrefix("-") || trimmed.hasPrefix("•") || trimmed.hasPrefix("*") {
            return true
        }

        // Check for numbered items
        if trimmed.range(of: #"^\d+[\.)]\s"#, options: .regularExpression) != nil {
            return true
        }

        return false
    }

    private static func parseItem(from line: String) -> ExtractedShoppingItem? {
        var cleaned = line.trimmingCharacters(in: .whitespaces)
        var isChecked = false

        // Detect checked status
        if cleaned.hasPrefix("[x]") || cleaned.hasPrefix("[X]") || cleaned.hasPrefix("☑") || cleaned.hasPrefix("✓") || cleaned.hasPrefix("✔") {
            isChecked = true
        }

        // Remove checkbox/bullet markers
        let prefixes = ["[ ]", "[x]", "[X]", "☐", "☑", "✓", "✔", "-", "•", "*"]
        for prefix in prefixes {
            if cleaned.hasPrefix(prefix) {
                cleaned = String(cleaned.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                break
            }
        }

        // Remove numbered list markers
        if let range = cleaned.range(of: #"^\d+[\.)]\s+"#, options: .regularExpression) {
            cleaned = String(cleaned[range.upperBound...])
        }

        // Extract quantity and name
        let (quantity, name) = extractQuantityAndName(from: cleaned)

        guard !name.isEmpty else {
            return nil
        }

        // Detect category
        let category = detectCategory(for: name.lowercased())

        return ExtractedShoppingItem(
            name: name,
            quantity: quantity,
            isChecked: isChecked,
            category: category
        )
    }

    private static func extractQuantityAndName(from text: String) -> (quantity: String?, name: String) {
        // Pattern: "2 apples", "1 gallon milk", "3 lbs chicken"
        let pattern = #"^(\d+(?:\.\d+)?)\s+(lb|lbs|oz|kg|g|gallon|quart|pint|cup|package|bag|box|can)s?\s+"#

        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let quantityRange = Range(match.range, in: text) {
            let quantity = String(text[quantityRange]).trimmingCharacters(in: .whitespaces)
            let name = String(text[quantityRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            return (quantity, name)
        }

        // Simpler pattern: just number at start
        if let regex = try? NSRegularExpression(pattern: #"^(\d+)\s+"#),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let quantityRange = Range(match.range(at: 1), in: text) {
            let quantity = String(text[quantityRange])
            let name = String(text[quantityRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            return (quantity, name)
        }

        return (nil, text)
    }

    private static func detectCategory(for item: String) -> String? {
        let categories: [String: [String]] = [
            "produce": ["apple", "banana", "orange", "lettuce", "tomato", "carrot", "onion", "potato", "fruit", "vegetable"],
            "dairy": ["milk", "cheese", "yogurt", "butter", "cream", "eggs"],
            "meat": ["chicken", "beef", "pork", "fish", "turkey", "bacon", "sausage"],
            "bakery": ["bread", "bagel", "donut", "cake", "pastry"],
            "pantry": ["rice", "pasta", "flour", "sugar", "oil", "cereal", "can"],
            "frozen": ["ice cream", "frozen", "pizza"],
            "household": ["detergent", "soap", "paper towel", "toilet paper", "cleaner"]
        ]

        for (category, keywords) in categories {
            for keyword in keywords {
                if item.contains(keyword) {
                    return category
                }
            }
        }

        return nil
    }
}

// MARK: - Errors

enum ShoppingExtractionError: LocalizedError {
    case noAPIKey
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No API key configured"
        case .invalidResponse:
            return "Invalid response from AI service"
        }
    }
}

// MARK: - Data Models

struct ExtractedShoppingList: Codable, Sendable, Equatable {
    let storeName: String?
    let items: [ExtractedShoppingItem]
    let notes: String?

    var hasMinimumData: Bool {
        !items.isEmpty
    }

    var uncheckedCount: Int {
        items.filter { !$0.isChecked }.count
    }
}

struct ExtractedShoppingItem: Codable, Sendable, Equatable, Identifiable {
    let id: UUID
    let name: String
    let quantity: String?
    let isChecked: Bool
    let category: String?

    init(name: String, quantity: String? = nil, isChecked: Bool = false, category: String? = nil) {
        self.id = UUID()
        self.name = name
        self.quantity = quantity
        self.isChecked = isChecked
        self.category = category
    }

    var displayName: String {
        if let quantity = quantity {
            return "\(quantity) \(name)"
        }
        return name
    }
}
