//
//  MeetingListView.swift
//  QuillStack
//
//  Created on 2025-12-10.
//

import SwiftUI

struct MeetingListView: View {
    @StateObject private var viewModel = MeetingViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.meetings.isEmpty {
                    emptyStateView
                } else {
                    meetingListContent
                }
            }
            .navigationTitle("Meetings")
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No meetings yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Capture meeting notes and they'll appear here")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    private var meetingListContent: some View {
        List {
            ForEach(viewModel.meetings) { meeting in
                MeetingRowView(meeting: meeting)
            }
        }
    }
}

struct MeetingRowView: View {
    let meeting: Meeting

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(meeting.title)
                .font(.headline)

            if let date = meeting.meetingDate {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption)
                    Text(date, style: .date)
                        .font(.caption)

                    Image(systemName: "clock")
                        .font(.caption)
                        .padding(.leading, 8)
                    Text("\(meeting.duration) min")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }

            if !meeting.attendeesList.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "person.2")
                        .font(.caption)
                    Text(meeting.attendeesList.prefix(3).joined(separator: ", "))
                        .font(.caption)
                        .lineLimit(1)
                }
                .foregroundColor(.secondary)
            }

            if !meeting.actionItemsList.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle")
                        .font(.caption)
                    Text("\(meeting.actionItemsList.count) action items")
                        .font(.caption)
                }
                .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    MeetingListView()
}
