//
//  ContactDetailView.swift
//  QuillStack
//
//  Created on 2025-12-31.
//

import SwiftUI
import Contacts
import CoreData

struct ContactDetailView: View, NoteDetailViewProtocol {
    @ObservedObject var note: Note
    @State private var contact: ParsedContact = ParsedContact()
    @State private var showingSaveSheet = false
    @State private var saveSuccess = false
    @State private var errorMessage: String?
    @State private var showingTypePicker = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.creamLight.ignoresSafeArea()

            VStack(spacing: 0) {
                DetailHeader(
                    title: contact.displayName.isEmpty ? "Contact" : contact.displayName,
                    date: note.createdAt,
                    noteType: "contact",
                    onBack: { dismiss() },
                    classification: note.classification
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
            Text("\(contact.displayName) has been added to your contacts.")
        }
        .alert("Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(isPresented: $showingTypePicker) {
            NoteTypePickerSheet(note: note)
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

                Text(contact.initials)
                    .font(.system(size: 32, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
            }

            // Name
            Text(contact.displayName.isEmpty ? "New Contact" : contact.displayName)
                .font(.serifHeadline(22, weight: .semibold))
                .foregroundColor(.textDark)

            // Job Title
            if !contact.jobTitle.isEmpty {
                Text(contact.jobTitle)
                    .font(.serifBody(14, weight: .medium))
                    .foregroundColor(.textMedium)
            }

            // Company
            if !contact.company.isEmpty {
                Text(contact.company)
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
        VStack(spacing: 0) {
            // Name section
            VStack(spacing: 12) {
                ContactFieldRow(icon: "person", label: "First Name", text: $contact.firstName)
                ContactFieldRow(icon: "person", label: "Last Name", text: $contact.lastName)
            }
            .padding(16)
            .background(Color.white.opacity(0.6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.forestDark.opacity(0.15), lineWidth: 1)
            )

            Spacer().frame(height: 12)

            // Work section
            VStack(spacing: 12) {
                ContactFieldRow(icon: "briefcase", label: "Job Title", text: $contact.jobTitle)
                ContactFieldRow(icon: "building.2", label: "Company", text: $contact.company)
            }
            .padding(16)
            .background(Color.white.opacity(0.6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.forestDark.opacity(0.15), lineWidth: 1)
            )

            Spacer().frame(height: 12)

            // Contact info section
            VStack(spacing: 12) {
                ContactFieldRow(icon: "phone", label: "Phone", text: $contact.phone, keyboardType: .phonePad)
                ContactFieldRow(icon: "envelope", label: "Email", text: $contact.email, keyboardType: .emailAddress)
                ContactFieldRow(icon: "globe", label: "Website", text: $contact.website, keyboardType: .URL)
            }
            .padding(16)
            .background(Color.white.opacity(0.6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.forestDark.opacity(0.15), lineWidth: 1)
            )

            Spacer().frame(height: 12)

            // Address section
            VStack(spacing: 12) {
                ContactFieldRow(icon: "mappin.and.ellipse", label: "Street Address", text: $contact.streetAddress)
                HStack(spacing: 12) {
                    ContactFieldRow(icon: "building", label: "City", text: $contact.city)
                    ContactFieldRow(icon: "map", label: "State", text: $contact.state)
                        .frame(width: 80)
                }
                ContactFieldRow(icon: "number", label: "ZIP Code", text: $contact.zipCode, keyboardType: .numberPad)
            }
            .padding(16)
            .background(Color.white.opacity(0.6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.forestDark.opacity(0.15), lineWidth: 1)
            )

            Spacer().frame(height: 12)

            // Notes section
            VStack(spacing: 12) {
                ContactFieldRow(icon: "note.text", label: "Notes", text: $contact.notes, isMultiline: true)
            }
            .padding(16)
            .background(Color.white.opacity(0.6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.forestDark.opacity(0.15), lineWidth: 1)
            )
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 16) {
            // Change Type button
            Button(action: { showingTypePicker = true }) {
                Image(systemName: "arrow.left.arrow.right.circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.textDark)
            }
            .accessibilityLabel("Change note type")

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

            if !contact.website.isEmpty {
                Button(action: openWebsite) {
                    Image(systemName: "safari")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.badgeContact)
                }
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
            .disabled(contact.displayName.isEmpty)
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

    // MARK: - NoteDetailViewProtocol

    func saveChanges() {
        // ContactDetailView is read-only; contacts are saved via saveToContacts()
    }

    // MARK: - Parsing

    private func parseContent() {
        // First, try to load from extractedDataJSON if available
        if let extractedJSON = note.extractedDataJSON,
           let jsonData = extractedJSON.data(using: .utf8) {
            do {
                let extractedContact = try JSONDecoder().decode(ParsedContact.self, from: jsonData)
                contact = extractedContact
                return
            } catch {
                // Log JSON decoding error for debugging, but fall back gracefully
                // Don't expose error details to user - just use fallback parsing
                print("Failed to decode extractedDataJSON for contact: \(error.localizedDescription)")
            }
        }
        
        // Fall back to parsing from content
        let classifier = TextClassifier()
        let content: String
        if let extracted = classifier.extractTriggerTag(from: note.content) {
            content = extracted.cleanedContent
        } else {
            content = note.content
        }

        contact = ContactParser.parse(content)
    }

    // MARK: - Actions

    private func saveToContacts() {
        Task {
            let contactsService = ContactsService.shared
            
            // Check authorization
            let status = contactsService.authorizationStatus
            if status == .notDetermined {
                let granted = await contactsService.requestAccess()
                if !granted {
                    await MainActor.run {
                        errorMessage = "Please enable Contacts access in Settings."
                    }
                    return
                }
            } else if status == .denied || status == .restricted {
                await MainActor.run {
                    errorMessage = "Contacts access is required. Please enable it in Settings."
                }
                return
            }
            
            // Create and save contact
            do {
                _ = try contactsService.createContact(from: contact)
                await MainActor.run {
                    saveSuccess = true
                }
            } catch let error as ContactsError {
                await MainActor.run {
                    // Use user-facing message (sanitized, no system details)
                    errorMessage = error.userFacingMessage
                }
            } catch {
                await MainActor.run {
                    // Generic fallback for unexpected errors
                    errorMessage = "Unable to save contact. Please try again."
                }
            }
        }
    }

    private func openWebsite() {
        var urlString = contact.website
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            urlString = "https://" + urlString
        }
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
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
        if !contact.displayName.isEmpty {
            lines.append(contact.displayName)
        }
        if !contact.jobTitle.isEmpty {
            lines.append(contact.jobTitle)
        }
        if !contact.company.isEmpty {
            lines.append(contact.company)
        }
        if !contact.phone.isEmpty {
            lines.append("Phone: \(contact.phone)")
        }
        if !contact.email.isEmpty {
            lines.append("Email: \(contact.email)")
        }
        if !contact.website.isEmpty {
            lines.append("Web: \(contact.website)")
        }
        if contact.hasAddress {
            lines.append("")
            lines.append(contact.formattedAddress)
        }
        if !contact.notes.isEmpty {
            lines.append("")
            lines.append(contact.notes)
        }
        return lines.joined(separator: "\n")
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
