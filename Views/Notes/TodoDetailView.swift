//
//  TodoDetailView.swift
//  QuillStack
//
//  Created on 2025-12-15.
//

import SwiftUI
import CoreData

struct TodoDetailView: View, NoteDetailViewProtocol {
    @ObservedObject var note: Note
    @State private var tasks: [ParsedTask] = []
    @State private var newTaskText: String = ""
    @State private var showingExportSheet: Bool = false
    @State private var showingSummarySheet: Bool = false
    @State private var showingRemindersSheet: Bool = false
    @FocusState private var isAddingTask: Bool
    @Environment(\.dismiss) private var dismiss

    // MARK: - NoteDetailViewProtocol

    var shareableContent: String {
        tasks.map { ($0.isCompleted ? "☑" : "☐") + " " + $0.text }.joined(separator: "\n")
    }

    var body: some View {
        ZStack {
            Color.creamLight.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header using shared component
                DetailHeader(
                    title: noteTitle,
                    date: note.createdAt,
                    noteType: "todo",
                    onBack: { dismiss() },
                    completedCount: completedCount,
                    totalCount: tasks.count
                )

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
        DetailBottomBar(
            onExport: { showingExportSheet = true },
            onShare: { shareContent() },
            onCopy: { copyToClipboard() },
            aiActions: DetailBottomBar.summarizeOnlyAIActions(
                onSummarize: { showingSummarySheet = true }
            ),
            primaryAction: DetailAction(
                icon: "checklist",
                color: .badgeTodo
            ) { showingRemindersSheet = true }
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

    private var completedCount: Int {
        tasks.filter { $0.isCompleted }.count
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

    func saveChanges() {
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
