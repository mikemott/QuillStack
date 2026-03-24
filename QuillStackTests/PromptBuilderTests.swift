import Testing
import Foundation
@testable import QuillStack

@Suite("OCR Prompt Builder")
struct PromptBuilderTests {

    private func buildPrompt(tags: Set<String>) async -> String {
        let service = RemoteOCRService()
        return await service.buildPrompt(tagNames: tags)
    }

    // MARK: - Base prompt

    @Test("Base prompt always includes text, tags, and title fields")
    func basePrompt() async {
        let prompt = await buildPrompt(tags: [])
        #expect(prompt.contains("\"text\""))
        #expect(prompt.contains("\"tags\""))
        #expect(prompt.contains("\"title\""))
    }

    @Test("No actionable tags produces no extraction instructions")
    func noActionableTags() async {
        let prompt = await buildPrompt(tags: ["Note", "Work"])
        #expect(!prompt.contains("\"contact\""))
        #expect(!prompt.contains("\"event\""))
        #expect(!prompt.contains("\"receipt\""))
    }

    @Test("Empty tag set produces base prompt only")
    func emptyTags() async {
        let prompt = await buildPrompt(tags: [])
        #expect(!prompt.contains("\"contact\""))
        #expect(!prompt.contains("\"event\""))
        #expect(!prompt.contains("\"receipt\""))
        #expect(prompt.contains("Respond ONLY with the JSON object"))
    }

    // MARK: - Contact extraction

    @Test("Contact tag adds contact extraction instructions")
    func contactTag() async {
        let prompt = await buildPrompt(tags: ["Contact"])
        #expect(prompt.contains("\"contact\""))
        #expect(prompt.contains("name"))
        #expect(prompt.contains("phone"))
        #expect(prompt.contains("email"))
        #expect(prompt.contains("company"))
    }

    // MARK: - Event extraction

    @Test("Event tag adds event extraction instructions")
    func eventTag() async {
        let prompt = await buildPrompt(tags: ["Event"])
        #expect(prompt.contains("\"event\""))
        #expect(prompt.contains("ISO 8601"))
        #expect(prompt.contains("location"))
    }

    // MARK: - Receipt extraction

    @Test("Receipt tag adds receipt extraction instructions")
    func receiptTag() async {
        let prompt = await buildPrompt(tags: ["Receipt"])
        #expect(prompt.contains("\"receipt\""))
        #expect(prompt.contains("vendor"))
        #expect(prompt.contains("total"))
        #expect(prompt.contains("items"))
    }

    // MARK: - Multiple tags

    @Test("Multiple actionable tags produce all extraction blocks")
    func allThreeTags() async {
        let prompt = await buildPrompt(tags: ["Contact", "Event", "Receipt"])
        #expect(prompt.contains("\"contact\""))
        #expect(prompt.contains("\"event\""))
        #expect(prompt.contains("\"receipt\""))
    }

    @Test("Field numbering increments correctly with multiple tags")
    func fieldNumbering() async {
        let prompt = await buildPrompt(tags: ["Contact", "Event", "Receipt"])
        // Base fields are 1-3, so extraction fields should start at 4
        #expect(prompt.contains("4."))
        #expect(prompt.contains("5."))
        #expect(prompt.contains("6."))
    }

    // MARK: - Case sensitivity

    @Test("Tag matching is case-sensitive")
    func caseSensitive() async {
        let prompt = await buildPrompt(tags: ["contact", "EVENT", "receipt"])
        // Should NOT match — tags are case-sensitive
        #expect(!prompt.contains("\"contact\""))
        #expect(!prompt.contains("\"event\""))
        #expect(!prompt.contains("\"receipt\""))
    }

    // MARK: - Prompt structure

    @Test("Prompt starts with no_think directive")
    func noThinkDirective() async {
        let prompt = await buildPrompt(tags: [])
        #expect(prompt.contains("/no_think"))
    }

    @Test("Prompt ends with JSON-only instruction")
    func endsWithJsonInstruction() async {
        let prompt = await buildPrompt(tags: ["Contact"])
        #expect(prompt.hasSuffix("Respond ONLY with the JSON object."))
    }
}
