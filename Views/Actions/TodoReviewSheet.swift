//
//  TodoReviewSheet.swift
//  QuillStack
//
//  Phase 3.5 - Reminders Action with Review Sheet
//  Review and edit todo tasks before saving to Reminders app.
//

import SwiftUI
import EventKit

struct TodoReviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var editableTasks: [EditableTask]
    @State private var newTaskText: String = ""
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var showingListPicker = false
    @State private var selectedList: EKCalendar?
    @State private var availableLists: [EKCalendar] = []

    private let remindersService = RemindersService.shared
    let onSave: ([EditableTask]) async throws -> Void
    let onCancel: () -> Void

    init(tasks: [ExtractedTodo], onSave: @escaping ([EditableTask]) async throws -> Void, onCancel: @escaping () -> Void) {
        self._editableTasks = State(initialValue: tasks.map { EditableTask(from: $0) })
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.creamLight.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Header with icon
                        headerSection

                        // Editable tasks section
                        editableTasksSection

                        // Add task section
                        addTaskSection
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
            .navigationTitle("Review Tasks")
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
                    Button(action: { showingListPicker = true }) {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Save")
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundColor(.badgeTodo)
                    .disabled(editableTasks.isEmpty || isSaving)
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
        .sheet(isPresented: $showingListPicker) {
            listPickerSheet
        }
        .onAppear {
            loadLists()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.badgeTodo, Color.badgeTodo.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "checklist")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.white)
            }

            Text("Review and edit tasks before saving")
                .font(.serifBody(14, weight: .regular))
                .foregroundColor(.textMedium)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    // MARK: - Editable Tasks Section

    private var editableTasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Tasks")
                    .font(.serifBody(13, weight: .semibold))
                    .foregroundColor(.textMedium)
                    .padding(.horizontal, 4)

                Spacer()

                Text("\(editableTasks.count) task\(editableTasks.count == 1 ? "" : "s")")
                    .font(.serifCaption(11, weight: .medium))
                    .foregroundColor(.textLight)
            }

            VStack(spacing: 0) {
                ForEach($editableTasks) { $task in
                    EditableTaskRow(task: $task, onDelete: {
                        deleteTask(task)
                    })

                    if task.id != editableTasks.last?.id {
                        Divider()
                            .padding(.leading, 52)
                    }
                }
            }
            .background(Color.white.opacity(0.6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.forestDark.opacity(0.15), lineWidth: 1)
            )
        }
    }

    // MARK: - Add Task Section

    private var addTaskSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Task")
                .font(.serifBody(13, weight: .semibold))
                .foregroundColor(.textMedium)
                .padding(.horizontal, 4)

            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(.badgeTodo)

                TextField("New task...", text: $newTaskText)
                    .font(.serifBody(15, weight: .regular))
                    .foregroundColor(.textDark)
                    .onSubmit {
                        addTask()
                    }

                if !newTaskText.isEmpty {
                    Button(action: addTask) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundColor(.badgeTodo)
                    }
                }
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

    // MARK: - List Picker Sheet

    private var listPickerSheet: some View {
        NavigationStack {
            List(availableLists, id: \.calendarIdentifier) { list in
                Button(action: {
                    selectedList = list
                    handleSave(to: list)
                }) {
                    HStack {
                        Circle()
                            .fill(Color(cgColor: list.cgColor))
                            .frame(width: 12, height: 12)
                        Text(list.title)
                            .font(.serifBody(16, weight: .regular))
                            .foregroundColor(.textDark)
                        Spacer()
                        if list == remindersService.getDefaultReminderList() {
                            Text("Default")
                                .font(.serifCaption(12, weight: .medium))
                                .foregroundColor(.textMedium)
                        }
                    }
                }
            }
            .navigationTitle("Choose Reminders List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingListPicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Helpers

    private func loadLists() {
        Task {
            let status = remindersService.authorizationStatus
            if status == .notDetermined {
                let granted = await remindersService.requestAccess()
                if !granted {
                    await MainActor.run {
                        saveError = "Reminders access is required to save tasks."
                    }
                    return
                }
            } else if status == .denied || status == .restricted {
                await MainActor.run {
                    saveError = "Reminders access denied. Please enable it in Settings."
                }
                return
            }

            await MainActor.run {
                availableLists = remindersService.getReminderLists()
                selectedList = remindersService.getDefaultReminderList()
            }
        }
    }

    private func addTask() {
        let trimmed = newTaskText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        editableTasks.append(EditableTask(
            text: trimmed,
            isCompleted: false,
            priority: "normal",
            dueDate: nil,
            notes: nil
        ))
        newTaskText = ""
    }

    private func deleteTask(_ task: EditableTask) {
        editableTasks.removeAll { $0.id == task.id }
    }

    // MARK: - Actions

    private func handleSave(to list: EKCalendar) {
        guard !editableTasks.isEmpty else {
            saveError = "Please add at least one task."
            showingListPicker = false
            return
        }

        Task {
            isSaving = true
            saveError = nil

            do {
                // Save each task to Reminders
                for task in editableTasks {
                    let reminder = EKReminder(eventStore: remindersService.eventStore)
                    reminder.calendar = list
                    reminder.title = task.text
                    reminder.isCompleted = task.isCompleted

                    // Set due date if available
                    if let dueDate = task.dueDate {
                        let calendar = Calendar.current
                        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
                        components.timeZone = TimeZone.current
                        reminder.dueDateComponents = components
                    }

                    // Set priority
                    switch task.priority.lowercased() {
                    case "high", "urgent":
                        reminder.priority = 1
                    case "medium":
                        reminder.priority = 5
                    default:
                        reminder.priority = 0
                    }

                    // Add notes if available
                    if let notes = task.notes, !notes.isEmpty {
                        reminder.notes = notes
                    }

                    try remindersService.eventStore.save(reminder, commit: false)
                }

                // Commit all changes at once
                try remindersService.eventStore.commit()

                // Call onSave with tasks
                try await onSave(editableTasks)

                // Only dismiss on success
                await MainActor.run {
                    isSaving = false
                    showingListPicker = false
                    dismiss()
                }
            } catch {
                // Show error and keep sheet open for user to retry or cancel
                await MainActor.run {
                    isSaving = false
                    showingListPicker = false
                    saveError = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Editable Task Model

struct EditableTask: Identifiable, Equatable {
    let id: UUID
    var text: String
    var isCompleted: Bool
    var priority: String
    var dueDate: Date?
    var notes: String?

    init(id: UUID = UUID(), text: String, isCompleted: Bool, priority: String, dueDate: Date?, notes: String?) {
        self.id = id
        self.text = text
        self.isCompleted = isCompleted
        self.priority = priority
        self.dueDate = dueDate
        self.notes = notes
    }

    init(from extracted: ExtractedTodo) {
        self.id = extracted.id
        self.text = extracted.text
        self.isCompleted = extracted.isCompleted
        self.priority = extracted.priority
        self.dueDate = extracted.parsedDueDate
        self.notes = extracted.notes
    }
}

// MARK: - Editable Task Row

struct EditableTaskRow: View {
    @Binding var task: EditableTask
    @State private var showingDetails = false
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Main row
            HStack(spacing: 12) {
                // Checkbox
                Button(action: {
                    task.isCompleted.toggle()
                }) {
                    Image(systemName: task.isCompleted ? "checkmark.square.fill" : "square")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(task.isCompleted ? .badgeTodo : .textMedium.opacity(0.5))
                }

                VStack(alignment: .leading, spacing: 4) {
                    // Task text
                    TextField("Task", text: $task.text)
                        .font(.serifBody(15, weight: .regular))
                        .foregroundColor(task.isCompleted ? .textMedium.opacity(0.6) : .textDark)

                    // Metadata row
                    HStack(spacing: 8) {
                        if task.priority != "normal" {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: 10))
                                Text(task.priority.capitalized)
                                    .font(.serifCaption(10, weight: .medium))
                            }
                            .foregroundColor(task.priority == "high" ? .red : .orange)
                        }

                        if let dueDate = task.dueDate {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 10))
                                Text(dueDate.formatted(date: .abbreviated, time: .omitted))
                                    .font(.serifCaption(10, weight: .regular))
                            }
                            .foregroundColor(.textLight)
                        }
                    }
                }

                Spacer()

                // Edit button
                Button(action: {
                    showingDetails.toggle()
                }) {
                    Image(systemName: showingDetails ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.textMedium)
                }

                // Delete button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.red.opacity(0.7))
                }
            }
            .padding(16)

            // Details section (expanded)
            if showingDetails {
                VStack(spacing: 12) {
                    Divider()

                    // Priority picker
                    HStack {
                        Image(systemName: "exclamationmark.circle")
                            .font(.system(size: 14))
                            .foregroundColor(.textMedium)
                        Text("Priority")
                            .font(.serifCaption(11, weight: .medium))
                            .foregroundColor(.textMedium)
                        Spacer()
                        Menu {
                            Button("Normal") { task.priority = "normal" }
                            Button("Medium") { task.priority = "medium" }
                            Button("High") { task.priority = "high" }
                        } label: {
                            Text(task.priority.capitalized)
                                .font(.serifBody(14, weight: .regular))
                                .foregroundColor(.badgeTodo)
                        }
                    }
                    .padding(.horizontal, 16)

                    // Due date picker
                    HStack {
                        Image(systemName: "calendar")
                            .font(.system(size: 14))
                            .foregroundColor(.textMedium)
                        Text("Due Date")
                            .font(.serifCaption(11, weight: .medium))
                            .foregroundColor(.textMedium)
                        Spacer()
                        if let dueDate = task.dueDate {
                            DatePicker("", selection: Binding(
                                get: { dueDate },
                                set: { task.dueDate = $0 }
                            ), displayedComponents: [.date, .hourAndMinute])
                                .labelsHidden()
                                .datePickerStyle(.compact)
                            Button(action: { task.dueDate = nil }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.textLight)
                            }
                        } else {
                            Button("Add") {
                                task.dueDate = Date()
                            }
                            .font(.serifBody(14, weight: .regular))
                            .foregroundColor(.badgeTodo)
                        }
                    }
                    .padding(.horizontal, 16)

                    // Notes field
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "note.text")
                                .font(.system(size: 14))
                                .foregroundColor(.textMedium)
                            Text("Notes")
                                .font(.serifCaption(11, weight: .medium))
                                .foregroundColor(.textMedium)
                        }
                        TextField("Additional notes...", text: Binding(
                            get: { task.notes ?? "" },
                            set: { task.notes = $0.isEmpty ? nil : $0 }
                        ), axis: .vertical)
                            .font(.serifBody(13, weight: .regular))
                            .foregroundColor(.textDark)
                            .lineLimit(2...4)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
                .background(Color.paperBeige.opacity(0.3))
            }
        }
    }
}

// MARK: - RemindersService Extension

extension RemindersService {
    var eventStore: EKEventStore {
        // Access the private eventStore for TodoReviewSheet
        // Note: This should ideally be made internal in RemindersService
        Mirror(reflecting: self).children.first { $0.label == "eventStore" }?.value as? EKEventStore ?? EKEventStore()
    }
}

#Preview {
    TodoReviewSheet(
        tasks: [
            ExtractedTodo(text: "Buy groceries", isCompleted: false, priority: "normal", dueDate: nil, notes: nil),
            ExtractedTodo(text: "Call dentist", isCompleted: false, priority: "high", dueDate: "tomorrow", notes: "Make appointment for checkup"),
            ExtractedTodo(text: "Finish report", isCompleted: true, priority: "medium", dueDate: nil, notes: nil)
        ],
        onSave: { _ in
            try await Task.sleep(nanoseconds: 500_000_000)
        },
        onCancel: { }
    )
}
