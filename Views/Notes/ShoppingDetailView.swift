//
//  ShoppingDetailView.swift
//  QuillStack
//
//  Created on 2025-12-31.
//

import SwiftUI
import EventKit
import CoreData

struct ShoppingDetailView: View, NoteDetailViewProtocol {
    @ObservedObject var note: Note
    @State private var items: [ShoppingItem] = []
    @State private var newItemText: String = ""
    @State private var showingRemindersSheet: Bool = false
    @State private var showingExportSheet: Bool = false
    @State private var showingSaveError: Bool = false
    @State private var saveErrorMessage: String = ""
    @State private var showingTypePicker = false
    @FocusState private var isAddingItem: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.creamLight.ignoresSafeArea()

            VStack(spacing: 0) {
                slimHeader

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach($items) { $item in
                            ShoppingItemRow(item: $item, onToggle: { saveChanges() })
                        }

                        addItemRow
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

                bottomBar
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            parseItems()
        }
        .sheet(isPresented: $showingRemindersSheet) {
            ShoppingExportSheet(items: items)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingExportSheet) {
            ExportSheet(note: note)
                .presentationDetents([.medium, .large])
        }
        .alert("Save Failed", isPresented: $showingSaveError) {
            Button("OK") { }
        } message: {
            Text(saveErrorMessage)
        }
        .sheet(isPresented: $showingTypePicker) {
            NoteTypePickerSheet(note: note)
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

                // Classification badge (only for automatic classifications)
                if note.classification.method.isAutomatic {
                    ClassificationBadge(classification: note.classification)
                }

                HStack(spacing: 4) {
                    Image(systemName: "cart")
                        .font(.system(size: 10, weight: .bold))
                    Text("SHOPPING")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.5)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    LinearGradient(
                        colors: [Color.badgeShopping, Color.badgeShopping.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(4)
                .shadow(color: Color.badgeShopping.opacity(0.3), radius: 2, x: 0, y: 1)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)

            HStack(spacing: 12) {
                Text(formattedDate)
                    .font(.serifCaption(12, weight: .regular))
                    .foregroundColor(.textLight.opacity(0.8))

                Text("•")
                    .foregroundColor(.textLight.opacity(0.5))

                Text("\(checkedCount)/\(items.count) items")
                    .font(.serifCaption(12, weight: .regular))
                    .foregroundColor(.textLight.opacity(0.8))

                Spacer()

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

    // MARK: - Add Item Row

    private var addItemRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.circle")
                .font(.system(size: 20, weight: .regular))
                .foregroundColor(.textMedium.opacity(0.6))

            TextField("Add item...", text: $newItemText)
                .font(.serifBody(16, weight: .regular))
                .foregroundColor(.textDark)
                .focused($isAddingItem)
                .onSubmit {
                    addItem()
                }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.clear)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 20) {
            // Change Type button
            Button(action: { showingTypePicker = true }) {
                Image(systemName: "arrow.left.arrow.right.circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.textDark)
            }
            .accessibilityLabel("Change note type")

            Button(action: { showingExportSheet = true }) {
                Image(systemName: "arrow.up.doc")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.textDark)
            }

            Button(action: shareList) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.textDark)
            }

