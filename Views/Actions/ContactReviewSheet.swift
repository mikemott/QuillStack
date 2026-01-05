//
//  ContactReviewSheet.swift
//  QuillStack
//
//  Phase 3.3 - Contact Action with Review Sheet
//  Review and edit contact before saving to Contacts app.
//

import SwiftUI
import Contacts

struct ContactReviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var contact: ParsedContact
    @State private var isSaving = false
    @State private var saveError: String?

    let onSave: (ParsedContact) -> Void
    let onCancel: () -> Void

    init(contact: ParsedContact, onSave: @escaping (ParsedContact) -> Void, onCancel: @escaping () -> Void) {
        self._contact = State(initialValue: contact)
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.creamLight.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Header with avatar
                        headerSection

                        // Editable fields
                        editableFieldsSection
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
            }
            .navigationTitle("Review Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                    .foregroundColor(.textDark)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: handleSave) {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Save")
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundColor(.badgeContact)
                    .disabled(contact.displayName.isEmpty || isSaving)
                }
            }
        }
        .alert("Error", isPresented: .init(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) {
                saveError = nil
            }
        } message: {
            if let error = saveError {
                Text(error)
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
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

            Text("Review and edit contact details before saving")
                .font(.serifBody(14, weight: .regular))
                .foregroundColor(.textMedium)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    // MARK: - Editable Fields Section

    private var editableFieldsSection: some View {
        VStack(spacing: 12) {
            // Name section
            sectionCard(title: "Name") {
                VStack(spacing: 12) {
                    ContactFieldRow(icon: "person", label: "First Name", text: $contact.firstName)
                    ContactFieldRow(icon: "person", label: "Last Name", text: $contact.lastName)
                }
            }

            // Work section
            sectionCard(title: "Work") {
                VStack(spacing: 12) {
                    ContactFieldRow(icon: "briefcase", label: "Job Title", text: $contact.jobTitle)
                    ContactFieldRow(icon: "building.2", label: "Company", text: $contact.company)
                }
            }

            // Contact info section
            sectionCard(title: "Contact Information") {
                VStack(spacing: 12) {
                    ContactFieldRow(icon: "phone", label: "Phone", text: $contact.phone, keyboardType: .phonePad)
                    ContactFieldRow(icon: "envelope", label: "Email", text: $contact.email, keyboardType: .emailAddress)
                    ContactFieldRow(icon: "globe", label: "Website", text: $contact.website, keyboardType: .URL)
                }
            }

            // Address section
            sectionCard(title: "Address") {
                VStack(spacing: 12) {
                    ContactFieldRow(icon: "mappin.and.ellipse", label: "Street Address", text: $contact.streetAddress)
                    HStack(spacing: 12) {
                        ContactFieldRow(icon: "building", label: "City", text: $contact.city)
                        ContactFieldRow(icon: "map", label: "State", text: $contact.state)
                            .frame(width: 80)
                    }
                    ContactFieldRow(icon: "number", label: "ZIP Code", text: $contact.zipCode, keyboardType: .numberPad)
                }
            }

            // Notes section
            sectionCard(title: "Notes") {
                ContactFieldRow(icon: "note.text", label: "Notes", text: $contact.notes, isMultiline: true)
            }
        }
    }

    // MARK: - Section Card Helper

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.serifBody(13, weight: .semibold))
                .foregroundColor(.textMedium)
                .padding(.horizontal, 4)

            VStack(spacing: 12) {
                content()
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

    // MARK: - Actions

    private func handleSave() {
        // Validate minimum required data
        guard !contact.displayName.isEmpty else {
            saveError = "Please enter at least a first and last name."
            return
        }

        onSave(contact)
        dismiss()
    }
}

#Preview {
    ContactReviewSheet(
        contact: ParsedContact(
            firstName: "John",
            lastName: "Doe",
            jobTitle: "Software Engineer",
            company: "Tech Corp",
            phone: "(555) 123-4567",
            email: "john@example.com"
        ),
        onSave: { _ in },
        onCancel: { }
    )
}
