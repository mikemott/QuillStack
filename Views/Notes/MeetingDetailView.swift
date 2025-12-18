//
//  MeetingDetailView.swift
//  QuillStack
//
//  Created on 2025-12-16.
//

import SwiftUI
import CoreData
import EventKit
import EventKitUI

// Keep event store alive as a singleton
final class CalendarManager: @unchecked Sendable {
    static let shared = CalendarManager()
    private let eventStore = EKEventStore()

    private init() {}

    func requestAccess() async throws -> Bool {
        if #available(iOS 17.0, *) {
            return try await eventStore.requestFullAccessToEvents()
        } else {
            return try await eventStore.requestAccess(to: .event)
        }
    }

    func createEvent(details: MeetingDetails) throws -> String {
        let event = EKEvent(eventStore: eventStore)
        event.title = details.subject
        event.notes = details.notes

        // Set location if available
        if let location = details.location {
            event.location = location
        }

        // Set date/time
        var startDate: Date
        if let parsedDate = details.parsedDate {
            startDate = parsedDate

            // Try to parse time with multiple formats
            if let timeStr = details.time {
                let timeFormats = ["h:mm a", "H:mm", "h:mma", "ha", "h a", "HH:mm"]
                var timeParsed = false

                for format in timeFormats {
                    let timeFormatter = DateFormatter()
                    timeFormatter.dateFormat = format
                    timeFormatter.locale = Locale(identifier: "en_US_POSIX")

                    if let time = timeFormatter.date(from: timeStr) {
                        let calendar = Calendar.current
                        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
                        if let hour = timeComponents.hour {
                            startDate = calendar.date(bySettingHour: hour,
                                                     minute: timeComponents.minute ?? 0,
                                                     second: 0,
                                                     of: parsedDate) ?? parsedDate
                            timeParsed = true
                            print("⏰ Parsed time '\(timeStr)' with format '\(format)' -> hour: \(hour)")
                            break
                        }
                    }
                }

                if !timeParsed {
                    print("⚠️ Could not parse time: '\(timeStr)'")
                }
            }
        } else {
            // Default to tomorrow at 9am if no date specified
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
            startDate = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow)!
        }

        event.startDate = startDate
        event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: startDate)!

        // Add attendees to notes
        if !details.attendees.isEmpty {
            let attendeeList = details.attendees.joined(separator: ", ")
            event.notes = "Attendees: \(attendeeList)\n\n\(details.notes)"
        }

        // Get calendar
        let allCalendars = eventStore.calendars(for: .event)
        print("📅 Available calendars: \(allCalendars.map { "\($0.title) (writable: \($0.allowsContentModifications))" })")

        guard let calendar = eventStore.defaultCalendarForNewEvents ??
              allCalendars.first(where: { $0.allowsContentModifications }) else {
            throw NSError(domain: "CalendarManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "No writable calendar found"])
        }

        print("📅 Using calendar: \(calendar.title)")
        event.calendar = calendar

        // Save with commit
        try eventStore.save(event, span: .thisEvent, commit: true)

        // Force refresh calendar sources
        eventStore.refreshSourcesIfNecessary()

        // Verify the event was saved
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        print("✅ Calendar event saved:")
        print("   Title: \(event.title ?? "nil")")
        print("   Calendar: \(calendar.title)")
        print("   Start: \(dateFormatter.string(from: event.startDate))")
        print("   End: \(dateFormatter.string(from: event.endDate))")
        print("   Event ID: \(event.eventIdentifier ?? "nil")")

        // Verify by fetching the event back
        if let eventId = event.eventIdentifier,
           let fetchedEvent = eventStore.event(withIdentifier: eventId) {
            print("✅ Verified: Event exists in calendar with title '\(fetchedEvent.title ?? "nil")'")
        } else {
            print("⚠️ Warning: Could not fetch event back from calendar")
        }

        return calendar.title
    }
}

