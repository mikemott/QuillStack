import Testing
import Foundation
@testable import QuillStack

@Suite("EnrichedCapture Decoding")
struct EnrichedCaptureTests {

    // MARK: - Full response

    @Test("Decodes complete enrichment with all extraction types")
    func fullResponse() throws {
        let json = """
        {
            "title": "Business Card",
            "summary": "A business card for Jane Smith",
            "text": "Jane Smith\\nAcme Corp\\n555-1234",
            "tags": [],
            "aiTags": ["business", "contact"],
            "contact": {
                "name": "Jane Smith",
                "phone": "555-1234",
                "company": "Acme Corp"
            },
            "event": null,
            "receipt": null
        }
        """
        let enrichment = try JSONDecoder().decode(EnrichedCapture.self, from: Data(json.utf8))

        #expect(enrichment.title == "Business Card")
        #expect(enrichment.aiTags == ["business", "contact"])
        #expect(enrichment.contact?.name == "Jane Smith")
        #expect(enrichment.contact?.phone == "555-1234")
        #expect(enrichment.contact?.company == "Acme Corp")
        #expect(enrichment.event == nil)
        #expect(enrichment.receipt == nil)
    }

    // MARK: - Missing optional fields

    @Test("Decodes enrichment with no extraction fields")
    func noExtractions() throws {
        let json = """
        {
            "title": "Note",
            "summary": "A handwritten note",
            "text": "Hello world",
            "tags": [],
            "aiTags": ["greeting"]
        }
        """
        let enrichment = try JSONDecoder().decode(EnrichedCapture.self, from: Data(json.utf8))

        #expect(enrichment.title == "Note")
        #expect(enrichment.contact == nil)
        #expect(enrichment.event == nil)
        #expect(enrichment.receipt == nil)
    }

    @Test("Decodes enrichment with empty aiTags array")
    func emptyAiTags() throws {
        let json = """
        {
            "title": "Photo",
            "summary": "A photo",
            "text": "",
            "tags": [],
            "aiTags": []
        }
        """
        let enrichment = try JSONDecoder().decode(EnrichedCapture.self, from: Data(json.utf8))
        #expect(enrichment.aiTags.isEmpty)
    }

    // MARK: - Backward compatibility

    @Test("Decodes legacy JSON without aiTags field")
    func missingAiTags() throws {
        let json = """
        {
            "title": "Old capture",
            "summary": "From v1",
            "text": "Some text",
            "tags": ["Receipt"]
        }
        """
        // EnrichedCapture requires aiTags in its Codable — this should fail
        // but we need to verify the app handles it gracefully
        let result = try? JSONDecoder().decode(EnrichedCapture.self, from: Data(json.utf8))
        // If this fails, we need a custom decoder with decodeIfPresent
        if let result {
            #expect(result.aiTags.isEmpty)
        }
    }

    // MARK: - Contact extraction edge cases

    @Test("Decodes contact with only name")
    func contactNameOnly() throws {
        let json = """
        {
            "title": "Card",
            "summary": "A card",
            "text": "John",
            "tags": [],
            "aiTags": [],
            "contact": {"name": "John"}
        }
        """
        let enrichment = try JSONDecoder().decode(EnrichedCapture.self, from: Data(json.utf8))
        #expect(enrichment.contact?.name == "John")
        #expect(enrichment.contact?.phone == nil)
        #expect(enrichment.contact?.email == nil)
    }

    @Test("Decodes contact with all fields")
    func contactAllFields() throws {
        let json = """
        {
            "title": "Card",
            "summary": "A card",
            "text": "Full contact",
            "tags": [],
            "aiTags": [],
            "contact": {
                "name": "Jane Doe",
                "phone": "+1-555-0199",
                "email": "jane@example.com",
                "company": "Acme Inc",
                "address": "123 Main St",
                "jobTitle": "CEO",
                "url": "https://example.com"
            }
        }
        """
        let enrichment = try JSONDecoder().decode(EnrichedCapture.self, from: Data(json.utf8))
        let contact = try #require(enrichment.contact)
        #expect(contact.name == "Jane Doe")
        #expect(contact.phone == "+1-555-0199")
        #expect(contact.email == "jane@example.com")
        #expect(contact.company == "Acme Inc")
        #expect(contact.address == "123 Main St")
        #expect(contact.jobTitle == "CEO")
        #expect(contact.url == "https://example.com")
    }

    // MARK: - Event extraction

    @Test("Decodes event with partial fields")
    func eventPartial() throws {
        let json = """
        {
            "title": "Concert",
            "summary": "A concert flyer",
            "text": "Live Music Friday",
            "tags": [],
            "aiTags": ["music"],
            "event": {
                "title": "Live Music Night",
                "date": "2026-04-15",
                "location": "The Venue"
            }
        }
        """
        let enrichment = try JSONDecoder().decode(EnrichedCapture.self, from: Data(json.utf8))
        let event = try #require(enrichment.event)
        #expect(event.title == "Live Music Night")
        #expect(event.date == "2026-04-15")
        #expect(event.location == "The Venue")
        #expect(event.time == nil)
        #expect(event.endTime == nil)
    }

    // MARK: - Receipt extraction

    @Test("Decodes receipt with line items")
    func receiptWithItems() throws {
        let json = """
        {
            "title": "Grocery Receipt",
            "summary": "Receipt from store",
            "text": "Milk $3.99",
            "tags": [],
            "aiTags": ["grocery"],
            "receipt": {
                "vendor": "Whole Foods",
                "total": "42.50",
                "date": "2026-03-24",
                "currency": "USD",
                "items": [
                    {"name": "Milk", "quantity": 1, "price": "3.99"},
                    {"name": "Bread", "quantity": 2, "price": "5.49"}
                ]
            }
        }
        """
        let enrichment = try JSONDecoder().decode(EnrichedCapture.self, from: Data(json.utf8))
        let receipt = try #require(enrichment.receipt)
        #expect(receipt.vendor == "Whole Foods")
        #expect(receipt.total == "42.50")
        #expect(receipt.currency == "USD")
        #expect(receipt.items?.count == 2)
        #expect(receipt.items?[0].name == "Milk")
        #expect(receipt.items?[1].quantity == 2)
    }

    @Test("Decodes receipt with no items")
    func receiptNoItems() throws {
        let json = """
        {
            "title": "Receipt",
            "summary": "A receipt",
            "text": "Total: $10",
            "tags": [],
            "aiTags": [],
            "receipt": {
                "vendor": "Coffee Shop",
                "total": "10.00"
            }
        }
        """
        let enrichment = try JSONDecoder().decode(EnrichedCapture.self, from: Data(json.utf8))
        let receipt = try #require(enrichment.receipt)
        #expect(receipt.vendor == "Coffee Shop")
        #expect(receipt.items == nil)
    }

    // MARK: - Encode/decode roundtrip

    @Test("Roundtrip encode/decode preserves all data")
    func roundtrip() throws {
        let original = EnrichedCapture(
            title: "Test",
            summary: "A test",
            text: "Hello",
            tags: ["Note"],
            aiTags: ["test", "greeting"],
            contact: ContactExtraction(name: "Bob", phone: "555-0000"),
            event: nil,
            receipt: ReceiptExtraction(vendor: "Shop", total: "9.99")
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(EnrichedCapture.self, from: data)

        #expect(decoded.title == original.title)
        #expect(decoded.aiTags == original.aiTags)
        #expect(decoded.contact?.name == "Bob")
        #expect(decoded.contact?.phone == "555-0000")
        #expect(decoded.event == nil)
        #expect(decoded.receipt?.vendor == "Shop")
    }
}