            Button(action: copyContent) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.textDark)
            }

            Spacer()

            Button(action: { showingRemindersSheet = true }) {
                Image(systemName: "checklist")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        LinearGradient(
                            colors: [Color.badgeShopping, Color.badgeShopping.opacity(0.8)],
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
        let classifier = TextClassifier()
        if let extracted = classifier.extractTriggerTag(from: note.content) {
            let firstLine = extracted.cleanedContent.components(separatedBy: .newlines).first ?? "Shopping List"
            return firstLine.truncated(to: 30)
        }
        let firstLine = note.content.components(separatedBy: .newlines).first ?? "Shopping List"
        return firstLine.truncated(to: 30)
    }

    private var formattedDate: String {
        note.createdAt.shortFormat
    }

    private var checkedCount: Int {
        items.filter { $0.isChecked }.count
    }

    private var progressPercent: CGFloat {
        guard !items.isEmpty else { return 0 }
        return CGFloat(checkedCount) / CGFloat(items.count)
    }

    private func parseItems() {
        let classifier = TextClassifier()
        let content: String
        if let extracted = classifier.extractTriggerTag(from: note.content) {
            content = extracted.cleanedContent
        } else {
            content = note.content
        }

        let lines = content.components(separatedBy: .newlines)
        var parsedItems: [ShoppingItem] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            let isChecked = trimmed.lowercased().hasPrefix("[x]") ||
                            trimmed.lowercased().hasPrefix("(x)") ||
                            trimmed.lowercased().hasPrefix("✓") ||
                            trimmed.lowercased().hasPrefix("☑")

            var itemText = trimmed

            let prefixes = ["[ ]", "[x]", "[X]", "( )", "(x)", "(X)", "- ", "• ", "* ", "✓ ", "☑ ", "☐ "]
            for prefix in prefixes {
                if itemText.hasPrefix(prefix) {
                    itemText = String(itemText.dropFirst(prefix.count))
                    break
                }
            }

            if let match = itemText.range(of: "^\\d+\\.\\s*", options: .regularExpression) {
                itemText = String(itemText[match.upperBound...])
            }

            itemText = itemText.trimmingCharacters(in: .whitespaces)

            if !itemText.isEmpty {
                parsedItems.append(ShoppingItem(text: itemText, isChecked: isChecked))
            }
        }

        items = parsedItems
    }

    func saveChanges() {
        var lines: [String] = []

        let classifier = TextClassifier()
        if let extracted = classifier.extractTriggerTag(from: note.content) {
            lines.append(extracted.tag)
        }

        for item in items {
            let checkbox = item.isChecked ? "[x]" : "[ ]"
            lines.append("\(checkbox) \(item.text)")
        }

        note.content = lines.joined(separator: "\n")
        note.updatedAt = Date()
        do {
            try CoreDataStack.shared.saveViewContext()
        } catch {
            saveErrorMessage = error.localizedDescription
            showingSaveError = true
        }
    }

    private func addItem() {
        guard !newItemText.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        items.append(ShoppingItem(text: newItemText.trimmingCharacters(in: .whitespaces), isChecked: false))
        newItemText = ""
        saveChanges()
    }

    private func shareList() {
        let text = items.map { ($0.isChecked ? "☑" : "☐") + " " + $0.text }.joined(separator: "\n")
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }

    private func copyContent() {
        let text = items.map { ($0.isChecked ? "☑" : "☐") + " " + $0.text }.joined(separator: "\n")
        UIPasteboard.general.string = text
    }
}

// MARK: - Shopping Item Model

struct ShoppingItem: Identifiable {
    let id = UUID()
    var text: String
    var isChecked: Bool
}

// MARK: - Shopping Item Row

struct ShoppingItemRow: View {
    @Binding var item: ShoppingItem
    var onToggle: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: {
                item.isChecked.toggle()
                onToggle()
            }) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundColor(item.isChecked ? .badgeShopping : .textMedium.opacity(0.5))
            }

            Text(item.text)
                .font(.serifBody(16, weight: .regular))
                .foregroundColor(item.isChecked ? .textMedium.opacity(0.6) : .textDark)
                .strikethrough(item.isChecked, color: .textMedium.opacity(0.4))

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            item.isChecked.toggle()
            onToggle()
        }
    }
}

// MARK: - Shopping Export Sheet

struct ShoppingExportSheet: View {
    let items: [ShoppingItem]
    @Environment(\.dismiss) private var dismiss

    @State private var authorizationStatus: RemindersService.AuthorizationStatus = .notDetermined
    @State private var selectedList: EKCalendar?
    @State private var availableLists: [EKCalendar] = []
    @State private var selectedItems: Set<UUID> = []
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
            Image(systemName: "cart")
                .font(.system(size: 56))
                .foregroundColor(.forestDark)

            Text("Reminders Access Required")
                .font(.serifHeadline(20, weight: .semibold))
                .foregroundColor(.textDark)

