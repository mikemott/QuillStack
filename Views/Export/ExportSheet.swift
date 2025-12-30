//
//  ExportSheet.swift
//  QuillStack
//
//  Created on 2025-12-18.
//

import SwiftUI
import CoreData

// MARK: - Export Sheet

/// Quick export sheet shown from bottom bar button
struct ExportSheet: View {
    let note: Note
    @Environment(\.dismiss) private var dismiss
    @StateObject private var settings = SettingsManager.shared

    @State private var isExporting = false
    @State private var exportResult: ExportResult?
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var includeImage = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header
                headerSection

                // Destination buttons
                destinationSection

                // Options
                optionsSection

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .background(Color.creamLight)
            .navigationTitle("Export Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.forestDark)
                }
            }
            .alert("Export Failed", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .overlay {
                if isExporting {
                    exportingOverlay
                }
            }
            .overlay {
                if let result = exportResult, result.success {
                    successOverlay(result: result)
                }
            }
        }
        .onAppear {
            includeImage = settings.includeOriginalImageDefault
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Export to")
                .font(.serifBody(15, weight: .medium))
                .foregroundColor(.textMedium)

            // Note preview
            HStack(spacing: 12) {
                // Type badge
                Text(note.noteType.capitalized)
                    .font(.serifCaption(11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(badgeColor(for: note.noteType))
                    .cornerRadius(4)

                // Title preview
                Text(extractTitle(from: note.content))
                    .font(.serifBody(14, weight: .medium))
                    .foregroundColor(.textDark)
                    .lineLimit(1)

                Spacer()
            }
            .padding(12)
            .background(Color.white)
            .cornerRadius(8)
        }
    }

    // MARK: - Destinations

    private var destinationSection: some View {
        VStack(spacing: 12) {
            ForEach(ExportDestinationType.allCases) { destination in
                ExportDestinationButton(
                    destination: destination,
                    isConfigured: ExportService.shared.canExport(to: destination),
                    isExporting: isExporting,
                    action: {
                        exportTo(destination)
                    }
                )
            }
        }
    }

    // MARK: - Options

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Options")
                .font(.serifBody(15, weight: .medium))
                .foregroundColor(.textMedium)

            Toggle(isOn: $includeImage) {
                HStack(spacing: 10) {
                    Image(systemName: "photo")
                        .foregroundColor(.forestDark)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Include original image")
                            .font(.serifBody(14, weight: .medium))
                            .foregroundColor(.textDark)
                        Text("Attach the captured handwriting")
                            .font(.serifCaption(12, weight: .regular))
                            .foregroundColor(.textMedium)
                    }
                }
            }
            .tint(.forestDark)
            .padding(12)
            .background(Color.white)
            .cornerRadius(8)
        }
    }

    // MARK: - Overlays

    private var exportingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.forestDark)

                Text("Exporting...")
                    .font(.serifBody(15, weight: .medium))
                    .foregroundColor(.textDark)
            }
            .padding(32)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(radius: 10)
        }
    }

    private func successOverlay(result: ExportResult) -> some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.green)

                Text(result.message ?? "Exported successfully")
                    .font(.serifBody(15, weight: .medium))
                    .foregroundColor(.textDark)

                HStack(spacing: 12) {
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .tint(.forestDark)

                    if let openURL = result.openURL {
                        Button("Open") {
                            UIApplication.shared.open(openURL)
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.forestDark)
                    }
                }
            }
            .padding(32)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(radius: 10)
        }
    }

    // MARK: - Actions

    private func exportTo(_ destination: ExportDestinationType) {
        guard !isExporting else { return }

        isExporting = true
        exportResult = nil

        Task {
            do {
                let options = ExportOptions(
                    includeOriginalImage: includeImage,
                    includeMetadata: true,
                    openAfterExport: false
                )

                let result = try await ExportService.shared.export(
                    note: note,
                    to: destination,
                    options: options
                )

                await MainActor.run {
                    isExporting = false
                    exportResult = result
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }

    // MARK: - Helpers

    private func extractTitle(from content: String) -> String {
        let firstLine = content.components(separatedBy: .newlines).first ?? "Untitled"
        let cleaned = firstLine
            .replacingOccurrences(of: "#\\w+#", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty ? "Untitled" : String(cleaned.prefix(40))
    }

    private func badgeColor(for type: String) -> Color {
        switch type.lowercased() {
        case "todo": return .badgeTodo
        case "meeting": return .badgeMeeting
        case "email": return .badgeEmail
        default: return .badgeGeneral
        }
    }
}

// MARK: - Export Destination Button

struct ExportDestinationButton: View {
    let destination: ExportDestinationType
    let isConfigured: Bool
    let isExporting: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // Icon
                Image(systemName: destination.icon)
                    .font(.system(size: 24))
                    .foregroundColor(isConfigured ? .forestDark : .textLight)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(destination.name)
                        .font(.serifBody(16, weight: .semibold))
                        .foregroundColor(.textDark)

                    if isConfigured {
                        Text(destination.description)
                            .font(.serifCaption(12, weight: .regular))
                            .foregroundColor(.textMedium)
                    } else {
                        Text("Setup required")
                            .font(.serifCaption(12, weight: .medium))
                            .foregroundColor(.orange)
                    }
                }

                Spacer()

                if isConfigured {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.textLight)
                } else {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16))
                        .foregroundColor(.textLight)
                }
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(12)
            .opacity(isConfigured ? 1.0 : 0.7)
        }
        .disabled(!isConfigured || isExporting)
    }
}

// MARK: - Preview

#Preview {
    ExportSheet(note: {
        let context = CoreDataStack.shared.persistentContainer.viewContext
        let note = Note(context: context)
        note.content = "#todo# Test task list\n- Item 1\n- Item 2"
        note.noteType = "todo"
        note.createdAt = Date()
        return note
    }())
}
