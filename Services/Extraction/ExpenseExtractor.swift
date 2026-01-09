import Foundation

/// Extracts structured expense data from note content using LLM with heuristic fallback.
struct ExpenseExtractor {

    /// Extracts expense data from note content
    static func extractExpense(from content: String) async throws -> ExtractedExpense {
        // Try LLM extraction first if API key is available
        let settings = await SettingsManager.shared
        if let apiKey = await settings.claudeAPIKey, !apiKey.isEmpty {
            do {
                return try await extractWithLLM(from: content)
            } catch {
                print("[ExpenseExtractor] LLM extraction failed: \(error.localizedDescription), falling back to heuristic")
            }
        }

        // Fall back to heuristic extraction
        return extractWithHeuristics(from: content)
    }

    // MARK: - LLM Extraction

    private static func extractWithLLM(from content: String) async throws -> ExtractedExpense {
        let prompt = """
        Extract expense information from this handwritten note or receipt. Return valid JSON with this exact structure:
        {
            "merchant": "merchant name or null",
            "amount": 123.45 or null,
            "currency": "USD" or null,
            "date": "YYYY-MM-DD or null",
            "category": "category or null",
            "paymentMethod": "payment method or null",
            "notes": "additional notes or null"
        }

        Guidelines:
        - Extract merchant/vendor name
        - Parse amount as number (e.g., "$123.45" → 123.45)
        - Detect currency (default USD if $ symbol)
        - Parse date in YYYY-MM-DD format
        - Categorize: food, transport, shopping, utilities, entertainment, health, other
        - Detect payment method: cash, card, credit, debit, mobile
        - Include any notes about the expense

        Note content:
        \(content)
        """

        let response = try await LLMService.shared.performRequest(prompt: prompt, maxTokens: 500)
        let cleanedResponse = cleanJSONResponse(response)
        guard let jsonData = cleanedResponse.data(using: .utf8) else {
            throw ExpenseExtractionError.invalidResponse
        }

        let decoder = JSONDecoder()
        return try decoder.decode(ExtractedExpense.self, from: jsonData)
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

    private static func extractWithHeuristics(from content: String) -> ExtractedExpense {
        let lines = content.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }

        var merchant: String?
        var amount: Double?
        var currency: String = "USD"
        var date: String?
        var category: String?
        var paymentMethod: String?
        var notes: [String] = []

        for line in lines where !line.isEmpty {
            let lowercased = line.lowercased()

            // Extract amount (priority: look for $ signs first)
            if amount == nil, let extractedAmount = extractAmount(from: line) {
                amount = extractedAmount

                // Detect currency
                if line.contains("€") {
                    currency = "EUR"
                } else if line.contains("£") {
                    currency = "GBP"
                } else if line.contains("¥") {
                    currency = "JPY"
                }
                continue
            }

            // Extract merchant (first meaningful line without amount)
            if merchant == nil && !containsAmount(line) {
                let cleaned = line.trimmingCharacters(in: CharacterSet(charactersIn: ":#-"))
                if cleaned.count >= 3 && cleaned.count <= 60 {
                    merchant = cleaned
                    continue
                }
            }

            // Extract date
            if date == nil, let extractedDate = extractDate(from: line) {
                date = extractedDate
                continue
            }

            // Extract category
            if category == nil, let extractedCategory = extractCategory(from: lowercased) {
                category = extractedCategory
                continue
            }

            // Extract payment method
            if paymentMethod == nil, let extractedMethod = extractPaymentMethod(from: lowercased) {
                paymentMethod = extractedMethod
                continue
            }

            // Collect notes (non-matching lines)
            if merchant != nil && amount != nil {
                notes.append(line)
            }
        }

        return ExtractedExpense(
            merchant: merchant,
            amount: amount,
            currency: currency,
            date: date,
            category: category,
            paymentMethod: paymentMethod,
            notes: notes.isEmpty ? nil : notes.joined(separator: "\n")
        )
    }

    // MARK: - Helpers

