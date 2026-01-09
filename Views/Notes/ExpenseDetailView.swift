//
//  ExpenseDetailView.swift
//  QuillStack
//
//  Created on 2025-12-31.
//

import SwiftUI
import CoreData

struct ExpenseDetailView: View, NoteDetailViewProtocol {
    @ObservedObject var note: Note
    @State private var amount: String = ""
    @State private var vendor: String = ""
    @State private var category: String = ""
    @State private var expenseDate: Date = Date()
    @State private var notes: String = ""
    @State private var showingImageViewer = false
    @State private var showingExportSheet = false
    @State private var showingShareSheet = false
    @State private var csvData: String = ""
    @State private var showingSaveError: Bool = false
    @State private var saveErrorMessage: String = ""
    @State private var showingTypePicker = false
    @Bindable private var settings = SettingsManager.shared
    @Environment(\.dismiss) private var dismiss

    private let categories = ["Food", "Transport", "Office", "Travel", "Utilities", "Entertainment", "Other"]

    var body: some View {
        ZStack {
            Color.creamLight.ignoresSafeArea()

            VStack(spacing: 0) {
                slimHeader

                ScrollView {
                    VStack(spacing: 16) {
                        // Receipt image preview
                        receiptImageSection

                        // Expense fields
                        expenseFieldsSection

                        // Notes section
                        notesSection

                        // Related notes section (QUI-161)
                        if note.linkCount > 0 {
                            RelatedNotesSection(note: note) { selectedNote in
                                // TODO: Navigate to selected note
                                print("Selected related note: \(selectedNote.id)")
                            }
                            .padding(.vertical, 12)
                        }
                    }
                    .padding(16)
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
            parseExpenseContent()
        }
        .onChange(of: amount) { _, _ in saveChanges() }
        .onChange(of: vendor) { _, _ in saveChanges() }
        .onChange(of: category) { _, _ in saveChanges() }
        .onChange(of: expenseDate) { _, _ in saveChanges() }
        .onChange(of: notes) { _, _ in saveChanges() }
        .sheet(isPresented: $showingImageViewer) {
            ReceiptImageViewer(note: note)
        }
        .sheet(isPresented: $showingExportSheet) {
            ExportSheet(note: note)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [generateCSV()])
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

                Text("Expense")
                    .font(.serifBody(17, weight: .semibold))
                    .foregroundColor(.forestLight)
                    .lineLimit(1)

                Spacer()

                // Classification badge (only for automatic classifications)
                if note.classification.method.isAutomatic {
                    ClassificationBadge(classification: note.classification)
                }

                // Badge
                HStack(spacing: 4) {
                    Image(systemName: "dollarsign.circle")
                        .font(.system(size: 10, weight: .bold))
                    Text("EXPENSE")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.5)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    LinearGradient(
                        colors: [Color.badgeExpense, Color.badgeExpense.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(4)
                .shadow(color: Color.badgeExpense.opacity(0.3), radius: 2, x: 0, y: 1)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)

            // Date row with amount
            HStack(spacing: 12) {
                Text(formattedDate)
                    .font(.serifCaption(12, weight: .regular))
                    .foregroundColor(.textLight.opacity(0.8))

                Text("•")
                    .foregroundColor(.textLight.opacity(0.5))

                if !amount.isEmpty {
                    Text(formattedAmount)
                        .font(.serifCaption(12, weight: .semibold))
                        .foregroundColor(.textLight)
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

    // MARK: - Receipt Image Section

    private var receiptImageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Receipt Image")
                .font(.serifCaption(12, weight: .medium))
                .foregroundColor(.textMedium)

            Button(action: { showingImageViewer = true }) {
                if let firstPage = note.sortedPages.first,
                   let thumbnail = firstPage.thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 120)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.forestDark.opacity(0.2), lineWidth: 1)
                        )
                        .overlay(
                            Image(systemName: "magnifyingglass.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                                .shadow(radius: 2)
                                .padding(8),
                            alignment: .bottomTrailing
                        )
                } else if let imageData = note.originalImageData,
                          let image = UIImage(data: imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 120)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.forestDark.opacity(0.2), lineWidth: 1)
                        )
                        .overlay(
                            Image(systemName: "magnifyingglass.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                                .shadow(radius: 2)
                                .padding(8),
                            alignment: .bottomTrailing
                        )
                } else {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "photo")
                                .font(.system(size: 32))
                                .foregroundColor(.textMedium.opacity(0.5))
                            Text("No receipt image")
                                .font(.serifCaption(13, weight: .regular))
                                .foregroundColor(.textMedium)
                        }
                        Spacer()
                    }
                    .frame(height: 100)
                    .background(Color.forestDark.opacity(0.05))
                    .cornerRadius(8)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.white.opacity(0.5))
        .cornerRadius(12)
    }

    // MARK: - Expense Fields Section

    private var expenseFieldsSection: some View {
        VStack(spacing: 0) {
            // Amount
            expenseField(
                icon: "dollarsign.circle",
                label: "Amount",
                content: {
                    TextField("0.00", text: $amount)
                        .font(.serifBody(18, weight: .semibold))
                        .foregroundColor(.textDark)
                        .keyboardType(.decimalPad)
                }
            )

            Divider().background(Color.forestDark.opacity(0.1))

            // Vendor
            expenseField(
                icon: "building.2",
                label: "Vendor",
                content: {
                    TextField("Store or business name", text: $vendor)
                        .font(.serifBody(16, weight: .regular))
                        .foregroundColor(.textDark)
                }
            )

            Divider().background(Color.forestDark.opacity(0.1))

            // Category
            expenseField(
                icon: "tag",
                label: "Category",
                content: {
                    Menu {
                        ForEach(categories, id: \.self) { cat in
                            Button(cat) {
                                category = cat
                            }
                        }
                    } label: {
                        HStack {
                            Text(category.isEmpty ? "Select category" : category)
                                .font(.serifBody(16, weight: .regular))
                                .foregroundColor(category.isEmpty ? .textMedium : .textDark)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12))
                                .foregroundColor(.textMedium)
                        }
                    }
                }
            )

            Divider().background(Color.forestDark.opacity(0.1))

            // Date
            expenseField(
                icon: "calendar",
                label: "Date",
                content: {
                    DatePicker("", selection: $expenseDate, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                }
            )
        }
        .background(Color.white.opacity(0.5))
        .cornerRadius(12)
    }

    private func expenseField<Content: View>(
        icon: String,
        label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.badgeExpense)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.serifCaption(11, weight: .medium))
                    .foregroundColor(.textMedium)
                content()
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.serifCaption(12, weight: .medium))
                .foregroundColor(.textMedium)

            TextEditor(text: $notes)
                .font(.serifBody(15, weight: .regular))
                .foregroundColor(.textDark)
                .lineSpacing(4)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 80)
                .padding(12)
                .background(Color.white.opacity(0.5))
                .cornerRadius(8)
        }
        .padding(16)
        .background(Color.white.opacity(0.3))
        .cornerRadius(12)
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

            // Export
            Button(action: { showingExportSheet = true }) {
                Image(systemName: "arrow.up.doc")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.textDark)
            }

            // Copy
            Button(action: copyExpenseToClipboard) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.textDark)
            }

            Spacer()

            // Export CSV button
            Button(action: { showingShareSheet = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "tablecells")
                        .font(.system(size: 14, weight: .semibold))
                    Text("CSV")
                        .font(.serifBody(14, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [Color.badgeExpense, Color.badgeExpense.opacity(0.8)],
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

    private var formattedDate: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(note.createdAt) {
            return "Today"
        } else if calendar.isDateInYesterday(note.createdAt) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: note.createdAt)
        }
    }

    private var formattedAmount: String {
        guard let value = Double(amount.replacingOccurrences(of: ",", with: ".")) else {
            return amount
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: value)) ?? "$\(amount)"
    }

    private func parseExpenseContent() {
        let classifier = TextClassifier()
        let content: String
        if let extracted = classifier.extractTriggerTag(from: note.content) {
            content = extracted.cleanedContent
        } else {
            content = note.content
        }

        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let lowercased = trimmed.lowercased()

            // Parse amount - look for $ or "amount:"
            if lowercased.hasPrefix("amount:") {
                amount = extractValue(from: trimmed, prefix: "amount:")
            } else if let dollarMatch = extractDollarAmount(from: trimmed) {
                if amount.isEmpty {
                    amount = dollarMatch
                }
            }

            // Parse vendor
            if lowercased.hasPrefix("vendor:") || lowercased.hasPrefix("store:") || lowercased.hasPrefix("from:") {
                vendor = extractValue(from: trimmed, prefix: lowercased.hasPrefix("vendor:") ? "vendor:" : (lowercased.hasPrefix("store:") ? "store:" : "from:"))
            }

            // Parse category
            if lowercased.hasPrefix("category:") || lowercased.hasPrefix("cat:") {
                category = extractValue(from: trimmed, prefix: lowercased.hasPrefix("category:") ? "category:" : "cat:")
            }

            // Parse date
            if lowercased.hasPrefix("date:") {
                let dateStr = extractValue(from: trimmed, prefix: "date:")
                if let parsed = parseDate(dateStr) {
                    expenseDate = parsed
                }
            }
        }

        // Remaining content becomes notes
        var noteLines: [String] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let lowercased = trimmed.lowercased()

            // Skip parsed fields
            if lowercased.hasPrefix("amount:") ||
               lowercased.hasPrefix("vendor:") ||
               lowercased.hasPrefix("store:") ||
               lowercased.hasPrefix("from:") ||
               lowercased.hasPrefix("category:") ||
               lowercased.hasPrefix("cat:") ||
               lowercased.hasPrefix("date:") ||
               trimmed.isEmpty {
                continue
            }

            // Skip lines that are just dollar amounts
            if extractDollarAmount(from: trimmed) != nil && trimmed.count < 15 {
                continue
            }

            noteLines.append(line)
        }

        notes = noteLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractValue(from line: String, prefix: String) -> String {
        guard let range = line.lowercased().range(of: prefix) else { return "" }
        let startIndex = line.index(line.startIndex, offsetBy: line.distance(from: line.startIndex, to: range.upperBound))
        return String(line[startIndex...]).trimmingCharacters(in: .whitespaces)
    }

    private func extractDollarAmount(from text: String) -> String? {
        // Match patterns like $12.34, $12, 12.34, etc.
        let patterns = [
            #"\$\d+\.?\d*"#,  // $12.34 or $12
            #"\d+\.\d{2}"#    // 12.34
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
                let range = Range(match.range, in: text)!
                var result = String(text[range])
                result = result.replacingOccurrences(of: "$", with: "")
                return result
            }
        }
        return nil
    }

    private func parseDate(_ dateStr: String) -> Date? {
        let formatters = [
            "MM/dd/yyyy", "MM-dd-yyyy", "yyyy-MM-dd",
            "MMM d, yyyy", "MMM d yyyy", "d MMM yyyy"
        ]

        for format in formatters {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            if let date = formatter.date(from: dateStr) {
                return date
            }
        }
        return nil
    }

    func saveChanges() {
        var lines: [String] = ["#expense#"]

        if !amount.isEmpty {
            lines.append("Amount: $\(amount)")
        }
        if !vendor.isEmpty {
            lines.append("Vendor: \(vendor)")
        }
        if !category.isEmpty {
            lines.append("Category: \(category)")
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy"
        lines.append("Date: \(dateFormatter.string(from: expenseDate))")

        if !notes.isEmpty {
            lines.append("")
            lines.append(notes)
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

    private func generateCSV() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        var csv = "Date,Amount,Vendor,Category,Notes\n"
        let escapedNotes = notes.replacingOccurrences(of: "\"", with: "\"\"")
        let escapedVendor = vendor.replacingOccurrences(of: "\"", with: "\"\"")

        csv += "\"\(dateFormatter.string(from: expenseDate))\",\"\(amount)\",\"\(escapedVendor)\",\"\(category)\",\"\(escapedNotes)\"\n"

        return csv
    }

    private func copyExpenseToClipboard() {
        var text = ""
        if !amount.isEmpty { text += "Amount: $\(amount)\n" }
        if !vendor.isEmpty { text += "Vendor: \(vendor)\n" }
        if !category.isEmpty { text += "Category: \(category)\n" }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy"
        text += "Date: \(dateFormatter.string(from: expenseDate))\n"

        if !notes.isEmpty { text += "\n\(notes)" }

        UIPasteboard.general.string = text
    }
}

// MARK: - Receipt Image Viewer

struct ReceiptImageViewer: View {
    let note: Note
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if note.sortedPages.isEmpty {
                    if let imageData = note.originalImageData,
                       let image = UIImage(data: imageData) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }
                } else {
                    TabView(selection: $currentPage) {
                        ForEach(note.sortedPages.indices, id: \.self) { index in
                            let page = note.sortedPages[index]
                            if let image = page.image {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .tag(index)
                            }
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .automatic))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .principal) {
                    Text("Receipt")
                        .foregroundColor(.white)
                        .font(.headline)
                }
            }
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ExpenseDetailView(note: Note())
}
