//
//  EventDetailView.swift
//  QuillStack
//
//  Created on 2025-12-31.
//

import SwiftUI
import EventKit

struct EventDetailView: View {
    @ObservedObject var note: Note
    @State private var eventTitle: String = ""
    @State private var eventDate: Date = Date()
    @State private var eventTime: Date = Date()
    @State private var hasTime: Bool = true
    @State private var duration: Int = 60 // minutes
    @State private var location: String = ""
    @State private var eventNotes: String = ""
    @State private var showingCalendarPicker = false
    @State private var showingCalendarError = false
    @State private var calendarErrorMessage = ""
    @State private var selectedCalendar: EKCalendar?
    @State private var availableCalendars: [EKCalendar] = []
    @State private var eventCreated = false
    @State private var createdEventId: String?
    @ObservedObject private var settings = SettingsManager.shared
    @Environment(\.dismiss) private var dismiss

    private let calendarService = CalendarService.shared

    var body: some View {
        ZStack {
            Color.creamLight.ignoresSafeArea()

            VStack(spacing: 0) {
                slimHeader
                ScrollView {
                    VStack(spacing: 0) {
                        // Title field
                        eventField(label: "What:", placeholder: "Event title") {
                            TextField("Meeting, appointment, etc.", text: $eventTitle)
                                .font(.serifBody(16, weight: .regular))
                                .foregroundColor(.textDark)
                        }

                        Divider().background(Color.forestDark.opacity(0.1))

                        // Date picker
                        eventField(label: "When:", placeholder: "") {
                            VStack(alignment: .leading, spacing: 8) {
                                DatePicker("Date", selection: $eventDate, displayedComponents: .date)
                                    .labelsHidden()
                                    .datePickerStyle(.compact)

                                if hasTime {
                                    HStack {
                                        DatePicker("Time", selection: $eventTime, displayedComponents: .hourAndMinute)
                                            .labelsHidden()
                                            .datePickerStyle(.compact)

                                        Spacer()

                                        // Duration picker
                                        Menu {
                                            Button("15 min") { duration = 15 }
                                            Button("30 min") { duration = 30 }
                                            Button("1 hour") { duration = 60 }
                                            Button("2 hours") { duration = 120 }
                                        } label: {
                                            Text("\(durationText)")
                                                .font(.serifCaption(13, weight: .medium))
                                                .foregroundColor(.badgeEvent)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.badgeEvent.opacity(0.1))
                                                .cornerRadius(4)
                                        }
                                    }
                                }

                                Toggle("All-day event", isOn: Binding(
                                    get: { !hasTime },
                                    set: { hasTime = !$0 }
                                ))
                                .font(.serifCaption(14, weight: .regular))
                                .foregroundColor(.textMedium)
                                .tint(.badgeEvent)
                            }
                        }

                        Divider().background(Color.forestDark.opacity(0.1))

                        // Location field
                        eventField(label: "Where:", placeholder: "Location (optional)") {
                            TextField("Address or location name", text: $location)
                                .font(.serifBody(16, weight: .regular))
                                .foregroundColor(.textDark)
                        }

                        Divider().background(Color.forestDark.opacity(0.1))

                        // Notes
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes:")
                                .font(.serifBody(14, weight: .medium))
                                .foregroundColor(.textMedium)

                            TextEditor(text: $eventNotes)
                                .font(.serifBody(15, weight: .regular))
                                .foregroundColor(.textDark)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 100)
                        }
                        .padding(16)
                    }
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
        .onAppear {
            parseEventContent()
            loadCalendars()
        }
        .onChange(of: eventTitle) { _, _ in saveChanges() }
        .onChange(of: eventDate) { _, _ in saveChanges() }
        .onChange(of: eventTime) { _, _ in saveChanges() }
        .onChange(of: hasTime) { _, _ in saveChanges() }
        .onChange(of: duration) { _, _ in saveChanges() }
        .onChange(of: location) { _, _ in saveChanges() }
        .onChange(of: eventNotes) { _, _ in saveChanges() }
        .sheet(isPresented: $showingCalendarPicker) {
            calendarPickerSheet
        }
        .alert("Calendar Error", isPresented: $showingCalendarError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(calendarErrorMessage)
        }
    }

