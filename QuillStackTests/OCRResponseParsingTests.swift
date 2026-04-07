import Testing
import Foundation
@testable import QuillStack

@Suite("OCR Response Parsing")
struct OCRResponseParsingTests {

    /// Validates that various OCR response JSON shapes are parsed correctly.
    private func parseOllamaResponse(_ json: String) -> (
        text: String, title: String?, aiTags: [String],
        contact: ContactExtraction?, event: EventExtraction?, receipt: ReceiptExtraction?
    )? {
        guard let data = json.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let text = parsed["text"] as? String ?? ""
        let tags = parsed["tags"] as? [String] ?? []
        let title = parsed["title"] as? String

        var contact: ContactExtraction?
        if let c = parsed["contact"] as? [String: Any] {
            contact = ContactExtraction(
                name: c["name"] as? String, phone: c["phone"] as? String,
                email: c["email"] as? String, company: c["company"] as? String,
                address: c["address"] as? String, jobTitle: c["jobTitle"] as? String,
                url: c["url"] as? String
            )
        }

        var event: EventExtraction?
        if let e = parsed["event"] as? [String: Any] {
            event = EventExtraction(
                title: e["title"] as? String, date: e["date"] as? String,
                time: e["time"] as? String, endTime: e["endTime"] as? String,
                location: e["location"] as? String, description: e["description"] as? String
            )
        }

        var receipt: ReceiptExtraction?
        if let r = parsed["receipt"] as? [String: Any] {
            let items = (r["items"] as? [[String: Any]])?.map { item in
                ReceiptItem(
                    name: item["name"] as? String,
                    quantity: item["quantity"] as? Int,
                    price: item["price"] as? String
                )
            }
            receipt = ReceiptExtraction(
                vendor: r["vendor"] as? String, total: r["total"] as? String,
                date: r["date"] as? String, currency: r["currency"] as? String,
                items: items
            )
        }

        return (text, title, tags, contact, event, receipt)
    }

    // MARK: - Basic responses

    @Test("Parses minimal text-only response")
    func minimalResponse() throws {
        let result = try #require(parseOllamaResponse("""
        {"text": "Hello World", "tags": ["greeting"], "title": "Note"}
        """))
        #expect(result.text == "Hello World")
        #expect(result.title == "Note")
        #expect(result.aiTags == ["greeting"])
        #expect(result.contact == nil)
    }

    @Test("Handles missing text field gracefully")
    func missingText() throws {
        let result = try #require(parseOllamaResponse("""
        {"tags": ["photo"], "title": "Sunset"}
        """))
        #expect(result.text == "")
        #expect(result.title == "Sunset")
    }

    @Test("Handles missing tags field")
    func missingTags() throws {
        let result = try #require(parseOllamaResponse("""
        {"text": "Some text", "title": "Note"}
        """))
        #expect(result.aiTags.isEmpty)
    }

    // MARK: - Contact parsing from Ollama

    @Test("Parses contact from nested object")
    func contactNested() throws {
        let result = try #require(parseOllamaResponse("""
        {
            "text": "Jane Smith 555-1234",
            "tags": ["business"],
            "title": "Business Card",
            "contact": {
                "name": "Jane Smith",
                "phone": "555-1234",
                "email": "jane@acme.com",
                "company": "Acme Corp",
                "jobTitle": "VP Engineering"
            }
        }
        """))
        let contact = try #require(result.contact)
        #expect(contact.name == "Jane Smith")
        #expect(contact.phone == "555-1234")
        #expect(contact.email == "jane@acme.com")
        #expect(contact.jobTitle == "VP Engineering")
    }

    @Test("Contact with empty object returns extraction with all nils")
    func contactEmptyObject() throws {
        let result = try #require(parseOllamaResponse("""
        {"text": "blurry image", "tags": [], "title": "Unknown", "contact": {}}
        """))
        let contact = try #require(result.contact)
        #expect(contact.name == nil)
        #expect(contact.phone == nil)
    }

    @Test("Contact field as string (not object) is ignored")
    func contactAsString() throws {
        let result = try #require(parseOllamaResponse("""
        {"text": "text", "tags": [], "title": "T", "contact": "Jane Smith"}
        """))
        #expect(result.contact == nil)
    }

    // MARK: - Event parsing from Ollama

    @Test("Parses event with ISO date")
    func eventWithDate() throws {
        let result = try #require(parseOllamaResponse("""
        {
            "text": "Concert March 30",
            "tags": ["music"],
            "title": "Concert Flyer",
            "event": {
                "title": "Spring Concert",
                "date": "2026-03-30",
                "time": "7:00 PM",
                "location": "Main Hall"
            }
        }
        """))
        let event = try #require(result.event)
        #expect(event.title == "Spring Concert")
        #expect(event.date == "2026-03-30")
        #expect(event.time == "7:00 PM")
        #expect(event.location == "Main Hall")
    }

    // MARK: - Receipt parsing from Ollama

    @Test("Parses receipt with items array")
    func receiptWithItems() throws {
        let result = try #require(parseOllamaResponse("""
        {
            "text": "Total $42.50",
            "tags": ["shopping"],
            "title": "Store Receipt",
            "receipt": {
                "vendor": "Target",
                "total": "42.50",
                "currency": "USD",
                "date": "2026-03-24",
                "items": [
                    {"name": "Shirt", "quantity": 1, "price": "29.99"},
                    {"name": "Socks", "quantity": 3, "price": "4.17"}
                ]
            }
        }
        """))
        let receipt = try #require(result.receipt)
        #expect(receipt.vendor == "Target")
        #expect(receipt.total == "42.50")
        #expect(receipt.items?.count == 2)
        #expect(receipt.items?[1].quantity == 3)
    }

    @Test("Receipt with no items array")
    func receiptNoItems() throws {
        let result = try #require(parseOllamaResponse("""
        {"text": "t", "tags": [], "title": "R", "receipt": {"vendor": "Cafe", "total": "5.00"}}
        """))
        let receipt = try #require(result.receipt)
        #expect(receipt.vendor == "Cafe")
        #expect(receipt.items == nil)
    }

    // MARK: - Malformed / adversarial responses

    @Test("Invalid JSON returns nil")
    func invalidJson() {
        let result = parseOllamaResponse("not json at all")
        #expect(result == nil)
    }

    @Test("Empty JSON object returns empty text")
    func emptyObject() throws {
        let result = try #require(parseOllamaResponse("{}"))
        #expect(result.text == "")
        #expect(result.title == nil)
        #expect(result.aiTags.isEmpty)
    }

    @Test("Numeric values in string fields are ignored")
    func numericTitle() throws {
        let result = try #require(parseOllamaResponse("""
        {"text": "hello", "tags": [], "title": 12345}
        """))
        // title is cast as? String, so numeric value becomes nil
        #expect(result.title == nil)
        #expect(result.text == "hello")
    }

    @Test("Nested arrays in tags are handled")
    func nestedTagArrays() throws {
        // LLM might return nested arrays
        let result = try #require(parseOllamaResponse("""
        {"text": "t", "tags": [["nested"]], "title": "T"}
        """))
        // tags as? [String] will fail, falling back to []
        #expect(result.aiTags.isEmpty)
    }
}
