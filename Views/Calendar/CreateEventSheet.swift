//
//  CreateEventSheet.swift
//  QuillStack
//
//  Created on 2025-12-18.
//

import SwiftUI
import EventKit
import CoreData

// MARK: - Create Event Sheet

struct CreateEventSheet: View {
    @ObservedObject var meeting: Meeting
    @Environment(\.dismiss) private var dismiss

    @State private var authorizationStatus: CalendarService.AuthorizationStatus = .notDetermined
    @State private var selectedCalendar: EKCalendar?
    @State private var availableCalendars: [EKCalendar] = []

    @State private var eventTitle: String = ""
    @State private var eventDate: Date = Date()
    @State private var eventDuration: Int = 60
    @State private var eventLocation: String = ""

    @State private var isCreating = false
    @State private var showSuccess = false
    @State private var errorMessage: String?

    private let durationOptions = [15, 30, 45, 60, 90, 120]

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
                        if showSuccess {
                            successView
                        } else {
                            createEventForm
                        }
                    }
                }
            }
            .navigationTitle("Add to Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.forestDark)
                }
            }
            .onAppear {
                checkAuthorization()
                initializeFromMeeting()
            }
        }
    }

    // MARK: - Request Access View

    private var requestAccessView: some View {
        VStack(spacing: 24) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 56))
                .foregroundColor(.forestDark)

            Text("Calendar Access Required")
                .font(.serifHeadline(20, weight: .semibold))
                .foregroundColor(.textDark)

            Text("QuillStack needs access to your Calendar to create events from meeting notes.")
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

            Text("Please enable Calendar access in Settings to create events.")
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

    // MARK: - Create Event Form

    private var createEventForm: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    // Calendar picker
                    calendarPickerSection

                    // Event details
                    eventDetailsSection

                    // Error message
                    if let error = errorMessage {
                        Text(error)
                            .font(.serifCaption(13, weight: .regular))
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                }
                .padding(20)
            }

            // Create button
            createButton
        }
    }

    private var calendarPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Calendar")
                .font(.serifCaption(13, weight: .semibold))
                .foregroundColor(.textMedium)

            Menu {
                ForEach(availableCalendars, id: \.calendarIdentifier) { calendar in
                    Button(action: { selectedCalendar = calendar }) {
                        HStack {
                            Circle()
                                .fill(Color(cgColor: calendar.cgColor))
                                .frame(width: 12, height: 12)
                            Text(calendar.title)
                            if selectedCalendar?.calendarIdentifier == calendar.calendarIdentifier {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    if let calendar = selectedCalendar {
                        Circle()
                            .fill(Color(cgColor: calendar.cgColor))
                            .frame(width: 16, height: 16)
                        Text(calendar.title)
                            .font(.serifBody(16, weight: .medium))
                            .foregroundColor(.textDark)
                    } else {
                        Text("Select a calendar")
                            .font(.serifBody(16, weight: .medium))
                            .foregroundColor(.textMedium)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.textMedium)
                }
                .padding(14)
                .background(Color.white)
                .cornerRadius(10)
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            }
        }
    }

    private var eventDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Event Details")
                .font(.serifCaption(13, weight: .semibold))
                .foregroundColor(.textMedium)

            VStack(spacing: 0) {
                // Title
                HStack {
                    Text("Title")
                        .font(.serifBody(14, weight: .medium))
                        .foregroundColor(.textMedium)
                        .frame(width: 70, alignment: .leading)
                    TextField("Event title", text: $eventTitle)
                        .font(.serifBody(16, weight: .regular))
                        .foregroundColor(.textDark)
                }
                .padding(14)

                Divider()

                // Date & Time
                HStack {
                    Text("When")
                        .font(.serifBody(14, weight: .medium))
                        .foregroundColor(.textMedium)
                        .frame(width: 70, alignment: .leading)
                    DatePicker("", selection: $eventDate, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                }
                .padding(14)

                Divider()

                // Duration
                HStack {
                    Text("Duration")
                        .font(.serifBody(14, weight: .medium))
                        .foregroundColor(.textMedium)
                        .frame(width: 70, alignment: .leading)

                    Picker("Duration", selection: $eventDuration) {
                        ForEach(durationOptions, id: \.self) { minutes in
                            Text(formatDuration(minutes)).tag(minutes)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.forestDark)
                }
                .padding(14)

                Divider()

                // Location
                HStack {
                    Text("Location")
                        .font(.serifBody(14, weight: .medium))
                        .foregroundColor(.textMedium)
                        .frame(width: 70, alignment: .leading)
                    TextField("Optional", text: $eventLocation)
                        .font(.serifBody(16, weight: .regular))
                        .foregroundColor(.textDark)
                }
                .padding(14)
            }
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)

            // Attendees preview
            if !meeting.attendeesList.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Attendees")
                        .font(.serifCaption(12, weight: .medium))
                        .foregroundColor(.textMedium)

                    Text(meeting.attendeesList.joined(separator: ", "))
                        .font(.serifCaption(13, weight: .regular))
                        .foregroundColor(.textDark)
                }
                .padding(.top, 8)
            }
        }
    }

    private var createButton: some View {
        VStack(spacing: 12) {
            Button(action: createEvent) {
                HStack(spacing: 8) {
                    if isCreating {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    Text(isCreating ? "Creating..." : "Add to Calendar")
                        .font(.serifBody(16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: canCreate ? [Color.badgeMeeting, Color.badgeMeeting.opacity(0.8)] : [Color.gray, Color.gray.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(12)
            }
            .disabled(!canCreate || isCreating)
        }
        .padding(20)
        .background(Color.creamLight)
        .overlay(
            Rectangle()
                .fill(Color.forestDark.opacity(0.1))
                .frame(height: 1),
            alignment: .top
        )
    }

    // MARK: - Success View

    private var successView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            Text("Event Created!")
                .font(.serifHeadline(22, weight: .semibold))
                .foregroundColor(.textDark)

            Text("The meeting has been added to your calendar.")
                .font(.serifBody(15, weight: .regular))
                .foregroundColor(.textMedium)
                .multilineTextAlignment(.center)

            Button(action: { dismiss() }) {
                Text("Done")
                    .font(.serifBody(16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.forestDark)
                    .cornerRadius(10)
            }
            .padding(.horizontal, 40)
            .padding(.top, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private var canCreate: Bool {
        selectedCalendar != nil && !eventTitle.isEmpty
    }

    private func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        } else if minutes == 60 {
            return "1 hour"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            if mins == 0 {
                return "\(hours) hour\(hours > 1 ? "s" : "")"
            } else {
                return "\(hours)h \(mins)m"
            }
        }
    }

    private func checkAuthorization() {
        authorizationStatus = CalendarService.shared.authorizationStatus
        if authorizationStatus == .authorized {
            loadCalendars()
        }
    }

    private func requestAccess() {
        Task {
            let granted = await CalendarService.shared.requestAccess()
            await MainActor.run {
                authorizationStatus = granted ? .authorized : .denied
                if granted {
                    loadCalendars()
                }
            }
        }
    }

    private func loadCalendars() {
        availableCalendars = CalendarService.shared.getCalendars()
        selectedCalendar = CalendarService.shared.getDefaultCalendar()
    }

    private func initializeFromMeeting() {
        eventTitle = meeting.title
        eventDate = meeting.meetingDate ?? Date()
        eventDuration = Int(meeting.duration)
    }

    private func createEvent() {
        guard let calendar = selectedCalendar else { return }

        isCreating = true
        errorMessage = nil

        Task {
            do {
                let notes = meeting.agenda ?? meeting.note?.content

                let eventId = try CalendarService.shared.createEvent(
                    title: eventTitle,
                    startDate: eventDate,
                    duration: eventDuration,
                    notes: notes,
                    attendees: meeting.attendeesList,
                    location: eventLocation.isEmpty ? nil : eventLocation,
                    calendar: calendar
                )

                // Save the event ID to the meeting
                meeting.calendarEventIdentifier = eventId
                try? CoreDataStack.shared.saveViewContext()

                await MainActor.run {
                    isCreating = false
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isCreating = false
                }
            }
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Preview

#Preview {
    CreateEventSheet(meeting: Meeting())
}