            Text("QuillStack needs access to your Reminders to export shopping items.")
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

            Text("Please enable Reminders access in Settings to export your shopping list.")
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
                    listPickerSection
                    itemSelectionSection
                }
                .padding(20)
            }

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

            // Hint for Groceries list
            if let groceryList = availableLists.first(where: { $0.title.lowercased().contains("grocer") }) {
                Button(action: { selectedList = groceryList }) {
                    HStack(spacing: 6) {
                        Image(systemName: "cart.fill")
                            .font(.system(size: 12))
                        Text("Use \"\(groceryList.title)\" list")
                            .font(.serifCaption(12, weight: .medium))
                    }
                    .foregroundColor(.badgeShopping)
                }
                .padding(.top, 4)
            }
        }
    }

    private var itemSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Items to Export")
                    .font(.serifCaption(13, weight: .semibold))
                    .foregroundColor(.textMedium)

                Spacer()

                Button(action: toggleSelectAll) {
                    Text(selectedItems.count == items.count ? "Deselect All" : "Select All")
                        .font(.serifCaption(12, weight: .medium))
                        .foregroundColor(.forestDark)
                }
            }

            VStack(spacing: 0) {
                ForEach(items) { item in
                    Button(action: { toggleItem(item) }) {
                        HStack(spacing: 14) {
                            Image(systemName: selectedItems.contains(item.id) ? "checkmark.square.fill" : "square")
                                .font(.system(size: 20))
                                .foregroundColor(selectedItems.contains(item.id) ? .badgeShopping : .textMedium)

                            Text(item.text)
                                .font(.serifBody(15, weight: .regular))
                                .foregroundColor(.textDark)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)

                            Spacer()

                            if item.isChecked {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(14)
                    }

                    if item.id != items.last?.id {
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
            Button(action: exportItems) {
                HStack(spacing: 8) {
                    if isExporting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    Text(isExporting ? "Exporting..." : "Export \(selectedItems.count) Item\(selectedItems.count == 1 ? "" : "s")")
                        .font(.serifBody(16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: canExport ? [Color.badgeShopping, Color.badgeShopping.opacity(0.8)] : [Color.gray, Color.gray.opacity(0.8)],
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
                    let successCount = exportResults.filter { $0.success }.count
                    let failCount = exportResults.filter { !$0.success }.count

                    VStack(spacing: 12) {
                        Image(systemName: failCount == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(failCount == 0 ? .green : .orange)

                        Text(failCount == 0 ? "Export Complete" : "Export Finished")
                            .font(.serifHeadline(20, weight: .semibold))
                            .foregroundColor(.textDark)

                        Text("\(successCount) item\(successCount == 1 ? "" : "s") exported successfully\(failCount > 0 ? ", \(failCount) failed" : "")")
                            .font(.serifBody(14, weight: .regular))
                            .foregroundColor(.textMedium)
                    }
                    .padding(.top, 20)

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
        selectedList != nil && !selectedItems.isEmpty
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

        // Try to find a Groceries list first, otherwise use default
        if let groceryList = availableLists.first(where: { $0.title.lowercased().contains("grocer") }) {
            selectedList = groceryList
        } else {
            selectedList = RemindersService.shared.getDefaultReminderList()
        }

        // Select all unchecked items by default
        for item in items where !item.isChecked {
            selectedItems.insert(item.id)
        }
    }

    private func toggleItem(_ item: ShoppingItem) {
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        } else {
            selectedItems.insert(item.id)
        }
    }

    private func toggleSelectAll() {
        if selectedItems.count == items.count {
            selectedItems.removeAll()
        } else {
            selectedItems = Set(items.map { $0.id })
        }
    }

    private func exportItems() {
        guard let list = selectedList else { return }

        let itemsToExport = items.filter { selectedItems.contains($0.id) }
        let tasksToExport = itemsToExport.map { ParsedTask(text: $0.text, isCompleted: $0.isChecked) }
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

#Preview {
    ShoppingDetailView(note: Note())
}
