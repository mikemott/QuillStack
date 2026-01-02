//
//  ActionTriggerParser.swift
//  QuillStack
//
//  Phase A.2 - Trigger Parser
//  Parses inline action triggers from OCR text and extracts NoteAction objects.
//

import Foundation

/// Parses inline action triggers from note content.
///
/// Supports three tiers of trigger syntax:
/// - **Tier 1 (Quick):** `#summarize#`, `#analyze#`, `#research#`, etc.
/// - **Tier 2 (Parameterized):** `#ask: question here#`, `#email: recipient#`
/// - **Tier 3 (Extended):** `@Claude: prompt here` or `@AI: prompt here`
///
/// Example usage:
/// ```swift
/// let parser = ActionTriggerParser()
/// let result = parser.parse("Meeting notes\n#summarize#\n---\nAction items")
/// // result.actions contains one .summarize action
/// // result.cleanedContent = "Meeting notes\nAction items"
/// // result.hasDivider = true
/// ```
@MainActor
class ActionTriggerParser: ActionTriggerParserProtocol {

    // MARK: - Regex Patterns

    /// Quick actions: #summarize#, #analyze#, etc. (case-insensitive)
    private let quickActionPattern = #"#(summarize|analyze|research|proofread|expand|translate)#"#

    /// Parameterized actions: #ask: question#, #email: recipient#, etc.
    private let parameterizedPattern = #"#(ask|email|remind|calendar):\s*(.+?)#"#

    /// Extended prompts: @Claude: or @AI: followed by rest of line
    private let extendedPromptPattern = #"^@(Claude|AI):\s*(.+)$"#

    /// Content divider: three or more dashes on a line
    private let dividerPattern = #"^-{3,}$"#

    // MARK: - ActionTriggerParserProtocol

    func parse(_ text: String) -> TriggerParseResult {
        guard !text.isEmpty else {
            return .empty
        }

        var actions: [NoteAction] = []
        var cleanedLines: [String] = []
        var hasDivider = false
        var foundDividerAt: Int? = nil

        let lines = text.components(separatedBy: .newlines)

        for (index, line) in lines.enumerated() {
            // Check for divider
            if matchesDivider(line) {
                hasDivider = true
                foundDividerAt = index
                continue // Don't include divider in cleaned content
            }

            var processedLine = line

            // Extract quick actions
            processedLine = extractQuickActions(from: processedLine, into: &actions)

            // Extract parameterized actions
            processedLine = extractParameterizedActions(from: processedLine, into: &actions)

            // Extract extended prompts (consume entire line)
            if let extendedAction = extractExtendedPrompt(from: line) {
                actions.append(extendedAction)
                continue // Don't add this line to cleaned content
            }

            // Add non-empty processed lines
            let trimmed = processedLine.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                cleanedLines.append(processedLine)
            }
        }

        // If divider found, actions operate on content before it
        let finalActions: [NoteAction]
        if hasDivider {
            finalActions = actions.map { action in
                NoteAction(
                    type: action.type,
                    prompt: action.prompt,
                    parameters: action.parameters,
                    scope: .beforeDivider
                )
            }
        } else {
            finalActions = actions
        }

        return TriggerParseResult(
            actions: finalActions,
            cleanedContent: cleanedLines.joined(separator: "\n"),
            hasDivider: hasDivider
        )
    }

    // MARK: - Private Helpers

    private func matchesDivider(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.range(of: dividerPattern, options: .regularExpression) != nil
    }

    /// Extracts quick action triggers like #summarize#, #analyze#
    private func extractQuickActions(from line: String, into actions: inout [NoteAction]) -> String {
        var result = line

        guard let regex = try? NSRegularExpression(
            pattern: quickActionPattern,
            options: .caseInsensitive
        ) else { return result }

        let range = NSRange(line.startIndex..., in: line)
        let matches = regex.matches(in: line, options: [], range: range)

        // Process matches in reverse order to preserve indices
        for match in matches.reversed() {
            guard let actionRange = Range(match.range(at: 1), in: line) else { continue }
            let actionName = String(line[actionRange]).lowercased()

            if let actionType = quickActionType(from: actionName) {
                actions.append(NoteAction(type: actionType))
            }

            // Remove the trigger from the line
            if let fullRange = Range(match.range, in: result) {
                result.replaceSubrange(fullRange, with: "")
            }
        }

        return result
    }

    /// Extracts parameterized actions like #ask: question#, #email: recipient#
    private func extractParameterizedActions(from line: String, into actions: inout [NoteAction]) -> String {
        var result = line

        guard let regex = try? NSRegularExpression(
            pattern: parameterizedPattern,
            options: .caseInsensitive
        ) else { return result }

        let range = NSRange(line.startIndex..., in: line)
        let matches = regex.matches(in: line, options: [], range: range)

        // Process matches in reverse order to preserve indices
        for match in matches.reversed() {
            guard let actionRange = Range(match.range(at: 1), in: line),
                  let paramRange = Range(match.range(at: 2), in: line) else { continue }

            let actionName = String(line[actionRange]).lowercased()
            let paramValue = String(line[paramRange]).trimmingCharacters(in: .whitespaces)

            if let action = createParameterizedAction(type: actionName, parameter: paramValue) {
                actions.append(action)
            }

            // Remove the trigger from the line
            if let fullRange = Range(match.range, in: result) {
                result.replaceSubrange(fullRange, with: "")
            }
        }

        return result
    }

    /// Extracts extended prompts like @Claude: or @AI:
    private func extractExtendedPrompt(from line: String) -> NoteAction? {
        guard let regex = try? NSRegularExpression(
            pattern: extendedPromptPattern,
            options: .caseInsensitive
        ) else { return nil }

        let range = NSRange(line.startIndex..., in: line)
        guard let match = regex.firstMatch(in: line, options: [], range: range),
              let promptRange = Range(match.range(at: 2), in: line) else {
            return nil
        }

        let prompt = String(line[promptRange]).trimmingCharacters(in: .whitespaces)
        guard !prompt.isEmpty else { return nil }

        return NoteAction(type: .ask, prompt: prompt)
    }

    /// Maps quick action trigger names to ActionType
    private func quickActionType(from name: String) -> ActionType? {
        switch name {
        case "summarize": return .summarize
        case "analyze": return .analyze
        case "research": return .research
        case "proofread": return .proofread
        case "expand": return .expand
        case "translate": return .translate
        default: return nil
        }
    }

    /// Creates a parameterized action from trigger name and parameter value
    private func createParameterizedAction(type: String, parameter: String) -> NoteAction? {
        switch type {
        case "ask":
            return NoteAction(type: .ask, prompt: parameter)

        case "email":
            return NoteAction(
                type: .email,
                parameters: ["recipient": parameter]
            )

        case "remind":
            return NoteAction(
                type: .setReminder,
                parameters: ["when": parameter]
            )

        case "calendar":
            return NoteAction(
                type: .addToCalendar,
                parameters: ["details": parameter]
            )

        default:
            return nil
        }
    }
}
