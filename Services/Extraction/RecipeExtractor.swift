import Foundation

/// Extracts structured recipe data from note content using LLM with heuristic fallback.
struct RecipeExtractor {

    /// Extracts recipe data from note content
    static func extractRecipe(from content: String) async throws -> ExtractedRecipe {
        // Try LLM extraction first if API key is available
        let settings = await SettingsManager.shared
        if let apiKey = await settings.claudeAPIKey, !apiKey.isEmpty {
            do {
                return try await extractWithLLM(from: content)
            } catch {
                print("[RecipeExtractor] LLM extraction failed: \(error.localizedDescription), falling back to heuristic")
            }
        }

        // Fall back to heuristic extraction
        return extractWithHeuristics(from: content)
    }

    // MARK: - LLM Extraction

    private static func extractWithLLM(from content: String) async throws -> ExtractedRecipe {
        let prompt = """
        Extract recipe information from this handwritten note. Return valid JSON with this exact structure:
        {
            "title": "recipe name or null",
            "ingredients": ["ingredient 1", "ingredient 2"],
            "steps": ["step 1", "step 2"],
            "servings": "serving count or null",
            "cookTime": "cooking time or null",
            "prepTime": "prep time or null",
            "notes": "additional notes or null"
        }

        Guidelines:
        - Extract all ingredients with quantities (e.g., "2 cups flour")
        - Extract steps in order
        - Parse serving count (e.g., "serves 4" → "4", "makes 12 cookies" → "12")
        - Parse times as written (e.g., "30 minutes", "1 hour")
        - Include any tips, variations, or notes at the end
        - Return empty arrays if no ingredients or steps found

        Note content:
        \(content)
        """

        let response = try await LLMService.shared.performRequest(prompt: prompt, maxTokens: 500)
        let cleanedResponse = cleanJSONResponse(response)
        guard let jsonData = cleanedResponse.data(using: .utf8) else {
            throw RecipeExtractionError.invalidResponse
        }

        let decoder = JSONDecoder()
        return try decoder.decode(ExtractedRecipe.self, from: jsonData)
    }

    // MARK: - Heuristic Extraction

    private static func extractWithHeuristics(from content: String) -> ExtractedRecipe {
        let lines = content.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }

        var title: String?
        var ingredients: [String] = []
        var steps: [String] = []
        var servings: String?
        var cookTime: String?
        var prepTime: String?
        var notes: String?

        var currentSection: Section = .unknown

        for line in lines where !line.isEmpty {
            let lowercased = line.lowercased()

            // Detect section headers
            if lowercased.contains("ingredient") {
                currentSection = .ingredients
                continue
            } else if lowercased.contains("direction") || lowercased.contains("instruction") || lowercased.contains("steps") {
                currentSection = .steps
                continue
            } else if lowercased.contains("note") && ingredients.count > 0 {
                currentSection = .notes
                continue
            }

            // Extract title (first meaningful line before ingredients)
            if title == nil && currentSection == .unknown && !isIngredientLine(line) && !isStepLine(line) {
                let cleaned = line.trimmingCharacters(in: CharacterSet(charactersIn: ":#-"))
                if cleaned.count >= 3 && cleaned.count <= 60 {
                    title = cleaned
                    continue
                }
            }

            // Extract servings
            if let servingMatch = extractServings(from: line) {
                servings = servingMatch
            }

            // Extract times
            if let timeMatch = extractTime(from: line, type: "cook") {
                cookTime = timeMatch
            }
            if let timeMatch = extractTime(from: line, type: "prep") {
                prepTime = timeMatch
            }

            // Extract ingredients
            if currentSection == .ingredients || (currentSection == .unknown && isIngredientLine(line)) {
                currentSection = .ingredients
                let cleaned = cleanIngredientLine(line)
                if !cleaned.isEmpty {
                    ingredients.append(cleaned)
                }
                continue
            }

            // Extract steps
            if currentSection == .steps || (currentSection == .unknown && isStepLine(line)) {
                currentSection = .steps
                let cleaned = cleanStepLine(line)
                if !cleaned.isEmpty {
                    steps.append(cleaned)
                }
                continue
            }

            // Collect notes
            if currentSection == .notes {
                if notes == nil {
                    notes = line
                } else {
                    notes? += "\n" + line
                }
            }
        }

