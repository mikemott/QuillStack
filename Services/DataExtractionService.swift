import Foundation
import CoreData

/// Service that orchestrates structured data extraction from notes.
/// Automatically detects note type and calls the appropriate extractor,
/// storing results in the note's extractedDataJSON field.
@MainActor
final class DataExtractionService {

    // MARK: - Public Methods

    /// Extracts structured data from a note and stores it in extractedDataJSON.
    /// - Parameter note: The note to extract data from
    /// - Returns: True if extraction was successful, false otherwise
    @discardableResult
    func extractData(from note: Note) async -> Bool {
        guard !note.content.isEmpty else {
            print("[DataExtractionService] Note has no content, skipping extraction")
            return false
        }

        let noteType = note.noteType
        print("[DataExtractionService] Extracting data for note type: \(noteType)")

        do {
            let jsonString: String?

            switch noteType {
            case "contact":
                jsonString = try await extractContact(from: note.content)

            case "todo":
                jsonString = try await extractTodos(from: note.content)

            case "event":
                jsonString = try await extractEvent(from: note.content)

            case "meeting":
                // Meeting uses CoreData entity, not extractedDataJSON
                try await extractMeeting(from: note.content, for: note)
                jsonString = nil

            case "recipe":
                jsonString = try await extractRecipe(from: note.content)

            case "expense":
                jsonString = try await extractExpense(from: note.content)

            case "shopping":
                jsonString = try await extractShopping(from: note.content)

            case "email":
                jsonString = try await extractEmail(from: note.content)

            default:
                // No extraction needed for general, idea, reminder, claudePrompt types
                print("[DataExtractionService] No extraction configured for note type: \(noteType)")
                return false
            }

            // Store JSON in note
            if let jsonString = jsonString {
                note.extractedDataJSON = jsonString
                print("[DataExtractionService] Successfully extracted data for \(noteType) note")
                return true
            }

            return false

        } catch {
            print("[DataExtractionService] Extraction failed for \(noteType): \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Private Extraction Methods

    private func extractContact(from content: String) async throws -> String? {
        let contact = ContactParser.parse(content)

        // Only store if we extracted meaningful data
        guard !contact.firstName.isEmpty || !contact.lastName.isEmpty ||
              !contact.company.isEmpty || !contact.phone.isEmpty ||
              !contact.email.isEmpty else {
            return nil
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(contact)
        return String(data: data, encoding: .utf8)
    }

    private func extractTodos(from content: String) async throws -> String? {
        // TodoParser.extractHybrid returns [ExtractedTodo] which is what we need for JSON
        let context = CoreDataStack.shared.context
        let todoParser = TodoParser(context: context)
        let todos = try await todoParser.extractHybrid(content)

        guard !todos.isEmpty else {
            return nil
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(todos)
        return String(data: data, encoding: .utf8)
    }

    private func extractEvent(from content: String) async throws -> String? {
        let event = try await EventExtractor.extract(content)

        // Only store if event has minimum required data
        guard event.hasMinimumData else {
            return nil
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(event)
        return String(data: data, encoding: .utf8)
    }

    private func extractMeeting(from content: String, for note: Note) async throws {
        guard let context = note.managedObjectContext else {
            throw DataExtractionError.noManagedObjectContext
        }

        // MeetingParser uses CoreData directly, not JSON
        let meetingParser = MeetingParser(context: context)
        if let meeting = meetingParser.parseMeeting(from: note.content, note: note) {
            meeting.note = note
            note.meeting = meeting
            print("[DataExtractionService] Created Meeting entity for note")
        }
    }

    private func extractRecipe(from content: String) async throws -> String? {
        let recipe = try await RecipeExtractor.extractRecipe(from: content)

        guard !recipe.ingredients.isEmpty || !recipe.steps.isEmpty else {
            return nil
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(recipe)
        return String(data: data, encoding: .utf8)
    }

    private func extractExpense(from content: String) async throws -> String? {
        let expense = try await ExpenseExtractor.extractExpense(from: content)

        guard expense.amount != nil || expense.merchant != nil else {
            return nil
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(expense)
        return String(data: data, encoding: .utf8)
    }

    private func extractShopping(from content: String) async throws -> String? {
        let shopping = try await ShoppingExtractor.extractShoppingList(from: content)

        guard !shopping.items.isEmpty else {
            return nil
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(shopping)
        return String(data: data, encoding: .utf8)
    }

    private func extractEmail(from content: String) async throws -> String? {
        let email = try await EmailExtractor.extractEmail(from: content)

        guard email.to != nil || email.subject != nil || email.body != nil else {
            return nil
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(email)
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - Errors

enum DataExtractionError: LocalizedError {
    case noManagedObjectContext

    var errorDescription: String? {
        switch self {
        case .noManagedObjectContext:
            return "Note has no managed object context for creating related entities"
        }
    }
}
