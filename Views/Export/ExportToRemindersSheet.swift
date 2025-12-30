//
//  ExportToRemindersSheet.swift
//  QuillStack
//
//  Created on 2025-12-18.
//

import SwiftUI
import EventKit

// MARK: - Export to Reminders Sheet

struct ExportToRemindersSheet: View {
    let tasks: [ParsedTask]
    @Environment(\.dismiss) private var dismiss

    @State private var authorizationStatus: RemindersService.AuthorizationStatus = .notDetermined
    @State private var selectedList: EKCalendar?
    @State private var availableLists: [EKCalendar] = []
    @State private var selectedTasks: Set<UUID> = []
    @State private var isExporting = false
    @State private var exportResults: [ReminderExportResult] = []
    @State private var showResults = false

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
                        if showResults {
                            resultsView
                        } else {
                            exportOptionsView
                        }
                    }
                }
            }
            .navigationTitle("Export to Reminders")
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
            }
        }
    }

    // MARK: - Request Access View

    private var requestAccessView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checklist")
                .font(.system(size: 56))
                .foregroundColor(.forestDark)

            Text("Reminders Access Required")
                .font(.serifHeadline(20, weight: .semibold))
                .foregroundColor(.textDark)

            Text("QuillStack needs access to your Reminders to export tasks.")
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

            Text("Please enable Reminders access in Settings to export your tasks.")
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

    // MARK: - Export Options View

    private var exportOptionsView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    // List picker
                    listPickerSection

                    // Task selection
                    taskSelectionSection
                }
                .padding(20)
            }

            // Export button
            exportButton
        }
    }

    private var listPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reminders List")
                .font(.serifCaption(13, weight: .semibold))
                .foregroundColor(.textMedium)

            Menu {
                ForEach(availableLists, id: \.calendarIdentifier) { list in
                    Button(action: { selectedList = list }) {
                        HStack {
                            Circle()
                                .fill(Color(cgColor: list.cgColor))
                                .frame(width: 12, height: 12)
                            Text(list.title)
                            if selectedList?.calendarIdentifier == list.calendarIdentifier {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    if let list = selectedList {
                        Circle()
                            .fill(Color(cgColor: list.cgColor))
                            .frame(width: 16, height: 16)
                        Text(list.title)
                            .font(.serifBody(16, weight: .medium))
                            .foregroundColor(.textDark)
                    } else {
                        Text("Select a list")
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

    private var taskSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Tasks to Export")
                    .font(.serifCaption(13, weight: .semibold))
                    .foregroundColor(.textMedium)

                Spacer()

                Button(action: toggleSelectAll) {
                    Text(selectedTasks.count == tasks.count ? "Deselect All" : "Select All")
                        .font(.serifCaption(12, weight: .medium))
                        .foregroundColor(.forestDark)
                }
            }

            VStack(spacing: 0) {
                ForEach(tasks) { task in
                    Button(action: { toggleTask(task) }) {
                        HStack(spacing: 14) {
                            Image(systemName: selectedTasks.contains(task.id) ? "checkmark.square.fill" : "square")
                                .font(.system(size: 20))
                                .foregroundColor(selectedTasks.contains(task.id) ? .badgeTodo : .textMedium)

                            Text(task.text)
                                .font(.serifBody(15, weight: .regular))
                                .foregroundColor(.textDark)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)

                            Spacer()

                            if task.isCompleted {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(14)
                    }

                    if task.id != tasks.last?.id {
                        Divider()
                    }
                }
            }
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
    }

    private var exportButton: some View {
        VStack(spacing: 12) {
            Button(action: exportTasks) {
                HStack(spacing: 8) {
                    if isExporting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    Text(isExporting ? "Exporting..." : "Export \(selectedTasks.count) Task\(selectedTasks.count == 1 ? "" : "s")")
                        .font(.serifBody(16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: canExport ? [Color.badgeTodo, Color.badgeTodo.opacity(0.8)] : [Color.gray, Color.gray.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(12)
            }
            .disabled(!canExport || isExporting)
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

    // MARK: - Results View

    private var resultsView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    // Summary
                    let successCount = exportResults.filter { $0.success }.count
                    let failCount = exportResults.filter { !$0.success }.count

                    VStack(spacing: 12) {
                        Image(systemName: failCount == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(failCount == 0 ? .green : .orange)

                        Text(failCount == 0 ? "Export Complete" : "Export Finished")
                            .font(.serifHeadline(20, weight: .semibold))
                            .foregroundColor(.textDark)

                        Text("\(successCount) task\(successCount == 1 ? "" : "s") exported successfully\(failCount > 0 ? ", \(failCount) failed" : "")")
                            .font(.serifBody(14, weight: .regular))
                            .foregroundColor(.textMedium)
                    }
                    .padding(.top, 20)

                    // Results list
                    VStack(spacing: 0) {
                        ForEach(exportResults) { result in
                            HStack(spacing: 12) {
                                Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(result.success ? .green : .red)

                                Text(result.task)
                                    .font(.serifBody(14, weight: .regular))
                                    .foregroundColor(.textDark)
                                    .lineLimit(1)

                                Spacer()

                                if !result.success, let error = result.error {
                                    Text(error)
                                        .font(.serifCaption(11, weight: .regular))
                                        .foregroundColor(.textLight)
                                        .lineLimit(1)
                                }
                            }
                            .padding(12)

                            if result.id != exportResults.last?.id {
                                Divider()
                            }
                        }
                    }
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                }
                .padding(20)
            }

            // Done button
            Button(action: { dismiss() }) {
                Text("Done")
                    .font(.serifBody(16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.forestDark)
                    .cornerRadius(12)
            }
            .padding(20)
            .background(Color.creamLight)
        }
    }

    // MARK: - Helpers

    private var canExport: Bool {
        selectedList != nil && !selectedTasks.isEmpty
    }

    private func checkAuthorization() {
        authorizationStatus = RemindersService.shared.authorizationStatus
        if authorizationStatus == .authorized {
            loadLists()
        }
    }

    private func requestAccess() {
        Task {
            let granted = await RemindersService.shared.requestAccess()
            await MainActor.run {
                authorizationStatus = granted ? .authorized : .denied
                if granted {
                    loadLists()
                }
            }
        }
    }

    private func loadLists() {
        availableLists = RemindersService.shared.getReminderLists()
        selectedList = RemindersService.shared.getDefaultReminderList()

        // Select all incomplete tasks by default
        for task in tasks where !task.isCompleted {
            selectedTasks.insert(task.id)
        }
    }

    private func toggleTask(_ task: ParsedTask) {
        if selectedTasks.contains(task.id) {
            selectedTasks.remove(task.id)
        } else {
            selectedTasks.insert(task.id)
        }
    }

    private func toggleSelectAll() {
        if selectedTasks.count == tasks.count {
            selectedTasks.removeAll()
        } else {
            selectedTasks = Set(tasks.map { $0.id })
        }
    }

    private func exportTasks() {
        guard let list = selectedList else { return }

        let tasksToExport = tasks.filter { selectedTasks.contains($0.id) }
        isExporting = true

        Task {
            let results = try? await RemindersService.shared.exportTasks(tasksToExport, toList: list)
            await MainActor.run {
                exportResults = results ?? []
                isExporting = false
                showResults = true
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
    ExportToRemindersSheet(tasks: [
        ParsedTask(text: "Buy groceries", isCompleted: false),
        ParsedTask(text: "Call mom", isCompleted: true),
        ParsedTask(text: "Finish report", isCompleted: false)
    ])
}
