//
//  ReminderDetailView.swift
//  QuillStack
//
//  Created on 2025-12-31.
//

import SwiftUI
import EventKit
import CoreData

struct ReminderDetailView: View, NoteDetailViewProtocol {
    @ObservedObject var note: Note
    @State private var reminderText: String = ""
    @State private var dueDate: Date?
    @State private var hasDueDate: Bool = false
    @State private var showingExportSheet: Bool = false
    @State private var showingDatePicker: Bool = false
    @State private var showingSaveError: Bool = false
    @State private var saveErrorMessage: String = ""
    @State private var showingTypePicker = false
    @State private var showingTagEditor = false // QUI-184
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.creamLight.ignoresSafeArea()

            VStack(spacing: 0) {
                DetailHeader(
                    title: "Reminder",
                    date: note.createdAt,
                    noteType: "reminder",
                    onBack: { dismiss() },
                    classification: note.classification
                )

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Reminder text editor
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Reminder")
                                .font(.serifCaption(13, weight: .medium))
                                .foregroundColor(.textMedium)

                            TextEditor(text: $reminderText)
                                .font(.serifBody(16, weight: .regular))
                                .foregroundColor(.textDark)
                                .frame(minHeight: 100)
                                .padding(12)
                                .background(Color.white.opacity(0.6))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.forestDark.opacity(0.15), lineWidth: 1)
                                )
                                .onChange(of: reminderText) { _, _ in saveChanges() }
                        }

                        // Due date section
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle(isOn: $hasDueDate) {
                                HStack(spacing: 8) {
                                    Image(systemName: "clock")
                                        .foregroundColor(.badgeReminder)
                                    Text("Due Date")
                                        .font(.serifBody(16, weight: .medium))
                                        .foregroundColor(.textDark)
                                }
                            }
                            .tint(.badgeReminder)
                            .onChange(of: hasDueDate) { _, newValue in
                                if newValue && dueDate == nil {
                                    dueDate = Date().addingTimeInterval(3600)
                                }
                            }

                            if hasDueDate {
                                DatePicker(
                                    "When",
                                    selection: Binding(
                                        get: { dueDate ?? Date() },
                                        set: { dueDate = $0 }
                                    ),
                                    displayedComponents: [.date, .hourAndMinute]
                                )
                                .font(.serifBody(15, weight: .regular))
                                .tint(.badgeReminder)
                            }
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.6))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.forestDark.opacity(0.15), lineWidth: 1)
                        )

                        // Tags section (QUI-184)
                        TagDisplaySection(note: note, showingTagEditor: $showingTagEditor)

                    // Related notes section (QUI-161)
                    if note.linkCount > 0 {
                        RelatedNotesSection(note: note) { selectedNote in
                            // TODO: Navigate to selected note
                            print("Selected related note: \(selectedNote.id)")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
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
        .sheet(isPresented: $showingExportSheet) {
            SingleReminderExportSheet(
                reminderText: reminderText,
                dueDate: hasDueDate ? dueDate : nil
            )
            .presentationDetents([.medium])
        }
        .alert("Save Failed", isPresented: $showingSaveError) {
            Button("OK") { }
        } message: {
            Text(saveErrorMessage)
        }
        .sheet(isPresented: $showingTypePicker) {
            NoteTypePickerSheet(note: note)
        }
        .sheet(isPresented: $showingTagEditor) {
            TagEditorSheet(note: note)
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            Spacer()
            
            // Single Actions menu consolidating all actions
            Menu {
                // Primary action - Add to Reminders
                Button(action: { showingExportSheet = true }) {
                    Label("Add to Reminders", systemImage: "bell.badge")
                }
                
                Divider()
                
                // Share
                Button(action: shareNote) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                
                // Copy
                Button(action: copyContent) {
                    Label("Copy Text", systemImage: "doc.on.clipboard")
                }
                
                Section {
                    Button(action: { showingTypePicker = true }) {
                        Label("Change Type", systemImage: "arrow.left.arrow.right.circle")
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Actions")
                        .font(.serifBody(16, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [Color.forestDark, Color.forestMedium],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(10)
            }
            .accessibilityLabel("Actions menu")
            
            Spacer()
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

    // MARK: - Helpers

    private func parseContent() {
        let classifier = TextClassifier()
        let content: String
        if let extracted = classifier.extractTriggerTag(from: note.content) {
            content = extracted.cleanedContent
        } else {
            content = note.content
        }

        // Try to parse date from content
        let parsed = parseReminderContent(content)
        reminderText = parsed.text
        dueDate = parsed.date
        hasDueDate = parsed.date != nil
    }

    private func parseReminderContent(_ content: String) -> (text: String, date: Date?) {
        let lines = content.components(separatedBy: .newlines)
        var textLines: [String] = []
        var foundDate: Date?

        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Try to detect date in this line
            if foundDate == nil, let detector = detector {
                let range = NSRange(trimmed.startIndex..., in: trimmed)
                if let match = detector.firstMatch(in: trimmed, options: [], range: range),
                   let matchDate = match.date {
                    foundDate = matchDate
                    // If the entire line is just a date, skip adding it to text
                    let matchRange = Range(match.range, in: trimmed)!
                    let matchedText = String(trimmed[matchRange])
                    if matchedText.count > trimmed.count / 2 {
                        continue
                    }
                }
            }
            textLines.append(trimmed)
        }

        return (textLines.joined(separator: "\n"), foundDate)
    }

    func saveChanges() {
        let classifier = TextClassifier()
        var newContent = ""

        if let extracted = classifier.extractTriggerTag(from: note.content) {
            newContent = extracted.tag + "\n"
        }

        newContent += reminderText

        note.content = newContent
        note.updatedAt = Date()
        do {
            try CoreDataStack.shared.saveViewContext()
        } catch {
            saveErrorMessage = error.localizedDescription
            showingSaveError = true
        }
    }

    private func shareNote() {
        var text = reminderText
        if hasDueDate, let date = dueDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            text += "\nDue: \(formatter.string(from: date))"
        }

        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }

    private func copyContent() {
        var text = reminderText
        if hasDueDate, let date = dueDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            text += "\nDue: \(formatter.string(from: date))"
        }
        UIPasteboard.general.string = text
    }
}

// MARK: - Single Reminder Export Sheet

struct SingleReminderExportSheet: View {
    let reminderText: String
    let dueDate: Date?

    @State private var selectedList: EKCalendar?
    @State private var availableLists: [EKCalendar] = []
    @State private var isExporting = false
    @State private var exportSuccess = false
    @State private var errorMessage: String?
    @State private var isAccessDenied = false
    @Environment(\.dismiss) private var dismiss

    private let remindersService = RemindersService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color.creamLight.ignoresSafeArea()

                VStack(spacing: 20) {
                    if exportSuccess {
                        successView
                    } else if let error = errorMessage {
                        errorView(error)
                    } else {
                        listPickerView
                    }
                }
                .padding(20)
            }
            .navigationTitle("Export to Reminders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear { loadLists() }
    }

    private var listPickerView: some View {
        VStack(spacing: 20) {
            // Preview
            VStack(alignment: .leading, spacing: 8) {
                Text("Reminder")
                    .font(.serifCaption(12, weight: .medium))
                    .foregroundColor(.textMedium)

                Text(reminderText)
                    .font(.serifBody(15, weight: .regular))
                    .foregroundColor(.textDark)
                    .lineLimit(3)

                if let date = dueDate {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                        Text(date.formattedForNotes())
                            .font(.serifCaption(12, weight: .regular))
                    }
                    .foregroundColor(.badgeReminder)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.white.opacity(0.6))
            .cornerRadius(8)

            // List picker
            if !availableLists.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add to List")
                        .font(.serifCaption(12, weight: .medium))
                        .foregroundColor(.textMedium)

                    Picker("List", selection: $selectedList) {
                        ForEach(availableLists, id: \.calendarIdentifier) { list in
                            Text(list.title).tag(list as EKCalendar?)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 120)
                }
            }

            Spacer()

            // Export button
            Button(action: exportReminder) {
                HStack {
                    if isExporting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "bell.badge")
                        Text("Add to Reminders")
                    }
                }
                .font(.serifBody(16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color.badgeReminder, Color.badgeReminder.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(12)
            }
            .disabled(isExporting || selectedList == nil)
        }
    }

    private var successView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.appSuccess)

            Text("Added to Reminders")
                .font(.serifHeadline(20, weight: .semibold))
                .foregroundColor(.textDark)

            Button("Done") { dismiss() }
                .font(.serifBody(16, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 40)
                .padding(.vertical, 12)
                .background(Color.forestDark)
                .cornerRadius(10)
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: isAccessDenied ? "lock.circle" : "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)

            Text(message)
                .font(.serifBody(15, weight: .regular))
                .foregroundColor(.textDark)
                .multilineTextAlignment(.center)

            if isAccessDenied {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.serifBody(15, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Color.forestDark)
                .cornerRadius(8)
            } else {
                Button("Try Again") {
                    errorMessage = nil
                }
                .font(.serifBody(15, weight: .medium))
                .foregroundColor(.forestDark)
            }
        }
    }

    private func loadLists() {
        Task {
            let authorized = await remindersService.requestAccess()
            guard authorized else {
                await MainActor.run {
                    isAccessDenied = true
                    errorMessage = "Reminders access is required. Please enable it in Settings."
                }
                return
            }

            await MainActor.run {
                isAccessDenied = false
                availableLists = remindersService.getReminderLists()
                selectedList = remindersService.getDefaultReminderList() ?? availableLists.first
            }
        }
    }

    private func exportReminder() {
        guard let list = selectedList else { return }
        isExporting = true

        Task {
            do {
                let store = EKEventStore()
                if #available(iOS 17.0, *) {
                    _ = try await store.requestFullAccessToReminders()
                } else {
                    _ = try await store.requestAccess(to: .reminder)
                }

                // Re-fetch the calendar from the new store
                guard let targetList = store.calendars(for: .reminder).first(where: { $0.calendarIdentifier == list.calendarIdentifier }) else {
                    throw RemindersError.exportFailed("Could not find selected list")
                }

                let newReminder = EKReminder(eventStore: store)
                newReminder.calendar = targetList
                newReminder.title = reminderText.components(separatedBy: .newlines).first ?? reminderText

                if reminderText.contains("\n") {
                    newReminder.notes = reminderText
                }

                if let date = dueDate {
                    let calendar = Calendar.current
                    var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
                    components.timeZone = TimeZone.current
                    newReminder.dueDateComponents = components
                    newReminder.addAlarm(EKAlarm(absoluteDate: date))
                }

                try store.save(newReminder, commit: true)

                await MainActor.run {
                    isExporting = false
                    exportSuccess = true
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    ReminderDetailView(note: Note())
}
