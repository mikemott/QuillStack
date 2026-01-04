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
            // Log error type without exposing system details
            let errorType = String(describing: type(of: error))
            Self.logger.error("Contacts access request failed: \(errorType)")
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
            // Log success without PII (only log that a contact was created, not the name)
            Self.logger.info("Successfully created contact (hasName: \(!contact.displayName.isEmpty), hasEmail: \(!contact.email.isEmpty), hasPhone: \(!contact.phone.isEmpty))")
            
            return cnContact.identifier
        } catch {
            // Log error without exposing PII or system details
            let errorType = String(describing: type(of: error))
            Self.logger.error("Failed to save contact: \(errorType) (code: \((error as NSError).code))")
            // Sanitize error message for user-facing error
            let sanitizedMessage = sanitizeErrorMessage(error)
            throw ContactsError.createFailed(sanitizedMessage)
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
        let predicate = CNContact.predicateForContacts(matchingName: name)

        do {
            let contacts = try contactStore.unifiedContacts(matching: predicate, keysToFetch: keys)

            for contact in contacts {
                let fullName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
                if fullName.lowercased() == name.lowercased() {
                    // If email provided, check for match
                    if let email = email, !email.isEmpty {
                        let contactEmails = contact.emailAddresses.map { $0.value as String }
                        if contactEmails.contains(where: { $0.lowercased() == email.lowercased() }) {
                            return true
                        }
                    } else {
                        return true
                    }
                }
            }
            return false
        } catch {
            // Log error type without exposing system details
            let errorType = String(describing: type(of: error))
            Self.logger.error("Failed to check contact existence: \(errorType)")
            return false
        }
    }
    
    // MARK: - Error Sanitization
    
    /// Sanitize error messages to remove PII and system details
    private func sanitizeErrorMessage(_ error: Error) -> String {
        // Remove common system error prefixes and PII patterns
        var message = error.localizedDescription
        
        // Remove file paths
        message = message.replacingOccurrences(of: #"/[^\s]+"#, with: "[path]", options: .regularExpression)
        
        // Remove email addresses
        message = message.replacingOccurrences(of: #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#, with: "[email]", options: .regularExpression)
        
        // Remove phone numbers
        message = message.replacingOccurrences(of: #"\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}"#, with: "[phone]", options: .regularExpression)
        
        // Genericize common error messages
        if message.lowercased().contains("domain") && message.lowercased().contains("code") {
            return "A system error occurred while saving the contact."
        }
        
        return message.isEmpty ? "An unknown error occurred." : message
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
            // Return user-friendly message (already sanitized)
            return "Failed to create contact. \(message)"
        case .invalidData:
            return "Invalid contact data provided."
        }
    }
    
    /// User-facing error message (sanitized, no system details)
    var userFacingMessage: String {
        switch self {
        case .accessDenied:
            return "Contacts access is required. Please enable it in Settings."
        case .createFailed:
            return "Unable to save contact. Please try again."
        case .invalidData:
            return "The contact information is incomplete or invalid."
        }
    }
}

