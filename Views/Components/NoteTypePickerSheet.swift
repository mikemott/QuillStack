//
//  NoteTypePickerSheet.swift
//  QuillStack
//
//  Phase 1.5: Change Type Button and Picker
//  Allows users to manually correct note classification.
//

import SwiftUI
import CoreData

/// Sheet for manually changing a note's type
/// Tracks the original type for classification improvement
struct NoteTypePickerSheet: View {
    @ObservedObject var note: Note
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    @State private var selectedType: NoteType

    init(note: Note) {
        self.note = note
        _selectedType = State(initialValue: note.type)
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.creamLight.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Header explanation
                        headerSection

                        // Type selection grid
                        typeSelectionGrid

                        // Current classification info
                        if let method = note.classificationMethod,
                           method != "manual" {
                            classificationInfoSection
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Change Note Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveTypeChange()
                    }
                    .fontWeight(.semibold)
                    .disabled(selectedType == note.type)
                }
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.left.arrow.right.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.forestMedium)

            Text("Select the correct note type")
                .font(.serifBody(16, weight: .medium))
                .foregroundColor(.textDark)
                .multilineTextAlignment(.center)

            Text("Your corrections help improve automatic classification")
                .font(.serifCaption(13, weight: .regular))
                .foregroundColor(.textMedium)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    @MainActor
    private var typeSelectionGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            ForEach(NoteType.allCases, id: \.self) { type in
                TypeSelectionCard(
                    type: type,
                    isSelected: selectedType == type,
                    onTap: { selectedType = type }
                )
            }
        }
    }

    private var classificationInfoSection: some View {
        VStack(spacing: 8) {
            Divider()
                .padding(.vertical, 8)

            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.textMedium)

                Text("Originally classified as")
                    .font(.serifCaption(12, weight: .regular))
                    .foregroundColor(.textMedium)

                Spacer()

                Text(note.type.displayName)
                    .font(.serifCaption(12, weight: .semibold))
                    .foregroundColor(.forestMedium)

                if note.classificationConfidence > 0 {
                    Text("(\(Int(note.classificationConfidence * 100))%)")
                        .font(.serifCaption(12, weight: .regular))
                        .foregroundColor(.textMedium)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.forestLight.opacity(0.1))
            .cornerRadius(8)
        }
    }

    // MARK: - Actions

    private func saveTypeChange() {
        let originalType = note.type
        let originalMethod = note.classificationMethodEnum ?? .default
        let originalConfidence = note.classificationConfidence

        // Store original type if not already set (for correction tracking)
        if note.originalClassificationType == nil {
            note.originalClassificationType = note.noteType
        }

        // Update note type
        note.type = selectedType
        note.classificationMethod = "manual"
        note.classificationConfidence = 1.0
        note.updatedAt = Date()

        // Save to Core Data
        do {
            try viewContext.save()

            // Log the correction for analytics
            ClassificationAnalytics.shared.logCorrection(
                note: note,
                originalType: originalType,
                correctedType: selectedType,
                originalMethod: originalMethod,
                originalConfidence: originalConfidence
            )

            dismiss()
        } catch {
            print("Error saving note type change: \(error)")
        }
    }
}

// MARK: - Type Selection Card

@MainActor
struct TypeSelectionCard: View {
    let type: NoteType
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // Icon
                Image(systemName: type.icon)
                    .font(.system(size: 28))
                    .foregroundColor(isSelected ? .white : type.badgeColor)
                    .frame(height: 36)

                // Label
                Text(type.displayName)
                    .font(.serifBody(14, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .textDark)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? type.badgeColor : Color.white)
                    .shadow(
                        color: isSelected ? type.badgeColor.opacity(0.3) : Color.black.opacity(0.08),
                        radius: isSelected ? 8 : 4,
                        x: 0,
                        y: 2
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? type.badgeColor : Color.clear,
                        lineWidth: isSelected ? 2 : 0
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    PreviewWrapper()
}

fileprivate struct PreviewWrapper: View {
    let note: Note = {
        let n = Note()
        n.noteType = "contact"
        n.classificationConfidence = 0.85
        n.classificationMethod = "llm"
        return n
    }()

    var body: some View {
        NoteTypePickerSheet(note: note)
    }
}
