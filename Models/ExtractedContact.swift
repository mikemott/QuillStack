//
//  ExtractedContact.swift
//  QuillStack
//
//  Phase 2.1: LLM-powered contact extraction
//  Structured contact data extracted by LLM from business cards
//

import Foundation

/// Contact information extracted by LLM from business card text
struct ExtractedContact: Codable, Sendable {
    var name: String?
    var firstName: String?
    var lastName: String?
    var phone: String?
    var email: String?
    var company: String?
    var title: String?
    var address: String?
    var website: String?
    var notes: String?

    /// Convert to ParsedContact for compatibility with existing code
    func toParsedContact() -> ParsedContact {
        var contact = ParsedContact()

        // Handle name variations
        if let firstName = firstName {
            contact.firstName = firstName
        } else if let name = name {
            // Split name if provided as full name
            let parts = name.split(separator: " ")
            if parts.count >= 2 {
                contact.firstName = String(parts.first!)
                contact.lastName = parts.dropFirst().joined(separator: " ")
            } else if parts.count == 1 {
                contact.firstName = String(parts.first!)
            }
        }

        if let lastName = lastName {
            contact.lastName = lastName
        }

        contact.jobTitle = title ?? ""
        contact.company = company ?? ""
        contact.phone = phone ?? ""
        contact.email = email ?? ""
        contact.website = website ?? ""
        contact.notes = notes ?? ""

        // Parse address if provided as full string
        if let address = address {
            parseAddress(address, into: &contact)
        }

        return contact
    }

    /// Simple address parsing to split into components
    private func parseAddress(_ fullAddress: String, into contact: inout ParsedContact) {
        // Try to parse "Street, City, State ZIP" format
        let lines = fullAddress.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        if lines.count >= 3 {
            // Format: Street, City, State ZIP
            contact.streetAddress = lines[0]
            contact.city = lines[1]

            // Parse "State ZIP" from last component
            let stateZip = lines[2].split(separator: " ")
            if stateZip.count >= 2 {
                contact.state = String(stateZip.first!)
                contact.zipCode = stateZip.dropFirst().joined(separator: " ")
            } else {
                contact.state = lines[2]
            }
        } else if lines.count == 2 {
            // Format: Street, City State ZIP
            contact.streetAddress = lines[0]

            let cityStateZip = lines[1].split(separator: " ")
            if cityStateZip.count >= 3 {
                contact.city = String(cityStateZip.first!)
                contact.state = String(cityStateZip[1])
                contact.zipCode = cityStateZip.dropFirst(2).joined(separator: " ")
            } else {
                contact.city = lines[1]
            }
        } else {
            // Single line - just put in street address
            contact.streetAddress = fullAddress
        }
    }
}
