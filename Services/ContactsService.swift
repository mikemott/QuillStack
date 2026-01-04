//
//  ContactsService.swift
//  QuillStack
//
//  Phase 3.1 - Contacts Service
//  Service wrapper for CNContactStore to simplify contact creation.
//

import Foundation
import Contacts
import os.log

/// Service for contacts integration via Contacts framework.
/// Provides a simplified interface for creating and saving contacts.
final class ContactsService: @unchecked Sendable {
    static let shared = ContactsService()
    
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "QuillStack", category: "Contacts")
    
    private let contactStore = CNContactStore()
    
    private init() {}
    
    // MARK: - Authorization
    
    enum AuthorizationStatus {
        case authorized
        case denied
        case notDetermined
        case restricted
    }
    
    var authorizationStatus: AuthorizationStatus {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        switch status {
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        @unknown default:
            return .denied
        }
    }
    
    /// Request access to contacts
    /// - Returns: True if access was granted
    func requestAccess() async -> Bool {
        do {
            return try await contactStore.requestAccess(for: .contacts)
        } catch {
            Self.logger.error("Contacts access request failed: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Create Contact
    
    /// Create and save a contact from ParsedContact
    /// - Parameter contact: The parsed contact data
    /// - Returns: The created contact's identifier, or nil on failure
    /// - Throws: ContactsError on failure
    func createContact(from contact: ParsedContact) throws -> String {
        guard authorizationStatus == .authorized else {
            throw ContactsError.accessDenied
        }
        
        let cnContact = CNMutableContact()
        
        // Name
        cnContact.givenName = contact.firstName
        cnContact.familyName = contact.lastName
        
        // Organization
        if !contact.company.isEmpty {
            cnContact.organizationName = contact.company
        }
        if !contact.jobTitle.isEmpty {
            cnContact.jobTitle = contact.jobTitle
        }
        
        // Phone
        if !contact.phone.isEmpty {
            cnContact.phoneNumbers = [CNLabeledValue(
                label: CNLabelPhoneNumberMain,
                value: CNPhoneNumber(stringValue: contact.phone)
            )]
        }
        
        // Email
        if !contact.email.isEmpty {
            cnContact.emailAddresses = [CNLabeledValue(
                label: CNLabelWork,
                value: contact.email as NSString
            )]
        }
        
        // Website
        if !contact.website.isEmpty {
            var urlString = contact.website
            if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
                urlString = "https://" + urlString
            }
            cnContact.urlAddresses = [CNLabeledValue(
                label: CNLabelWork,
                value: urlString as NSString
            )]
        }
        
        // Postal Address
        if contact.hasAddress {
            let address = CNMutablePostalAddress()
            address.street = contact.streetAddress
            address.city = contact.city
            address.state = contact.state
            address.postalCode = contact.zipCode
            address.country = "USA" // Default to USA, could be made configurable
            
            cnContact.postalAddresses = [CNLabeledValue(
                label: CNLabelWork,
                value: address
            )]
        }
        
        // Notes
        if !contact.notes.isEmpty {
            cnContact.note = contact.notes
        }
        
        // Save contact
        let saveRequest = CNSaveRequest()
        saveRequest.add(cnContact, toContainerWithIdentifier: nil)
        
        do {
            try contactStore.execute(saveRequest)
            Self.logger.info("Successfully created contact: \(contact.displayName)")
            
            // Return a stable identifier (CNContact doesn't provide one until saved)
            // We'll use the display name as a reference
            return cnContact.identifier
        } catch {
            Self.logger.error("Failed to save contact: \(error.localizedDescription)")
            throw ContactsError.createFailed(error.localizedDescription)
        }
    }
    
    
    // MARK: - Fetch Contacts
    
    /// Check if a contact exists (by name and email)
    /// - Parameters:
    ///   - name: Contact name to search for
    ///   - email: Optional email to match
    /// - Returns: True if a matching contact exists
    func contactExists(name: String, email: String? = nil) -> Bool {
        guard authorizationStatus == .authorized else {
            return false
        }
        
        let keys: [CNKeyDescriptor] = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactEmailAddressesKey] as [CNKeyDescriptor]
        let request = CNContactFetchRequest(keysToFetch: keys)
        
        // Search by name
        request.predicate = CNContact.predicateForContacts(matchingName: name)
        
        do {
            var found = false
            try contactStore.enumerateContacts(with: request) { contact, _ in
                let fullName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
                if fullName.lowercased() == name.lowercased() {
                    // If email provided, check for match
                    if let email = email, !email.isEmpty {
                        let contactEmails = contact.emailAddresses.map { $0.value as String }
                        if contactEmails.contains(where: { $0.lowercased() == email.lowercased() }) {
                            found = true
                            return false // Stop enumeration
                        }
                    } else {
                        found = true
                        return false // Stop enumeration
                    }
                }
                return true // Continue enumeration
            }
            return found
        } catch {
            Self.logger.error("Failed to check contact existence: \(error.localizedDescription)")
            return false
        }
    }
}

// MARK: - Errors

enum ContactsError: LocalizedError {
    case accessDenied
    case createFailed(String)
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Access to Contacts was denied. Please enable access in Settings."
        case .createFailed(let message):
            return "Failed to create contact: \(message)"
        case .invalidData:
            return "Invalid contact data provided."
        }
    }
}

