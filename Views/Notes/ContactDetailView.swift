//
//  ContactDetailView.swift
//  QuillStack
//
//  Created on 2025-12-31.
//

import SwiftUI
import Contacts

struct ContactDetailView: View {
    @ObservedObject var note: Note
    @State private var parsedContact: ParsedContact = ParsedContact()
    @State private var showingSaveSheet = false
    @State private var saveSuccess = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.creamLight.ignoresSafeArea()

            VStack(spacing: 0) {
                DetailHeader(
                    title: parsedContact.displayName.isEmpty ? "Contact" : parsedContact.displayName,
                    date: note.createdAt,
                    noteType: "contact",
                    onBack: { dismiss() }
                )

                ScrollView {
                    VStack(spacing: 16) {
                        // Contact card preview
                        contactCard

                        // Editable fields
                        editableFields
                    }
                    .padding(20)
                }
                .background(
                    LinearGradient(
                        colors: [Color.paperBeige.opacity(0.98), Color.paperTan.opacity(0.98)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

                bottomBar
            }
        }
        .navigationBarHidden(true)
        .onAppear { parseContent() }
        .alert("Contact Saved", isPresented: $saveSuccess) {
            Button("OK") { }
        } message: {
            Text("Contact saved to your Contacts app")
        }
        .alert("Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Contact Card

    private var contactCard: some View {
        VStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.badgeContact, Color.badgeContact.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Text(parsedContact.initials)
                    .font(.system(size: 32, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
            }

            // Name
            Text(parsedContact.displayName.isEmpty ? "New Contact" : parsedContact.displayName)
                .font(.serifHeadline(22, weight: .semibold))
                .foregroundColor(.textDark)

            // Company
            if !parsedContact.company.isEmpty {
                Text(parsedContact.company)
                    .font(.serifBody(15, weight: .regular))
                    .foregroundColor(.textMedium)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.white.opacity(0.6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.badgeContact.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Editable Fields

    private var editableFields: some View {
        VStack(spacing: 12) {
            ContactFieldRow(icon: "person", label: "First Name", text: $parsedContact.firstName)
            ContactFieldRow(icon: "person", label: "Last Name", text: $parsedContact.lastName)
            ContactFieldRow(icon: "building.2", label: "Company", text: $parsedContact.company)
            ContactFieldRow(icon: "phone", label: "Phone", text: $parsedContact.phone, keyboardType: .phonePad)
            ContactFieldRow(icon: "envelope", label: "Email", text: $parsedContact.email, keyboardType: .emailAddress)
            ContactFieldRow(icon: "note.text", label: "Notes", text: $parsedContact.notes, isMultiline: true)
        }
        .padding(16)
        .background(Color.white.opacity(0.6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.forestDark.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 20) {
            Button(action: shareContact) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.textDark)
            }

            Button(action: copyContact) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.textDark)
            }

            Spacer()

            // Save to Contacts
            Button(action: saveToContacts) {
                HStack(spacing: 6) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Add to Contacts")
                        .font(.serifBody(14, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [Color.badgeContact, Color.badgeContact.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(10)
            }
            .disabled(parsedContact.displayName.isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.creamLight)
        .overlay(
            Rectangle()
                .fill(Color.forestDark.opacity(0.1))
                .frame(height: 1),
            alignment: .top
        )
    }

    // MARK: - Parsing

    private func parseContent() {
        let classifier = TextClassifier()
        let content: String
        if let extracted = classifier.extractTriggerTag(from: note.content) {
            content = extracted.cleanedContent
        } else {
            content = note.content
        }

        parsedContact = parseContactContent(content)
    }

    private func parseContactContent(_ content: String) -> ParsedContact {
        var contact = ParsedContact()
        let lines = content.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }

        // Phone regex
        let phonePattern = #"\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}"#
        let phoneRegex = try? NSRegularExpression(pattern: phonePattern, options: [])

        // Email detection
        let emailDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

        var remainingLines: [String] = []

        for line in lines {
            let range = NSRange(line.startIndex..., in: line)

            // Check for phone
            if contact.phone.isEmpty,
               let match = phoneRegex?.firstMatch(in: line, options: [], range: range),
               let matchRange = Range(match.range, in: line) {
                contact.phone = String(line[matchRange])
                // If line is mostly phone, skip it
                if String(line[matchRange]).count > line.count / 2 {
                    continue
                }
            }

            // Check for email
            if contact.email.isEmpty,
               let matches = emailDetector?.matches(in: line, options: [], range: range) {
                for match in matches {
                    if let url = match.url, url.scheme == "mailto" {
                        contact.email = url.absoluteString.replacingOccurrences(of: "mailto:", with: "")
                        break
                    } else if let url = match.url, url.absoluteString.contains("@") {
                        contact.email = url.absoluteString
                        break
                    }
                }
                // Check plain email pattern
                if contact.email.isEmpty && line.contains("@") && line.contains(".") {
                    let emailPattern = #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#
                    if let emailRegex = try? NSRegularExpression(pattern: emailPattern, options: []),
                       let match = emailRegex.firstMatch(in: line, options: [], range: range),
                       let matchRange = Range(match.range, in: line) {
                        contact.email = String(line[matchRange])
                        if contact.email.count > line.count / 2 {
                            continue
                        }
                    }
                }
            }

            remainingLines.append(line)
        }

        // First remaining line is likely the name
        if let firstLine = remainingLines.first {
            let nameParts = firstLine.components(separatedBy: " ").filter { !$0.isEmpty }
            if nameParts.count >= 2 {
                contact.firstName = nameParts[0]
                contact.lastName = nameParts.dropFirst().joined(separator: " ")
            } else if nameParts.count == 1 {
                contact.firstName = nameParts[0]
            }
            remainingLines.removeFirst()
        }

        // Check for company (often second line, or contains company keywords)
        let companyKeywords = ["inc", "llc", "corp", "company", "co.", "ltd", "group", "solutions", "consulting"]
        for (index, line) in remainingLines.enumerated() {
            let lower = line.lowercased()
            if companyKeywords.contains(where: { lower.contains($0) }) || (index == 0 && !line.contains("@") && !line.contains(where: { $0.isNumber })) {
                contact.company = line
                remainingLines.remove(at: index)
                break
            }
        }

        // If no company found but there are remaining lines, first one might be company
        if contact.company.isEmpty && !remainingLines.isEmpty {
            let firstRemaining = remainingLines[0]
            // If it doesn't look like notes (short, no sentences)
            if firstRemaining.count < 40 && !firstRemaining.contains(".") {
                contact.company = firstRemaining
                remainingLines.removeFirst()
            }
        }

        // Rest is notes
        if !remainingLines.isEmpty {
            contact.notes = remainingLines.joined(separator: "\n")
        }

        return contact
    }

    // MARK: - Actions

    private func saveToContacts() {
        let store = CNContactStore()

        store.requestAccess(for: .contacts) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    self.createContact(store: store)
                } else {
                    self.errorMessage = "Please enable Contacts access in Settings."
                }
            }
        }
    }

    private func createContact(store: CNContactStore) {
        let contact = CNMutableContact()

        contact.givenName = parsedContact.firstName
        contact.familyName = parsedContact.lastName
        contact.organizationName = parsedContact.company

        if !parsedContact.phone.isEmpty {
            contact.phoneNumbers = [CNLabeledValue(
                label: CNLabelPhoneNumberMain,
                value: CNPhoneNumber(stringValue: parsedContact.phone)
            )]
        }

        if !parsedContact.email.isEmpty {
            contact.emailAddresses = [CNLabeledValue(
                label: CNLabelHome,
                value: parsedContact.email as NSString
            )]
        }

        if !parsedContact.notes.isEmpty {
            contact.note = parsedContact.notes
        }

        let saveRequest = CNSaveRequest()
        saveRequest.add(contact, toContainerWithIdentifier: nil)

        do {
            try store.execute(saveRequest)

            // Store the saved contact's identifier in the Note for future reference
            note.savedContactIdentifier = contact.identifier
            note.updatedAt = Date()

            // Save the Core Data context
            if let context = note.managedObjectContext {
                try context.save()
            }

            saveSuccess = true
        } catch {
            errorMessage = "Failed to save contact: \(error.localizedDescription)"
        }
    }

    private func shareContact() {
        let text = formatContactText()
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }

    private func copyContact() {
        UIPasteboard.general.string = formatContactText()
    }

    private func formatContactText() -> String {
        var lines: [String] = []
        if !parsedContact.displayName.isEmpty {
            lines.append(parsedContact.displayName)
        }
        if !parsedContact.company.isEmpty {
            lines.append(parsedContact.company)
        }
        if !parsedContact.phone.isEmpty {
            lines.append("Phone: \(parsedContact.phone)")
        }
        if !parsedContact.email.isEmpty {
            lines.append("Email: \(parsedContact.email)")
        }
        if !parsedContact.notes.isEmpty {
            lines.append("")
            lines.append(parsedContact.notes)
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Parsed Contact Model

struct ParsedContact {
    var firstName: String = ""
    var lastName: String = ""
    var company: String = ""
    var phone: String = ""
    var email: String = ""
    var notes: String = ""

    var displayName: String {
        [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
    }

    var initials: String {
        let first = firstName.first.map { String($0).uppercased() } ?? ""
        let last = lastName.first.map { String($0).uppercased() } ?? ""
        return first + last
    }
}

// MARK: - Contact Field Row

struct ContactFieldRow: View {
    let icon: String
    let label: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var isMultiline: Bool = false

    var body: some View {
        HStack(alignment: isMultiline ? .top : .center, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.badgeContact)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.serifCaption(11, weight: .medium))
                    .foregroundColor(.textMedium)

                if isMultiline {
                    TextEditor(text: $text)
                        .font(.serifBody(15, weight: .regular))
                        .foregroundColor(.textDark)
                        .frame(minHeight: 60)
                        .scrollContentBackground(.hidden)
                } else {
                    TextField(label, text: $text)
                        .font(.serifBody(15, weight: .regular))
                        .foregroundColor(.textDark)
                        .keyboardType(keyboardType)
                        .textInputAutocapitalization(keyboardType == .emailAddress ? .never : .words)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContactDetailView(note: Note())
}
