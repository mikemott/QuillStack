//
//  EventReviewSheet.swift
//  QuillStack
//
//  Phase 3.4 - Calendar Action with Review Sheet
//  Review and edit event before saving to Calendar app.
//

import SwiftUI
import EventKit

struct EventReviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var eventDate: Date
    @State private var eventTime: Date
    @State private var isAllDay: Bool
    @State private var duration: Int // minutes
    @State private var location: String
    @State private var notes: String
    @State private var organizer: String
    @State private var contactInfo: String
    @State private var isRecurring: Bool
    @State private var recurrencePattern: String

    @State private var isSaving = false
    @State private var saveError: String?
    @State private var showingCalendarPicker = false
    @State private var selectedCalendar: EKCalendar?
    @State private var availableCalendars: [EKCalendar] = []

    private let calendarService = CalendarService.shared
    let onSave: (String) async throws -> Void // eventId
    let onCancel: () -> Void

    init(
        title: String,
        eventDate: Date,
        eventTime: Date,
        isAllDay: Bool,
        duration: Int,
        location: String,
        notes: String,
        organizer: String = "",
        contactInfo: String = "",
        isRecurring: Bool = false,
        recurrencePattern: String = "",
        onSave: @escaping (String) async throws -> Void,
        onCancel: @escaping () -> Void
    ) {
        self._title = State(initialValue: title)
        self._eventDate = State(initialValue: eventDate)
        self._eventTime = State(initialValue: eventTime)
        self._isAllDay = State(initialValue: isAllDay)
        self._duration = State(initialValue: duration)
        self._location = State(initialValue: location)
        self._notes = State(initialValue: notes)
        self._organizer = State(initialValue: organizer)
        self._contactInfo = State(initialValue: contactInfo)
        self._isRecurring = State(initialValue: isRecurring)
        self._recurrencePattern = State(initialValue: recurrencePattern)
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
            .navigationTitle("Review Event")
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
                    Button(action: { showingCalendarPicker = true }) {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Save")
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundColor(.badgeEvent)
                    .disabled(title.isEmpty || isSaving)
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
        .sheet(isPresented: $showingCalendarPicker) {
            calendarPickerSheet
        }
        .onAppear {
            loadCalendars()
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
                            colors: [Color.badgeEvent, Color.badgeEvent.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.white)
            }

            Text("Review and edit event details before saving")
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
            // Basic info section
            sectionCard(title: "Event Details") {
                VStack(spacing: 12) {
                    EventFieldRow(icon: "text.quote", label: "Title") {
                        TextField("Event title", text: $title)
                            .font(.serifBody(15, weight: .regular))
                            .foregroundColor(.textDark)
                    }

                    EventFieldRow(icon: "mappin.circle", label: "Location") {
                        TextField("Location (optional)", text: $location)
                            .font(.serifBody(15, weight: .regular))
                            .foregroundColor(.textDark)
                    }
                }
            }

            // Date/Time section
            sectionCard(title: "Date & Time") {
                VStack(spacing: 12) {
                    EventFieldRow(icon: "calendar", label: "Date") {
                        DatePicker("", selection: $eventDate, displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                    }

                    if !isAllDay {
                        EventFieldRow(icon: "clock", label: "Time") {
                            DatePicker("", selection: $eventTime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .datePickerStyle(.compact)
                        }

                        EventFieldRow(icon: "hourglass", label: "Duration") {
                            Menu {
                                Button("15 min") { duration = 15 }
                                Button("30 min") { duration = 30 }
                                Button("1 hour") { duration = 60 }
                                Button("2 hours") { duration = 120 }
                                Button("3 hours") { duration = 180 }
                            } label: {
                                Text(durationText)
                                    .font(.serifBody(15, weight: .regular))
                                    .foregroundColor(.badgeEvent)
                            }
                        }
                    }

                    EventFieldRow(icon: "sun.horizon", label: "All-day") {
                        Toggle("", isOn: $isAllDay)
                            .labelsHidden()
                            .tint(.badgeEvent)
                    }
                }
            }

            // Additional info section
            sectionCard(title: "Additional Information") {
                VStack(spacing: 12) {
                    if !organizer.isEmpty {
                        EventFieldRow(icon: "person.circle", label: "Organizer") {
                            TextField("Organizer", text: $organizer)
                                .font(.serifBody(15, weight: .regular))
                                .foregroundColor(.textDark)
                        }
                    }

                    if !contactInfo.isEmpty {
                        EventFieldRow(icon: "phone.circle", label: "Contact") {
                            TextField("Contact info", text: $contactInfo)
                                .font(.serifBody(15, weight: .regular))
                                .foregroundColor(.textDark)
                        }
                    }

                    if isRecurring {
                        EventFieldRow(icon: "repeat", label: "Repeats") {
                            TextField("Recurrence pattern", text: $recurrencePattern)
                                .font(.serifBody(15, weight: .regular))
                                .foregroundColor(.textDark)
                        }
                    }
                }
            }

            // Notes section
            sectionCard(title: "Notes") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Image(systemName: "note.text")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.badgeEvent)
                            .frame(width: 24)

                        Text("Description")
                            .font(.serifCaption(11, weight: .medium))
                            .foregroundColor(.textMedium)
                    }

                    TextEditor(text: $notes)
                        .font(.serifBody(15, weight: .regular))
                        .foregroundColor(.textDark)
                        .frame(minHeight: 80)
                        .scrollContentBackground(.hidden)
                }
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

    // MARK: - Calendar Picker Sheet

    private var calendarPickerSheet: some View {
        NavigationStack {
            List(availableCalendars, id: \.calendarIdentifier) { calendar in
                Button(action: {
                    selectedCalendar = calendar
                    handleSave(in: calendar)
                }) {
                    HStack {
                        Circle()
                            .fill(Color(cgColor: calendar.cgColor))
                            .frame(width: 12, height: 12)
                        Text(calendar.title)
                            .font(.serifBody(16, weight: .regular))
                            .foregroundColor(.textDark)
                        Spacer()
                        if calendar == calendarService.getDefaultCalendar() {
                            Text("Default")
                                .font(.serifCaption(12, weight: .medium))
                                .foregroundColor(.textMedium)
                        }
                    }
                }
            }
            .navigationTitle("Choose Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingCalendarPicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Helpers

    private var durationText: String {
        if duration < 60 {
            return "\(duration) min"
        } else if duration == 60 {
            return "1 hour"
        } else {
            return "\(duration / 60) hours"
        }
    }

    private func loadCalendars() {
        Task {
            let status = calendarService.authorizationStatus
            if status == .notDetermined {
                let granted = await calendarService.requestAccess()
                if !granted {
                    await MainActor.run {
                        saveError = "Calendar access is required to create events."
                    }
                    return
                }
            } else if status == .denied || status == .restricted {
                await MainActor.run {
                    saveError = "Calendar access denied. Please enable it in Settings."
                }
                return
            }

            await MainActor.run {
                availableCalendars = calendarService.getCalendars().filter { $0.allowsContentModifications }
                selectedCalendar = calendarService.getDefaultCalendar()
            }
        }
    }

    // MARK: - Actions

    private func handleSave(in calendar: EKCalendar) {
        guard !title.isEmpty else {
            saveError = "Please enter an event title."
            showingCalendarPicker = false
            return
        }

        Task {
            isSaving = true
            saveError = nil

            do {
                // Combine date and time
                let combinedDate: Date
                if !isAllDay {
                    let cal = Calendar.current
                    var components = cal.dateComponents([.year, .month, .day], from: eventDate)
                    let timeComponents = cal.dateComponents([.hour, .minute], from: eventTime)
                    components.hour = timeComponents.hour
                    components.minute = timeComponents.minute
                    combinedDate = cal.date(from: components) ?? eventDate
                } else {
                    combinedDate = eventDate
                }

                // Build notes from all additional fields
                var notesParts: [String] = []
                if !notes.isEmpty {
                    notesParts.append(notes)
                }
                if !organizer.isEmpty {
                    notesParts.append("Organizer: \(organizer)")
                }
                if !contactInfo.isEmpty {
                    notesParts.append("Contact: \(contactInfo)")
                }

                let eventNotes = notesParts.isEmpty ? nil : notesParts.joined(separator: "\n\n")

                // Create event
                let eventId = try calendarService.createEvent(
                    title: title,
                    startDate: combinedDate,
                    duration: isAllDay ? 1440 : duration, // All day = 24 hours
                    notes: eventNotes,
                    attendees: nil,
                    location: location.isEmpty ? nil : location,
                    calendar: calendar
                )

                // Add recurrence rule if recurring
                if isRecurring, !recurrencePattern.isEmpty {
                    if let event = calendarService.getEvent(identifier: eventId),
                       let recurrenceRule = parseRecurrencePattern(recurrencePattern) {
                        event.addRecurrenceRule(recurrenceRule)
                        try calendarService.updateEvent(event)
                    }
                }

                // Call onSave with event ID
                try await onSave(eventId)

                // Only dismiss on success
                await MainActor.run {
                    isSaving = false
                    showingCalendarPicker = false
                    dismiss()
                }
            } catch {
                // Show error and keep sheet open for user to retry or cancel
                await MainActor.run {
                    isSaving = false
                    showingCalendarPicker = false
                    saveError = error.localizedDescription
                }
            }
        }
    }

    /// Parse recurrence pattern string into EKRecurrenceRule
    private func parseRecurrencePattern(_ pattern: String) -> EKRecurrenceRule? {
        let lowercased = pattern.lowercased().trimmingCharacters(in: .whitespaces)

        let frequency: EKRecurrenceFrequency
        switch lowercased {
        case "daily", "every day":
            frequency = .daily
        case "weekly", "every week":
            frequency = .weekly
        case "monthly", "every month":
            frequency = .monthly
        case "yearly", "annually", "every year":
            frequency = .yearly
        default:
            return nil
        }

        return EKRecurrenceRule(
            recurrenceWith: frequency,
            interval: 1,
            end: nil
        )
    }
}

// MARK: - Event Field Row

struct EventFieldRow<Content: View>: View {
    let icon: String
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.badgeEvent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.serifCaption(11, weight: .medium))
                    .foregroundColor(.textMedium)

                content()
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    EventReviewSheet(
        title: "Team Meeting",
        eventDate: Date(),
        eventTime: Date(),
        isAllDay: false,
        duration: 60,
        location: "Conference Room A",
        notes: "Discuss Q1 planning and review project status.",
        onSave: { _ in
            try await Task.sleep(nanoseconds: 500_000_000)
        },
        onCancel: { }
    )
}
