//
//  BulkExportSheet.swift
//  QuillStack
//
//  Created on 2025-12-30.
//

import SwiftUI

/// Sheet for exporting multiple notes at once
struct BulkExportSheet: View {
    let notes: [Note]
    let onComplete: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var isExporting = false
    @State private var exportProgress: Double = 0
    @State private var exportResults: [ExportResult] = []
    @State private var showingResults = false
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
            .navigationTitle("Export \(notes.count) Notes")
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
                if showingResults {
                    resultsOverlay
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Export to")
                .font(.serifBody(15, weight: .medium))
                .foregroundColor(.textMedium)

            // Notes summary
            HStack(spacing: 12) {
                // Count badge
                Text("\(notes.count)")
                    .font(.serifHeadline(20, weight: .bold))
                    .foregroundColor(.forestDark)
                    .frame(width: 40, height: 40)
                    .background(Color.forestLight.opacity(0.3))
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 2) {
                    Text("note\(notes.count == 1 ? "" : "s") selected")
                        .font(.serifBody(14, weight: .medium))
                        .foregroundColor(.textDark)

                    // Type breakdown
                    let typeCounts = Dictionary(grouping: notes, by: { $0.noteType })
                    let summary = typeCounts.map { "\($0.value.count) \($0.key)" }.joined(separator: ", ")
                    Text(summary)
                        .font(.serifCaption(12, weight: .regular))
                        .foregroundColor(.textMedium)
                }

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
                        Text("Include original images")
                            .font(.serifBody(14, weight: .medium))
                            .foregroundColor(.textDark)
                        Text("Attach captured handwriting to each note")
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
                ProgressView(value: exportProgress, total: Double(notes.count))
                    .tint(.forestDark)
                    .frame(width: 200)

                Text("Exporting \(Int(exportProgress)) of \(notes.count)...")
                    .font(.serifBody(15, weight: .medium))
                    .foregroundColor(.textDark)
            }
            .padding(32)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(radius: 10)
        }
    }

    private var resultsOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                let successCount = exportResults.filter { $0.success }.count
                let failCount = exportResults.count - successCount

                if failCount == 0 {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                } else if successCount == 0 {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.red)
                } else {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                }

                Text(resultMessage(success: successCount, failed: failCount))
                    .font(.serifBody(15, weight: .medium))
                    .foregroundColor(.textDark)
                    .multilineTextAlignment(.center)

                Button("Done") {
                    dismiss()
                    onComplete()
                }
                .buttonStyle(.borderedProminent)
                .tint(.forestDark)
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
        exportProgress = 0
        exportResults = []

        Task {
            let options = ExportOptions(
                includeOriginalImage: includeImage,
                includeMetadata: true,
                openAfterExport: false
            )

            for (index, note) in notes.enumerated() {
                do {
                    let result = try await ExportService.shared.export(
                        note: note,
                        to: destination,
                        options: options
                    )
                    exportResults.append(result)
                } catch {
                    exportResults.append(.failure(destination: destination, message: error.localizedDescription))
                }

                await MainActor.run {
                    exportProgress = Double(index + 1)
                }
            }

            await MainActor.run {
                isExporting = false
                showingResults = true
            }
        }
    }

    private func resultMessage(success: Int, failed: Int) -> String {
        if failed == 0 {
            return "Successfully exported \(success) note\(success == 1 ? "" : "s")"
        } else if success == 0 {
            return "Failed to export \(failed) note\(failed == 1 ? "" : "s")"
        } else {
            return "Exported \(success) note\(success == 1 ? "" : "s")\n\(failed) failed"
        }
    }
}

#Preview {
    BulkExportSheet(notes: []) {
        // Complete
    }
}
