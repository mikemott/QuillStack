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
    @State private var showingTypePicker: Bool = false
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
                    totalCount: tasks.count,
                    classification: note.classification
                )

                // Task list
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach($tasks) { $task in
                            TaskRowView(task: $task, onToggle: { saveChanges() })
                        }

                        // Add task row
                        addTaskRow

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
            TodoReviewSheet(
                tasks: extractedTodos,
                onSave: { editedTasks in
                    try await handleTasksSaved(editedTasks)
                },
                onCancel: {
                    showingRemindersSheet = false
                }
            )
        }
        .sheet(isPresented: $showingTypePicker) {
            NoteTypePickerSheet(note: note)
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
            customActions: [
                DetailAction(icon: "arrow.left.arrow.right.circle") {
                    showingTypePicker = true
                }
            ],
            primaryAction: DetailAction(
                icon: "checklist",
                color: .badgeTodo
            ) { showingRemindersSheet = true }
        )
    }

    // MARK: - Helpers

    private var noteTitle: String {
        // Use smart title extraction (QUI-146)
        // Skips checkbox lines and finds meaningful headers
        note.smartTitle.truncated(to: 30)
    }

    private var completedCount: Int {
        tasks.filter { $0.isCompleted }.count
    }

    /// Convert ParsedTask to ExtractedTodo for TodoReviewSheet
    private var extractedTodos: [ExtractedTodo] {
        // First, try to load from extractedDataJSON if available
        if let extractedJSON = note.extractedDataJSON,
           let jsonData = extractedJSON.data(using: .utf8) {
            do {
                let todos = try JSONDecoder().decode([ExtractedTodo].self, from: jsonData)
                return todos
            } catch {
                // Log JSON decoding error for debugging
                print("⚠️ Failed to decode extractedDataJSON for todos: \(error.localizedDescription)")
                // Fall through to fallback below
            }
        }

        // Fall back to converting from current tasks
        return tasks.map { task in
            ExtractedTodo(
                text: task.text,
                isCompleted: task.isCompleted,
                priority: "normal",
                dueDate: nil,
                notes: nil
            )
        }
    }

    private func parseTasks() {
        // First, try to load from extractedDataJSON if available
        if let extractedJSON = note.extractedDataJSON,
           let jsonData = extractedJSON.data(using: .utf8) {
            do {
                let extractedTodos = try JSONDecoder().decode([ExtractedTodo].self, from: jsonData)
                // Convert ExtractedTodo to ParsedTask
                tasks = extractedTodos.map { todo in
                    ParsedTask(text: todo.text, isCompleted: todo.isCompleted)
                }
                return
            } catch {
                // Log JSON decoding error for debugging, but fall back gracefully
                print("Failed to decode extractedDataJSON for todos: \(error.localizedDescription)")
            }
        }
        
        // Fall back to parsing from content
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

    private func handleTasksSaved(_ editedTasks: [EditableTask]) async throws {
        // Tasks were successfully saved to Reminders
        // Optionally update the note with the edited tasks
        // For now, we just dismiss the sheet (handled by TodoReviewSheet)
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
