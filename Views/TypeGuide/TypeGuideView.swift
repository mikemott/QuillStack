//
//  TypeGuideView.swift
//  QuillStack
//
//  Created on 2026-01-01.
//

import SwiftUI

struct TypeGuideView: View {
    @State private var selectedType: (any NoteTypePlugin)?
    @State private var showingExample = false

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(NoteTypeRegistry.shared.allPlugins(), id: \.id) { plugin in
                        TypeCard(plugin: plugin)
                            .onTapGesture {
                                selectedType = plugin
                                showingExample = true
                            }
                    }
                }
                .padding()
            }
            .navigationTitle("Note Types")
            .background(Color.creamLight)
            .sheet(isPresented: $showingExample) {
                if let plugin = selectedType {
                    TypeExampleSheet(plugin: plugin)
                }
            }
        }
    }
}

struct TypeCard: View {
    let plugin: any NoteTypePlugin

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: plugin.icon)
                .font(.system(size: 36))
                .foregroundColor(plugin.badgeColor)
                .frame(height: 44)

            Text(plugin.displayName)
                .font(.headline)
                .foregroundColor(.textDark)

            VStack(spacing: 4) {
                ForEach(plugin.triggers.prefix(2), id: \.self) { trigger in
                    Text(trigger)
                        .font(.caption)
                        .foregroundColor(.textMedium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.paperBeige)
                        .cornerRadius(4)
                }
                if plugin.triggers.count > 2 {
                    Text("+\(plugin.triggers.count - 2) more")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Text(descriptionFor(plugin.type))
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 4)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private func descriptionFor(_ type: NoteType) -> String {
        switch type {
        case .general:
            return "Unstructured notes and freeform content"
        case .todo:
            return "Task lists with checkboxes"
        case .meeting:
            return "Meeting notes → Calendar"
        case .email:
            return "Draft emails for sending"
        case .reminder:
            return "Quick reminders with alerts"
        case .contact:
            return "Contact info → Contacts"
        case .expense:
            return "Track spending and receipts"
        case .shopping:
            return "Shopping and grocery lists"
        case .recipe:
            return "Cooking instructions and ingredients"
        case .event:
            return "Events → Calendar"
        case .idea:
            return "Capture thoughts and ideas"
        case .claudePrompt:
            return "Feature requests → Linear"
        }
    }
}

struct TypeExampleSheet: View {
    let plugin: any NoteTypePlugin
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Image(systemName: plugin.icon)
                            .font(.system(size: 32))
                            .foregroundColor(plugin.badgeColor)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(plugin.displayName)
                                .font(.title2)
                                .fontWeight(.bold)

                            Text("Example note")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.bottom, 8)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Triggers")
                            .font(.headline)
                            .foregroundColor(.textDark)

                        FlowLayout(spacing: 8) {
                            ForEach(plugin.triggers, id: \.self) { trigger in
                                Text(trigger)
                                    .font(.subheadline)
                                    .foregroundColor(.textDark)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(plugin.badgeColor.opacity(0.15))
                                    .cornerRadius(6)
                            }
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Example Content")
                            .font(.headline)
                            .foregroundColor(.textDark)

                        Text(exampleContentFor(plugin.type))
                            .font(.body)
                            .foregroundColor(.textMedium)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.paperBeige)
                            .cornerRadius(8)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("What happens")
                            .font(.headline)
                            .foregroundColor(.textDark)

                        Text(actionDescriptionFor(plugin.type))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .background(Color.creamLight)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.forestDark)
                }
            }
        }
    }

    private func exampleContentFor(_ type: NoteType) -> String {
        switch type {
        case .general:
            return "Just some quick thoughts I wanted to capture. No specific structure needed, just freeform notes."
        case .todo:
            return "☐ Buy groceries\n☐ Call dentist\n☐ Finish project report\n☐ Exercise for 30 min"
        case .meeting:
            return "Q1 Planning Meeting\nJan 15, 2026 at 2:00 PM\nWith: Sarah, Mike, Alex\n\n- Discussed new feature roadmap\n- Reviewed budget\n- Action: Sarah to draft timeline"
        case .email:
            return "To: team@company.com\nRe: Project Update\n\nHi team, wanted to share a quick update on the launch timeline..."
        case .reminder:
            return "Reminder: Pick up dry cleaning\nToday at 5:00 PM"
        case .contact:
            return "John Smith\nPhone: (555) 123-4567\nEmail: john@example.com\nCompany: Acme Corp"
        case .expense:
            return "Lunch meeting\n$45.00\nJan 12, 2026\nCategory: Meals"
        case .shopping:
            return "Shopping List:\n- Milk\n- Eggs\n- Bread\n- Chicken\n- Apples"
        case .recipe:
            return "Chocolate Chip Cookies\n\nIngredients:\n- 2 cups flour\n- 1 cup butter\n- 1 cup chocolate chips\n\nBake at 350°F for 12 min"
        case .event:
            return "Dinner with friends\nSaturday, Jan 18 at 7:00 PM\nLocation: The Garden Bistro"
        case .idea:
            return "What if we added a dark mode toggle? Could help with battery life and eye strain at night."
        case .claudePrompt:
            return "Feature Request: Add ability to search notes by date range. Would be super helpful for finding old meeting notes."
        }
    }

    private func actionDescriptionFor(_ type: NoteType) -> String {
        switch type {
        case .general:
            return "Saved as a general note with no special processing"
        case .todo:
            return "Extracts checkbox items and tracks completion status"
        case .meeting:
            return "Parses meeting details and offers to add to your calendar"
        case .email:
            return "Creates an email draft you can send from Mail"
        case .reminder:
            return "Creates a reminder with optional time-based alert"
        case .contact:
            return "Extracts contact details and offers to save to Contacts"
        case .expense:
            return "Tracks amount and categorizes for expense reporting"
        case .shopping:
            return "Creates a checkable shopping list"
        case .recipe:
            return "Organizes ingredients and instructions for cooking"
        case .event:
            return "Parses event details and offers to add to your calendar"
        case .idea:
            return "Saves your idea for future reference"
        case .claudePrompt:
            return "Creates a Linear issue for the development team"
        }
    }
}

#Preview {
    TypeGuideView()
}