struct MeetingDetailView: View {
    @ObservedObject var note: Note
    @State private var meetingDetails: MeetingDetails?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingCalendarPicker = false
    @State private var showingCalendarError = false
    @State private var calendarErrorMessage = ""
    @State private var showingSuccessToast = false
    @ObservedObject private var settings = SettingsManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.creamLight.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                slimHeader

                // Content
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else if let details = meetingDetails {
                    meetingContent(details)
                }

                // Bottom bar
                if meetingDetails != nil {
                    bottomBar
                }
            }

            // Success toast
            if showingSuccessToast {
                VStack {
                    Spacer()
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.green)
                        Text("Added to Calendar")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.textDark)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                    )
                    .padding(.bottom, 100)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            extractMeetingDetails()
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

                Text("Meeting")
                    .font(.serifBody(17, weight: .semibold))
                    .foregroundColor(.forestLight)
                    .lineLimit(1)

                Spacer()

                // Badge
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10, weight: .bold))
                    Text("MEETING")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.5)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    LinearGradient(
                        colors: [Color.badgeMeeting, Color.badgeMeeting.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(4)
                .shadow(color: Color.badgeMeeting.opacity(0.3), radius: 2, x: 0, y: 1)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)

            // Date row
            HStack(spacing: 12) {
                Text(formattedNoteDate)
                    .font(.serifCaption(12, weight: .regular))
                    .foregroundColor(.textLight.opacity(0.8))

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

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text("Extracting meeting details...")
                .font(.serifBody(15, weight: .regular))
                .foregroundColor(.textMedium)
            Spacer()
        }
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            Text(message)
                .font(.serifBody(15, weight: .regular))
                .foregroundColor(.textMedium)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button("Show Raw Note") {
                // Fall back to showing raw content
                meetingDetails = MeetingDetails(
                    subject: "Meeting Notes",
                    attendees: [],
                    date: nil,
                    time: nil,
                    location: nil,
                    notes: note.content
                )
                errorMessage = nil
            }
            .font(.serifBody(15, weight: .medium))
            .foregroundColor(.forestDark)

            Spacer()
        }
    }

    // MARK: - Meeting Content

    private func meetingContent(_ details: MeetingDetails) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Subject
                VStack(alignment: .leading, spacing: 8) {
                    Text(details.subject)
                        .font(.serifHeadline(24, weight: .bold))
                        .foregroundColor(.textDark)
                }
                .padding(16)

                Divider()
                    .background(Color.forestDark.opacity(0.1))

                // Date & Time row
                if details.date != nil || details.time != nil {
                    HStack(spacing: 16) {
                        if let date = details.date {
                            HStack(spacing: 6) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 14))
                                    .foregroundColor(.badgeMeeting)
                                Text(date)
                                    .font(.serifBody(15, weight: .medium))
                                    .foregroundColor(.textDark)
                            }
                        }

                        if let time = details.time {
                            HStack(spacing: 6) {
                                Image(systemName: "clock")
                                    .font(.system(size: 14))
                                    .foregroundColor(.badgeMeeting)
                                Text(time)
                                    .font(.serifBody(15, weight: .medium))
                                    .foregroundColor(.textDark)
                            }
                        }

                        Spacer()
                    }
                    .padding(16)

                    Divider()
                        .background(Color.forestDark.opacity(0.1))
                }

                // Location row
                if let location = details.location, !location.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "location")
                            .font(.system(size: 14))
                            .foregroundColor(.badgeMeeting)
                        Text(location)
                            .font(.serifBody(15, weight: .medium))
                            .foregroundColor(.textDark)
                        Spacer()
                    }
                    .padding(16)

                    Divider()
                        .background(Color.forestDark.opacity(0.1))
                }

                // Attendees
                if !details.attendees.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "person.2")
                                .font(.system(size: 14))
                                .foregroundColor(.badgeMeeting)
                            Text("Attendees")
                                .font(.serifBody(14, weight: .medium))
                                .foregroundColor(.textMedium)
                        }

                        // Attendee chips
                        AttendeeFlowLayout(spacing: 8) {
                            ForEach(details.attendees, id: \.self) { attendee in
                                AttendeeChip(name: attendee)
                            }
                        }
                    }
                    .padding(16)

                    Divider()
                        .background(Color.forestDark.opacity(0.1))
                }

                // Notes section
                if !details.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "note.text")
                                .font(.system(size: 14))
                                .foregroundColor(.badgeMeeting)
                            Text("Notes")
                                .font(.serifBody(14, weight: .medium))
                                .foregroundColor(.textMedium)
                        }

                        Text(details.notes)
                            .font(.serifBody(16, weight: .regular))
                            .foregroundColor(.textDark)
                            .lineSpacing(6)
                    }
                    .padding(16)
                }
            }
        }
        .background(
            LinearGradient(
                colors: [Color.paperBeige.opacity(0.98), Color.paperTan.opacity(0.98)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 16) {
            Button(action: copyContent) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.textDark)
            }

            Spacer()

            // Add to Calendar button
            Button(action: addToCalendar) {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Add to Calendar")
                        .font(.serifBody(15, weight: .semibold))
                }
                .foregroundColor(.forestLight)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [Color.badgeMeeting, Color.badgeMeeting.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(8)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.creamLight)
        .overlay(
            Rectangle()
                .fill(Color.forestDark.opacity(0.1))
                .frame(height: 1),
            alignment: .top
        )
    }

    // MARK: - Helpers

    private var formattedNoteDate: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(note.createdAt) {
            return "Captured today"
        } else if calendar.isDateInYesterday(note.createdAt) {
            return "Captured yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return "Captured \(formatter.string(from: note.createdAt))"
        }
    }

    private func extractMeetingDetails() {
        guard settings.hasAPIKey else {
            errorMessage = "No API key configured. Add your Claude API key in Settings to extract meeting details."
            isLoading = false
            return
        }

        Task {
            do {
                let details = try await LLMService.shared.extractMeetingDetails(from: note.content)
                await MainActor.run {
                    self.meetingDetails = details
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    private func addToCalendar() {
        guard let details = meetingDetails else { return }

        Task {
            do {
                // Request calendar access
                let granted = try await CalendarManager.shared.requestAccess()

                guard granted else {
                    calendarErrorMessage = "Calendar access denied. Please enable calendar access in Settings."
                    showingCalendarError = true
                    return
                }

                // Create and save the event
                let calendarName = try CalendarManager.shared.createEvent(details: details)

                withAnimation {
                    showingSuccessToast = true
                }
                // Hide toast after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        showingSuccessToast = false
                    }
                }

                print("✅ Event added to '\(calendarName)' calendar")

            } catch {
                calendarErrorMessage = "Failed to create calendar event: \(error.localizedDescription)"
                showingCalendarError = true
                print("❌ Calendar error: \(error)")
            }
        }
    }

    private func copyContent() {
        guard let details = meetingDetails else { return }
        var text = details.subject + "\n"
        if let date = details.date { text += "Date: \(date)\n" }
        if let time = details.time { text += "Time: \(time)\n" }
        if let location = details.location { text += "Location: \(location)\n" }
        if !details.attendees.isEmpty {
            text += "Attendees: \(details.attendees.joined(separator: ", "))\n"
        }
        text += "\n\(details.notes)"
        UIPasteboard.general.string = text
    }
}

// MARK: - Attendee Chip

struct AttendeeChip: View {
    let name: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(.badgeMeeting.opacity(0.7))

            Text(name)
                .font(.serifBody(14, weight: .medium))
                .foregroundColor(.textDark)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.badgeMeeting.opacity(0.15))
        .cornerRadius(20)
    }
}

// MARK: - Attendee Flow Layout for Chips

struct AttendeeFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = AttendeeFlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = AttendeeFlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct AttendeeFlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth, x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + rowHeight)
        }
    }
}

#Preview {
    MeetingDetailView(note: Note())
}