        return ExtractedRecipe(
            title: title,
            ingredients: ingredients,
            steps: steps,
            servings: servings,
            cookTime: cookTime,
            prepTime: prepTime,
            notes: notes
        )
    }

    // MARK: - Helpers

    private enum Section {
        case unknown, ingredients, steps, notes
    }

    private static func isIngredientLine(_ line: String) -> Bool {
        let lowercased = line.lowercased()

        // Check for measurement units
        let measurements = ["cup", "tbsp", "tsp", "oz", "lb", "g", "kg", "ml", "l", "pinch", "dash", "handful"]
        for measurement in measurements {
            if lowercased.contains(measurement) {
                return true
            }
        }

        // Check for numbers (quantities)
        if line.rangeOfCharacter(from: .decimalDigits) != nil {
            // But exclude lines that look like step numbers
            if !line.hasPrefix("1.") && !line.hasPrefix("2.") && !line.hasPrefix("3.") {
                return true
            }
        }

        // Check for bullet points with ingredient-like content
        if line.hasPrefix("-") || line.hasPrefix("•") || line.hasPrefix("*") {
            return true
        }

        return false
    }

    private static func isStepLine(_ line: String) -> Bool {
        let lowercased = line.lowercased()

        // Check for step numbers
        let stepPattern = #"^(\d+[\.):]|step \d+)"#
        if line.range(of: stepPattern, options: .regularExpression) != nil {
            return true
        }

        // Check for cooking verbs
        let cookingVerbs = ["mix", "stir", "bake", "cook", "heat", "add", "combine", "whisk", "pour", "fold", "beat", "melt", "boil", "simmer", "fry", "sauté", "roast", "grill", "blend", "chop", "dice", "slice"]
        for verb in cookingVerbs {
            if lowercased.hasPrefix(verb) || lowercased.contains(" \(verb) ") {
                return true
            }
        }

        return false
    }

    private static func cleanIngredientLine(_ line: String) -> String {
        var cleaned = line

        // Remove bullet points
        if cleaned.hasPrefix("-") || cleaned.hasPrefix("•") || cleaned.hasPrefix("*") {
            cleaned = String(cleaned.dropFirst()).trimmingCharacters(in: .whitespaces)
        }

        return cleaned
    }

    private static func cleanStepLine(_ line: String) -> String {
        var cleaned = line

        // Remove step numbers
        if let range = cleaned.range(of: #"^\d+[\.):\s]+"#, options: .regularExpression) {
            cleaned = String(cleaned[range.upperBound...])
        }

        // Remove "Step N:" prefix
        if let range = cleaned.range(of: #"^step \d+:?\s*"#, options: [.regularExpression, .caseInsensitive]) {
            cleaned = String(cleaned[range.upperBound...])
        }

        return cleaned.trimmingCharacters(in: .whitespaces)
    }

    private static func extractServings(from line: String) -> String? {
        let lowercased = line.lowercased()

        // Pattern: "serves 4", "makes 12", "yields 6 portions"
        let patterns = [
            #"serves?\s+(\d+)"#,
            #"makes?\s+(\d+)"#,
            #"yields?\s+(\d+)"#,
            #"(\d+)\s+servings?"#,
            #"(\d+)\s+portions?"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
               let range = Range(match.range(at: 1), in: line) {
                return String(line[range])
            }
        }

        return nil
    }

    private static func extractTime(from line: String, type: String) -> String? {
        let lowercased = line.lowercased()

        guard lowercased.contains(type) else {
            return nil
        }

        // Pattern: "30 minutes", "1 hour", "1.5 hours", "45 min"
        let pattern = #"(\d+(?:\.\d+)?)\s*(hour|hr|minute|min)s?"#

        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
           let fullRange = Range(match.range, in: line) {
            return String(line[fullRange])
        }

        return nil
    }

    /// Clean JSON response by removing markdown code blocks
    private static func cleanJSONResponse(_ response: String) -> String {
        var cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove markdown code blocks
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
}

// MARK: - Errors

enum RecipeExtractionError: LocalizedError {
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

// MARK: - Data Model

struct ExtractedRecipe: Codable, Sendable, Equatable {
    let title: String?
    let ingredients: [String]
    let steps: [String]
    let servings: String?
    let cookTime: String?
    let prepTime: String?
    let notes: String?

    var hasMinimumData: Bool {
        !ingredients.isEmpty || !steps.isEmpty
    }
}
