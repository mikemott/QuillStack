//
//  EventPickerView.swift
//  QuillStack
//
//  Created on 2025-12-18.
//

import SwiftUI
import EventKit
import CoreData

// MARK: - Event Picker View

struct EventPickerView: View {
    @ObservedObject var meeting: Meeting
    @Environment(\.dismiss) private var dismiss

    @State private var authorizationStatus: CalendarService.AuthorizationStatus = .notDetermined
    @State private var events: [EKEvent] = []
    @State private var searchText: String = ""
    @State private var selectedEvent: EKEvent?
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.creamLight.ignoresSafeArea()

                Group {
                    switch authorizationStatus {
                    case .notDetermined:
                        requestAccessView
                    case .denied, .restricted:
                        accessDeniedView
                    case .authorized:
                        eventListView
                    }
                }
            }
            .navigationTitle("Link to Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.forestDark)
                }

                if meeting.calendarEventIdentifier != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Unlink") {
                            unlinkEvent()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .onAppear {
                checkAuthorization()
            }
        }
    }

    // MARK: - Request Access View

    private var requestAccessView: some View {
        VStack(spacing: 24) {
            Image(systemName: "calendar")
                .font(.system(size: 56))
                .foregroundColor(.forestDark)

            Text("Calendar Access Required")
                .font(.serifHeadline(20, weight: .semibold))
                .foregroundColor(.textDark)

            Text("QuillStack needs access to your Calendar to link meeting notes to events.")
                .font(.serifBody(15, weight: .regular))
                .foregroundColor(.textMedium)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button(action: requestAccess) {
                Text("Grant Access")
                    .font(.serifBody(16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.forestDark)
                    .cornerRadius(10)
            }
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Access Denied View

    private var accessDeniedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.circle")
                .font(.system(size: 56))
                .foregroundColor(.orange)

            Text("Access Denied")
                .font(.serifHeadline(20, weight: .semibold))
                .foregroundColor(.textDark)

            Text("Please enable Calendar access in Settings to link events.")
                .font(.serifBody(15, weight: .regular))
                .foregroundColor(.textMedium)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button(action: openSettings) {
                Text("Open Settings")
                    .font(.serifBody(16, weight: .semibold))
                    .foregroundColor(.forestDark)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Event List View

    private var eventListView: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.textMedium)
                TextField("Search events...", text: $searchText)
                    .font(.serifBody(16, weight: .regular))
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.textLight)
                    }
                }
            }
            .padding(12)
            .background(Color.white)
            .cornerRadius(10)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if isLoading {
                Spacer()
                ProgressView()
                    .scaleEffect(1.2)
                Spacer()
            } else if filteredEvents.isEmpty {
                emptyStateView
            } else {
                eventsList
            }
        }
    }

    private var filteredEvents: [EKEvent] {
        if searchText.isEmpty {
            return events
        }
        return events.filter { event in
            event.title.localizedCaseInsensitiveContains(searchText) ||
            (event.location?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    private var eventsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredEvents, id: \.eventIdentifier) { event in
                    EventRow(
                        event: event,
                        isLinked: meeting.calendarEventIdentifier == event.eventIdentifier,
                        onTap: { linkEvent(event) }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(.textLight)

            Text("No upcoming events")
                .font(.serifHeadline(18, weight: .semibold))
                .foregroundColor(.textDark)

            Text("There are no events in the next 30 days to link to.")
                .font(.serifBody(14, weight: .regular))
                .foregroundColor(.textMedium)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }

    // MARK: - Helpers

    private func checkAuthorization() {
        authorizationStatus = CalendarService.shared.authorizationStatus
        if authorizationStatus == .authorized {
            loadEvents()
        }
    }

    private func requestAccess() {
        Task {
            let granted = await CalendarService.shared.requestAccess()
            await MainActor.run {
                authorizationStatus = granted ? .authorized : .denied
                if granted {
                    loadEvents()
                }
            }
        }
    }

    private func loadEvents() {
        isLoading = true
        events = CalendarService.shared.fetchUpcomingEvents()
        isLoading = false
    }

    private func linkEvent(_ event: EKEvent) {
        // Store the link
        meeting.calendarEventIdentifier = event.eventIdentifier

        // Update meeting data from event if not already set
        if meeting.title.isEmpty {
            meeting.title = event.title
        }
        if meeting.meetingDate == nil {
            meeting.meetingDate = event.startDate
        }

        // Update the calendar event with meeting notes and action items
        updateCalendarEvent(event)

        try? CoreDataStack.shared.saveViewContext()
        dismiss()
    }

    /// Updates the linked calendar event with meeting notes, agenda, and action items
    private func updateCalendarEvent(_ event: EKEvent) {
        // Build notes to append
        var meetingNotes: [String] = []

        if let agenda = meeting.agenda, !agenda.isEmpty {
            meetingNotes.append("📋 Agenda:\n\(agenda)")
        }

        if let actionItems = meeting.actionItems, !actionItems.isEmpty {
            let formattedItems = actionItems
                .components(separatedBy: "\n")
                .filter { !$0.isEmpty }
                .map { "• \($0)" }
                .joined(separator: "\n")
            meetingNotes.append("✅ Action Items:\n\(formattedItems)")
        }

        if !meeting.attendeesList.isEmpty {
            meetingNotes.append("👥 Attendees: \(meeting.attendeesList.joined(separator: ", "))")
        }

        // If we have meeting notes to add
        if !meetingNotes.isEmpty {
            let newNotes = meetingNotes.joined(separator: "\n\n")

            // Append to existing notes or set new notes
            if let existingNotes = event.notes, !existingNotes.isEmpty {
                event.notes = existingNotes + "\n\n---\n📝 Meeting Notes:\n\n" + newNotes
            } else {
                event.notes = newNotes
            }

            // Save the updated event
            do {
                try CalendarService.shared.updateEvent(event)
            } catch {
                print("Failed to update calendar event: \(error)")
            }
        }
    }

    private func unlinkEvent() {
        meeting.calendarEventIdentifier = nil
        try? CoreDataStack.shared.saveViewContext()
        dismiss()
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Event Row

struct EventRow: View {
    let event: EKEvent
    let isLinked: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Calendar color indicator
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(cgColor: event.calendar.cgColor))
                    .frame(width: 4, height: 50)

                // Event details
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.serifBody(15, weight: .medium))
                        .foregroundColor(.textDark)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        // Date
                        Text(formattedDate)
                            .font(.serifCaption(12, weight: .regular))
                            .foregroundColor(.textMedium)

                        // Time
                        Text(formattedTime)
                            .font(.serifCaption(12, weight: .regular))
                            .foregroundColor(.textMedium)
                    }

                    // Location
                    if let location = event.location, !location.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin")
                                .font(.system(size: 10))
                            Text(location)
                                .lineLimit(1)
                        }
                        .font(.serifCaption(11, weight: .regular))
                        .foregroundColor(.textLight)
                    }
                }

                Spacer()

                // Linked indicator
                if isLinked {
                    Image(systemName: "link.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.badgeMeeting)
                }
            }
            .padding(14)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isLinked ? Color.badgeMeeting : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current

        if calendar.isDateInToday(event.startDate) {
            return "Today"
        } else if calendar.isDateInTomorrow(event.startDate) {
            return "Tomorrow"
        } else {
            formatter.dateFormat = "EEE, MMM d"
            return formatter.string(from: event.startDate)
        }
    }

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: event.startDate)
    }
}

// MARK: - Preview

#Preview {
    EventPickerView(meeting: Meeting())
}