    private static func containsAmount(_ line: String) -> Bool {
        return line.contains("$") || line.contains("€") || line.contains("£") || line.contains("¥") ||
               line.range(of: #"\d+\.\d{2}"#, options: .regularExpression) != nil
    }

    private static func extractAmount(from line: String) -> Double? {
        // Pattern: $123.45, 123.45, $123
        let patterns = [
            #"[$€£¥]\s*(\d+(?:,\d{3})*(?:\.\d{2})?)"#,  // Currency symbol prefix
            #"(\d+(?:,\d{3})*(?:\.\d{2}))\s*[$€£¥]"#,    // Currency symbol suffix
            #"(\d+(?:,\d{3})*\.\d{2})"#                   // Just numbers with decimals
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
               let range = Range(match.range(at: 1), in: line) {
                let amountString = String(line[range]).replacingOccurrences(of: ",", with: "")
                return Double(amountString)
            }
        }

        return nil
    }

    private static func extractDate(from line: String) -> String? {
        let patterns = [
            (#"(\d{4})-(\d{2})-(\d{2})"#, "YYYY-MM-DD"),           // Already ISO
            (#"(\d{2})/(\d{2})/(\d{4})"#, "MM/DD/YYYY"),           // US format
            (#"(\d{2})-(\d{2})-(\d{4})"#, "DD-MM-YYYY")            // European format
        ]

        for (pattern, format) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
               let fullRange = Range(match.range, in: line) {

                let dateString = String(line[fullRange])

                // Convert to YYYY-MM-DD
                if format == "YYYY-MM-DD" {
                    return dateString
                } else if format == "MM/DD/YYYY" {
                    let components = dateString.split(separator: "/")
                    if components.count == 3 {
                        return "\(components[2])-\(components[0])-\(components[1])"
                    }
                } else if format == "DD-MM-YYYY" {
                    let components = dateString.split(separator: "-")
                    if components.count == 3 {
                        return "\(components[2])-\(components[1])-\(components[0])"
                    }
                }
            }
        }

        return nil
    }

    private static func extractCategory(from lowercased: String) -> String? {
        let categories: [String: [String]] = [
            "food": ["restaurant", "food", "dining", "lunch", "dinner", "breakfast", "cafe", "coffee"],
            "transport": ["uber", "lyft", "taxi", "gas", "fuel", "parking", "transit", "metro", "bus"],
            "shopping": ["store", "amazon", "shop", "retail", "purchase", "buy"],
            "utilities": ["electric", "water", "gas", "internet", "phone", "utility"],
            "entertainment": ["movie", "concert", "game", "ticket", "show", "theater"],
            "health": ["pharmacy", "doctor", "hospital", "medical", "health", "clinic"],
            "travel": ["hotel", "flight", "airline", "booking", "airbnb"]
        ]

        for (category, keywords) in categories {
            for keyword in keywords {
                if lowercased.contains(keyword) {
                    return category
                }
            }
        }

        return nil
    }

    private static func extractPaymentMethod(from lowercased: String) -> String? {
        let methods: [String: [String]] = [
            "cash": ["cash", "paid cash"],
            "credit": ["credit", "credit card"],
            "debit": ["debit", "debit card"],
            "card": ["card"],
            "mobile": ["apple pay", "venmo", "paypal", "zelle", "cashapp"]
        ]

        for (method, keywords) in methods {
            for keyword in keywords {
                if lowercased.contains(keyword) {
                    return method
                }
            }
        }

        return nil
    }
}

// MARK: - Data Model

struct ExtractedExpense: Codable, Sendable, Equatable {
    let merchant: String?
    let amount: Double?
    let currency: String
    let date: String?
    let category: String?
    let paymentMethod: String?
    let notes: String?

    var hasMinimumData: Bool {
        merchant != nil || amount != nil
    }

    var formattedAmount: String? {
        guard let amount = amount else { return nil }

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: amount))
    }
}

// MARK: - Errors

enum ExpenseExtractionError: LocalizedError {
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
