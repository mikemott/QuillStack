import Testing
import Foundation
@testable import QuillStack

@Suite("OCR Schema Builder")
struct SchemaBuilderTests {

    private func buildSchema(tags: Set<String>) -> [String: Any] {
        let service = DatalabOCRService()
        return service.buildSchema(tagNames: tags)
    }

    private func properties(from schema: [String: Any]) -> [String: Any] {
        schema["properties"] as? [String: Any] ?? [:]
    }

    private func required(from schema: [String: Any]) -> [String] {
        schema["required"] as? [String] ?? []
    }

    // MARK: - Base schema

    @Test("No actionable tags produces empty schema")
    func noActionableTags() {
        let schema = buildSchema(tags: ["Project", "Work"])
        let props = properties(from: schema)
        #expect(props.isEmpty)
    }

    @Test("Empty tag set produces empty schema")
    func emptyTags() {
        let schema = buildSchema(tags: [])
        let props = properties(from: schema)
        #expect(props.isEmpty)
    }

    // MARK: - Contact extraction

    @Test("Contact tag adds contact property with subfields")
    func contactTag() {
        let schema = buildSchema(tags: ["Contact"])
        let props = properties(from: schema)
        let contact = props["contact"] as? [String: Any]
        #expect(contact != nil)
        let contactProps = contact?["properties"] as? [String: Any]
        #expect(contactProps?["name"] != nil)
        #expect(contactProps?["phone"] != nil)
        #expect(contactProps?["email"] != nil)
        #expect(contactProps?["company"] != nil)
    }

    @Test("Contact tag adds contact to required")
    func contactRequired() {
        let schema = buildSchema(tags: ["Contact"])
        #expect(required(from: schema).contains("contact"))
    }

    // MARK: - Event extraction

    @Test("Event tag adds event property")
    func eventTag() {
        let schema = buildSchema(tags: ["Event"])
        let props = properties(from: schema)
        let event = props["event"] as? [String: Any]
        #expect(event != nil)
        let eventProps = event?["properties"] as? [String: Any]
        #expect(eventProps?["title"] != nil)
        #expect(eventProps?["date"] != nil)
        #expect(eventProps?["location"] != nil)
    }

    // MARK: - Receipt extraction

    @Test("Receipt tag adds receipt property with items array")
    func receiptTag() {
        let schema = buildSchema(tags: ["Receipt"])
        let props = properties(from: schema)
        let receipt = props["receipt"] as? [String: Any]
        #expect(receipt != nil)
        let receiptProps = receipt?["properties"] as? [String: Any]
        #expect(receiptProps?["vendor"] != nil)
        #expect(receiptProps?["total"] != nil)
        #expect(receiptProps?["items"] != nil)
    }

    // MARK: - Todo extraction

    @Test("To-Do tag adds todo property")
    func todoTag() {
        let schema = buildSchema(tags: ["To-Do"])
        let props = properties(from: schema)
        #expect(props["todo"] != nil)
    }

    // MARK: - Multiple tags

    @Test("Multiple actionable tags produce all extraction properties")
    func allTags() {
        let schema = buildSchema(tags: ["Contact", "Event", "Receipt", "To-Do"])
        let props = properties(from: schema)
        #expect(props["contact"] != nil)
        #expect(props["event"] != nil)
        #expect(props["receipt"] != nil)
        #expect(props["todo"] != nil)
        #expect(props.count == 4)
    }

    @Test("All actionable tags are in required")
    func allRequired() {
        let schema = buildSchema(tags: ["Contact", "Event", "Receipt", "To-Do"])
        let req = required(from: schema)
        #expect(req.count == 4)
    }

    // MARK: - Case sensitivity

    @Test("Tag matching is case-sensitive")
    func caseSensitive() {
        let schema = buildSchema(tags: ["contact", "EVENT", "receipt"])
        let props = properties(from: schema)
        #expect(props["contact"] == nil)
        #expect(props["event"] == nil)
        #expect(props["receipt"] == nil)
    }

    // MARK: - Schema structure

    @Test("Schema has type object at root")
    func rootType() {
        let schema = buildSchema(tags: [])
        #expect(schema["type"] as? String == "object")
    }
}
