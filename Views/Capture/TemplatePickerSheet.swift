//
//  TemplatePickerSheet.swift
//  QuillStack
//
//  Created on 2025-12-30.
//

import SwiftUI

/// Sheet for selecting a note template before capture
struct TemplatePickerSheet: View {
    @Binding var selectedTemplate: NoteTemplate
    @Environment(\.dismiss) private var dismiss
    let onSelect: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Choose a Template")
                        .font(.serifHeadline(24, weight: .bold))
                        .foregroundColor(.textDark)

                    Text("Templates guide your writing and improve OCR accuracy")
                        .font(.serifBody(14, weight: .regular))
                        .foregroundColor(.textMedium)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 8)

                // Template grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(NoteTemplate.allCases) { template in
                        TemplateCard(
                            template: template,
                            isSelected: selectedTemplate == template,
                            onTap: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedTemplate = template
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)

                Spacer()

                // Continue button
                Button(action: {
                    dismiss()
                    onSelect()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                        Text("Start Capture")
                    }
                    .font(.serifBody(17, weight: .semibold))
                    .foregroundColor(.forestLight)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color.forestDark, Color.forestMedium],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(Color.creamLight)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.forestDark)
                }
            }
        }
    }
}

// MARK: - Template Card

struct TemplateCard: View {
    let template: NoteTemplate
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(template.color.opacity(0.15))
                        .frame(width: 56, height: 56)

                    Image(systemName: template.icon)
                        .font(.system(size: 24))
                        .foregroundColor(template.color)
                }

                // Name
                Text(template.name)
                    .font(.serifBody(15, weight: .semibold))
                    .foregroundColor(.textDark)

                // Description
                Text(template.description)
                    .font(.serifCaption(11, weight: .regular))
                    .foregroundColor(.textMedium)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 160)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? template.color : Color.clear,
                        lineWidth: 3
                    )
            )
            .shadow(
                color: isSelected ? template.color.opacity(0.3) : .black.opacity(0.05),
                radius: isSelected ? 8 : 4,
                x: 0,
                y: isSelected ? 4 : 2
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

#Preview {
    TemplatePickerSheet(selectedTemplate: .constant(.meetingNotes)) {
        // On select
    }
}
