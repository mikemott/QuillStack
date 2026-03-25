import SwiftUI
import EventKit

struct TodoActionView: View {
    let extraction: TodoExtraction
    let eventStore: EKEventStore
    var onDismiss: () -> Void

    @State private var selectedItems: Set<Int> = []
    @State private var authStatus: EKAuthorizationStatus = .notDetermined
    @State private var showResult: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let items = extraction.items, !items.isEmpty {
                        ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                            todoRow(item, index: index)
                        }
                    } else {
                        Text("No tasks extracted")
                            .font(QSFont.sans(size: 15))
                            .foregroundStyle(QSColor.onSurfaceMuted)
                            .padding(.top, 20)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(QSSurface.base)
            .navigationTitle("To-Dos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { onDismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add to Reminders") { addToReminders() }
                        .fontWeight(.semibold)
                        .disabled(selectedItems.isEmpty)
                }
            }
            .alert("Reminders", isPresented: Binding(
                get: { showResult != nil },
                set: { if !$0 { showResult = nil; onDismiss() } }
            )) {
                Button("OK") { showResult = nil; onDismiss() }
            } message: {
                Text(showResult ?? "")
            }
            .onAppear {
                if let items = extraction.items {
                    selectedItems = Set(items.indices)
                }
                authStatus = EKEventStore.authorizationStatus(for: .reminder)
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func todoRow(_ item: TodoItem, index: Int) -> some View {
        let isSelected = selectedItems.contains(index)
        return Button {
            if isSelected { selectedItems.remove(index) } else { selectedItems.insert(index) }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? Color(hex: "#90EE90") : QSColor.onSurfaceMuted)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title ?? "Untitled task")
                        .font(QSFont.sans(size: 15))
                        .foregroundStyle(QSColor.onSurface)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 8) {
                        if let due = item.dueDate {
                            Label(due, systemImage: "calendar")
                                .font(QSFont.mono(size: 12))
                                .foregroundStyle(QSColor.onSurfaceMuted)
                        }
                        if let priority = item.priority {
                            Text(priority.uppercased())
                                .font(QSFont.mono(size: 10))
                                .foregroundStyle(priorityColor(priority))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(priorityColor(priority).opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }

                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(QSSurface.container)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func priorityColor(_ priority: String) -> Color {
        switch priority.lowercased() {
        case "high": return .red
        case "medium": return .orange
        default: return QSColor.onSurfaceMuted
        }
    }

    private func addToReminders() {
        Task {
            do {
                if authStatus != .fullAccess {
                    let granted = try await eventStore.requestFullAccessToReminders()
                    guard granted else {
                        showResult = "Reminders access was denied. Enable it in Settings."
                        return
                    }
                }

                guard let items = extraction.items else { return }
                guard let defaultList = eventStore.defaultCalendarForNewReminders() else {
                    showResult = "No default reminders list found. Check your Reminders settings."
                    return
                }
                var addedCount = 0

                for index in selectedItems.sorted() {
                    guard index < items.count else { continue }
                    let item = items[index]

                    let reminder = EKReminder(eventStore: eventStore)
                    reminder.title = item.title ?? "Untitled"
                    reminder.calendar = defaultList

                    if let dueDateStr = item.dueDate {
                        let formatter = ISO8601DateFormatter()
                        formatter.formatOptions = [.withFullDate]
                        if let date = formatter.date(from: dueDateStr) {
                            reminder.dueDateComponents = Calendar.current.dateComponents(
                                [.year, .month, .day], from: date
                            )
                        }
                    }

                    if let priority = item.priority?.lowercased() {
                        switch priority {
                        case "high": reminder.priority = Int(EKReminderPriority.high.rawValue)
                        case "medium": reminder.priority = Int(EKReminderPriority.medium.rawValue)
                        case "low": reminder.priority = Int(EKReminderPriority.low.rawValue)
                        default: break
                        }
                    }

                    if let notes = item.notes {
                        reminder.notes = notes
                    }

                    try eventStore.save(reminder, commit: false)
                    addedCount += 1
                }

                try eventStore.commit()
                showResult = "Added \(addedCount) reminder\(addedCount == 1 ? "" : "s")."
            } catch {
                showResult = "Failed to add reminders: \(error.localizedDescription)"
            }
        }
    }
}