    // MARK: - Header

    private var slimHeader: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.forestLight)
                }

                Text("New Event")
                    .font(.serifBody(17, weight: .semibold))
                    .foregroundColor(.forestLight)
                    .lineLimit(1)

                Spacer()

                // Badge
                HStack(spacing: 4) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 10, weight: .bold))
                    Text("EVENT")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.5)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    LinearGradient(
                        colors: [Color.badgeEvent, Color.badgeEvent.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(4)
                .shadow(color: Color.badgeEvent.opacity(0.3), radius: 2, x: 0, y: 1)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)

            // Date row
            HStack(spacing: 12) {
                Text(formattedDate)
                    .font(.serifCaption(12, weight: .regular))
                    .foregroundColor(.textLight.opacity(0.8))

                if eventCreated {
                    Text("Added to Calendar")
                        .font(.serifCaption(12, weight: .medium))
                        .foregroundColor(.green.opacity(0.9))
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
        .background(
            LinearGradient(
                colors: [Color.forestMedium, Color.forestDark],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        )
    }

    // MARK: - Event Field

    private func eventField<Content: View>(label: String, placeholder: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.serifBody(14, weight: .medium))
                .foregroundColor(.textMedium)
                .frame(width: 55, alignment: .leading)

            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 20) {
            Spacer()

            // Add to Calendar button
            Button(action: { showingCalendarPicker = true }) {
                HStack(spacing: 8) {
                    Image(systemName: eventCreated ? "checkmark.circle.fill" : "calendar.badge.plus")
                        .font(.system(size: 16, weight: .semibold))
                    Text(eventCreated ? "Added" : "Add to Calendar")
                        .font(.serifBody(15, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: eventCreated
                            ? [Color.green, Color.green.opacity(0.8)]
                            : [Color.badgeEvent, Color.badgeEvent.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(10)
            }
            .disabled(eventTitle.isEmpty)
            .opacity(eventTitle.isEmpty ? 0.5 : 1)
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

    // MARK: - Calendar Picker Sheet

    private var calendarPickerSheet: some View {
        NavigationStack {
            List(availableCalendars, id: \.calendarIdentifier) { calendar in
                Button(action: {
                    selectedCalendar = calendar
                    createCalendarEvent(in: calendar)
                    showingCalendarPicker = false
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

    private var formattedDate: String {
        note.createdAt.formattedForNotes()
    }

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
                    calendarErrorMessage = "Calendar access is required to create events."
                    showingCalendarError = true
                    return
                }
            } else if status == .denied || status == .restricted {
                calendarErrorMessage = "Please enable Calendar access in Settings."
                showingCalendarError = true
                return
            }

            await MainActor.run {
                availableCalendars = calendarService.getCalendars().filter { $0.allowsContentModifications }
                selectedCalendar = calendarService.getDefaultCalendar()
            }
        }
    }

    private func parseEventContent() {
        let classifier = TextClassifier()
        let content: String
        if let extracted = classifier.extractTriggerTag(from: note.content) {
            content = extracted.cleanedContent
        } else {
            content = note.content
        }

        let lines = content.components(separatedBy: .newlines)
        var notesLines: [String] = []
        var foundStructuredField = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let lowercased = trimmed.lowercased()

            // Try to extract title (first non-empty line or "what:" field)
            if lowercased.hasPrefix("what:") || lowercased.hasPrefix("title:") {
                let colonIndex = trimmed.firstIndex(of: ":")!
                eventTitle = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                foundStructuredField = true
            }
            // Try to extract location
            else if lowercased.hasPrefix("where:") || lowercased.hasPrefix("location:") || lowercased.hasPrefix("at:") {
                let colonIndex = trimmed.firstIndex(of: ":")!
                location = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                foundStructuredField = true
            }
            // Try to extract date/time with natural language
            else if lowercased.hasPrefix("when:") || lowercased.hasPrefix("date:") || lowercased.hasPrefix("time:") {
                let colonIndex = trimmed.firstIndex(of: ":")!
                let dateString = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                parseNaturalDate(dateString)
                foundStructuredField = true
            }
            // Everything else goes to notes
            else if !trimmed.isEmpty {
                if !foundStructuredField && eventTitle.isEmpty {
                    // First line becomes title if no explicit title
                    eventTitle = trimmed
                } else {
                    notesLines.append(trimmed)
                }
            }
        }

        eventNotes = notesLines.joined(separator: "\n")
    }

    private func parseNaturalDate(_ dateString: String) {
        let lowercased = dateString.lowercased()

        // Simple natural language parsing
        let calendar = Calendar.current

        if lowercased.contains("today") {
            eventDate = Date()
        } else if lowercased.contains("tomorrow") {
            eventDate = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        } else if lowercased.contains("next week") {
            eventDate = calendar.date(byAdding: .weekOfYear, value: 1, to: Date()) ?? Date()
        }

        // Try to parse time patterns like "3pm", "3:00 PM", "15:00"
        let timePatterns = [
            #"(\d{1,2}):(\d{2})\s*(am|pm)?"#,
            #"(\d{1,2})\s*(am|pm)"#
        ]

        for pattern in timePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: dateString, options: [], range: NSRange(dateString.startIndex..., in: dateString)) {
                var hour = 0
                var minute = 0

                if let hourRange = Range(match.range(at: 1), in: dateString) {
                    hour = Int(dateString[hourRange]) ?? 0
                }
                if match.numberOfRanges > 2, let minuteRange = Range(match.range(at: 2), in: dateString),
                   !dateString[minuteRange].lowercased().contains("am") && !dateString[minuteRange].lowercased().contains("pm") {
                    minute = Int(dateString[minuteRange]) ?? 0
                }

                // Check for AM/PM
                if lowercased.contains("pm") && hour < 12 {
                    hour += 12
                } else if lowercased.contains("am") && hour == 12 {
                    hour = 0
                }

                var components = calendar.dateComponents([.year, .month, .day], from: eventDate)
                components.hour = hour
                components.minute = minute
                if let newTime = calendar.date(from: components) {
                    eventTime = newTime
                    hasTime = true
                }
                break
            }
        }
    }

    private func saveChanges() {
        var lines: [String] = ["#event#"]

        if !eventTitle.isEmpty {
            lines.append("What: \(eventTitle)")
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium

        if hasTime {
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            lines.append("When: \(dateFormatter.string(from: eventDate)) at \(timeFormatter.string(from: eventTime))")
        } else {
            lines.append("When: \(dateFormatter.string(from: eventDate)) (all day)")
        }

        if !location.isEmpty {
            lines.append("Where: \(location)")
        }

        if !eventNotes.isEmpty {
            lines.append("")
            lines.append(eventNotes)
        }

        note.content = lines.joined(separator: "\n")
        note.updatedAt = Date()
        try? CoreDataStack.shared.saveViewContext()
    }

    private func createCalendarEvent(in calendar: EKCalendar) {
        // Combine date and time
        let combinedDate: Date
        if hasTime {
            let cal = Calendar.current
            var components = cal.dateComponents([.year, .month, .day], from: eventDate)
            let timeComponents = cal.dateComponents([.hour, .minute], from: eventTime)
            components.hour = timeComponents.hour
            components.minute = timeComponents.minute
            combinedDate = cal.date(from: components) ?? eventDate
        } else {
            combinedDate = eventDate
        }

        do {
            let eventId = try calendarService.createEvent(
                title: eventTitle,
                startDate: combinedDate,
                duration: hasTime ? duration : 1440, // All day = 24 hours
                notes: eventNotes.isEmpty ? nil : eventNotes,
                attendees: nil,
                location: location.isEmpty ? nil : location,
                calendar: calendar
            )
            createdEventId = eventId
            eventCreated = true

            // Store event ID in note summary for reference
            note.summary = eventId
            try? CoreDataStack.shared.saveViewContext()
        } catch {
            calendarErrorMessage = error.localizedDescription
            showingCalendarError = true
        }
    }
}

#Preview {
    EventDetailView(note: Note())
}
