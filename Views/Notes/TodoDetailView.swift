//
//  TodoDetailView.swift
//  QuillStack
//
//  Created on 2025-12-15.
//

import SwiftUI
import CoreData

struct TodoDetailView: View {
    @ObservedObject var note: Note
    @State private var tasks: [ParsedTask] = []
    @State private var newTaskText: String = ""
    @State private var showingExportSheet: Bool = false
    @State private var showingSummarySheet: Bool = false
    @State private var showingRemindersSheet: Bool = false
    @FocusState private var isAddingTask: Bool
    @ObservedObject private var settings = SettingsManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.creamLight.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                slimHeader

                // Task list
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach($tasks) { $task in
                            TaskRowView(task: $task, onToggle: { saveChanges() })
                        }

                        // Add task row
                        addTaskRow
                    }
                    .padding(.vertical, 12)
                }
                .background(
                    LinearGradient(
                        colors: [Color.paperBeige.opacity(0.98), Color.paperTan.opacity(0.98)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

                // Bottom bar with progress
                bottomBar
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            parseTasks()
        }
        .sheet(isPresented: $showingExportSheet) {
            ExportSheet(note: note)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingSummarySheet) {
            SummarySheet(note: note)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingRemindersSheet) {
            ExportToRemindersSheet(tasks: tasks)
                .presentationDetents([.medium, .large])
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

                Text(noteTitle)
                    .font(.serifBody(17, weight: .semibold))
                    .foregroundColor(.forestLight)
                    .lineLimit(1)

                Spacer()

                // Badge
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.square")
                        .font(.system(size: 10, weight: .bold))
                    Text("TO-DO")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.5)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    LinearGradient(
                        colors: [Color.badgeTodo, Color.badgeTodo.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(4)
                .shadow(color: Color.badgeTodo.opacity(0.3), radius: 2, x: 0, y: 1)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)

            // Progress row
            HStack(spacing: 12) {
                Text(formattedDate)
                    .font(.serifCaption(12, weight: .regular))
                    .foregroundColor(.textLight.opacity(0.8))

                Text("•")
                    .foregroundColor(.textLight.opacity(0.5))

                Text("\(completedCount)/\(tasks.count) complete")
                    .font(.serifCaption(12, weight: .regular))
                    .foregroundColor(.textLight.opacity(0.8))

                Spacer()

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.forestLight.opacity(0.3))
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.forestLight)
                            .frame(width: geo.size.width * progressPercent, height: 4)
                    }
                }
                .frame(width: 60, height: 4)
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

    // MARK: - Add Task Row

    private var addTaskRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.circle")
                .font(.system(size: 20, weight: .regular))
                .foregroundColor(.textMedium.opacity(0.6))

            TextField("Add a task...", text: $newTaskText)
                .font(.serifBody(16, weight: .regular))
                .foregroundColor(.textDark)
                .focused($isAddingTask)
                .onSubmit {
                    addTask()
                }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.clear)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 20) {
            // AI menu (only show if API key configured)
            if settings.hasAPIKey {
                Menu {
                    Button(action: { showingSummarySheet = true }) {
                        Label("Summarize", systemImage: "text.quote")
                    }
                } label: {
                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.forestDark)
                }
            }

            // Export
            Button(action: { showingExportSheet = true }) {
                Image(systemName: "arrow.up.doc")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.textDark)
            }

            // Share
            Button(action: shareNote) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.textDark)
            }

            // Copy
            Button(action: copyContent) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.textDark)
            }

            Spacer()

            // Export to Reminders
            Button(action: { showingRemindersSheet = true }) {
                Image(systemName: "checklist")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        LinearGradient(
                            colors: [Color.badgeTodo, Color.badgeTodo.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(10)
            }
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

    private var noteTitle: String {
        // Remove the trigger tag from title
        let classifier = TextClassifier()
        if let extracted = classifier.extractTriggerTag(from: note.content) {
            let firstLine = extracted.cleanedContent.components(separatedBy: .newlines).first ?? "To-Do List"
            return firstLine.truncated(to: 30)
        }
        let firstLine = note.content.components(separatedBy: .newlines).first ?? "To-Do List"
        return firstLine.truncated(to: 30)
    }

    private var formattedDate: String {
        note.createdAt.shortFormat
    }

    private var completedCount: Int {
        tasks.filter { $0.isCompleted }.count
    }

    private var progressPercent: CGFloat {
        guard !tasks.isEmpty else { return 0 }
        return CGFloat(completedCount) / CGFloat(tasks.count)
    }

    private func parseTasks() {
        let classifier = TextClassifier()
        let content: String
        if let extracted = classifier.extractTriggerTag(from: note.content) {
            content = extracted.cleanedContent
        } else {
            content = note.content
        }

        let lines = content.components(separatedBy: .newlines)
        var parsedTasks: [ParsedTask] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Check for checkbox patterns
            let isCompleted = trimmed.lowercased().hasPrefix("[x]") ||
                              trimmed.lowercased().hasPrefix("(x)")

            // Extract task text
            var taskText = trimmed

            // Remove checkbox prefixes
            let prefixes = ["[ ]", "[x]", "[X]", "( )", "(x)", "(X)", "- ", "• ", "* "]
            for prefix in prefixes {
                if taskText.hasPrefix(prefix) {
                    taskText = String(taskText.dropFirst(prefix.count))
                    break
                }
            }

            // Remove numbered list prefix
            if let match = taskText.range(of: "^\\d+\\.\\s*", options: .regularExpression) {
                taskText = String(taskText[match.upperBound...])
            }

            taskText = taskText.trimmingCharacters(in: .whitespaces)

            if !taskText.isEmpty {
                parsedTasks.append(ParsedTask(text: taskText, isCompleted: isCompleted))
            }
        }

        tasks = parsedTasks
    }

    private func saveChanges() {
        // Rebuild content from tasks
        var lines: [String] = []

        // Check if original had a trigger tag
        let classifier = TextClassifier()
        if let extracted = classifier.extractTriggerTag(from: note.content) {
            lines.append(extracted.tag)
        }

        for task in tasks {
            let checkbox = task.isCompleted ? "[x]" : "[ ]"
            lines.append("\(checkbox) \(task.text)")
        }

        note.content = lines.joined(separator: "\n")
        note.updatedAt = Date()
        try? CoreDataStack.shared.saveViewContext()
    }

    private func addTask() {
        guard !newTaskText.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        tasks.append(ParsedTask(text: newTaskText.trimmingCharacters(in: .whitespaces), isCompleted: false))
        newTaskText = ""
        saveChanges()
    }

    private func shareNote() {
        let text = tasks.map { ($0.isCompleted ? "☑" : "☐") + " " + $0.text }.joined(separator: "\n")
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }

    private func copyContent() {
        let text = tasks.map { ($0.isCompleted ? "☑" : "☐") + " " + $0.text }.joined(separator: "\n")
        UIPasteboard.general.string = text
    }
}

// MARK: - Parsed Task Model

struct ParsedTask: Identifiable {
    let id = UUID()
    var text: String
    var isCompleted: Bool
}

// MARK: - Task Row View

struct TaskRowView: View {
    @Binding var task: ParsedTask
    var onToggle: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Checkbox
            Button(action: {
                task.isCompleted.toggle()
                onToggle()
            }) {
                Image(systemName: task.isCompleted ? "checkmark.square.fill" : "square")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundColor(task.isCompleted ? .badgeTodo : .textMedium.opacity(0.5))
            }

            // Task text
            Text(task.text)
                .font(.serifBody(16, weight: .regular))
                .foregroundColor(task.isCompleted ? .textMedium.opacity(0.6) : .textDark)
                .strikethrough(task.isCompleted, color: .textMedium.opacity(0.4))

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            task.isCompleted.toggle()
            onToggle()
        }
    }
}

#Preview {
    TodoDetailView(note: Note())
}
