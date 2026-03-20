import Foundation
import FoundationModels

@Generable(description: "Structured analysis of a captured image")
struct Enrichment: Codable, Sendable {
    @Guide(description: "Short descriptive title, under 10 words")
    var title: String

    @Guide(description: "1-2 sentence summary of what this image shows")
    var summary: String

    @Guide(description: "All visible text transcribed from the image")
    var text: String

    @Guide(description: "1-2 tags from the allowed list that best categorize this image")
    var tags: [String]

    @Guide(description: "Actionable items extracted from the image, if any")
    var actions: [Action]

    @Generable(description: "An actionable item found in the image")
    struct Action: Codable, Sendable {
        @Guide(description: "Action type: createContact, createEvent, openURL, callPhone, or sendEmail")
        var type: String

        @Guide(description: "Person or business name, if found")
        var name: String?

        @Guide(description: "Phone number, if found")
        var phone: String?

        @Guide(description: "Email address, if found")
        var email: String?

        @Guide(description: "Company or organization name, if found")
        var company: String?

        @Guide(description: "Event title, if this is an event")
        var eventTitle: String?

        @Guide(description: "Date in ISO 8601 format, if found")
        var date: String?

        @Guide(description: "Time, if found")
        var time: String?

        @Guide(description: "Location or address, if found")
        var location: String?

        @Guide(description: "URL, if found")
        var url: String?
    }
}
