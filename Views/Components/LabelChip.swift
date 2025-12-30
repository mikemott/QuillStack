//
//  LabelChip.swift
//  QuillStack
//
//  Created on 2025-12-30.
//

import SwiftUI

/// A selectable chip for GitHub issue labels
struct LabelChip: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                }

                Text(label)
                    .font(.serifCaption(13, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? labelColor.opacity(0.2) : Color.gray.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? labelColor : Color.gray.opacity(0.3), lineWidth: 1.5)
            )
            .foregroundColor(isSelected ? labelColor : .textMedium)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    /// Returns a color based on the label type (matching GitHub conventions)
    private var labelColor: Color {
        switch label.lowercased() {
        case "enhancement":
            return Color(red: 0.63, green: 0.53, blue: 0.94) // Purple
        case "bug":
            return Color(red: 0.85, green: 0.26, blue: 0.34) // Red
        case "documentation":
            return Color(red: 0.0, green: 0.45, blue: 0.79) // Blue
        case "ui":
            return Color(red: 0.54, green: 0.17, blue: 0.89) // Violet
        case "performance":
            return Color(red: 0.98, green: 0.65, blue: 0.0) // Orange
        case "refactor":
            return Color(red: 0.99, green: 0.92, blue: 0.24) // Yellow
        case "security":
            return Color(red: 0.85, green: 0.0, blue: 0.0) // Dark red
        case "testing":
            return Color(red: 0.0, green: 0.64, blue: 0.53) // Teal
        case "help wanted":
            return Color(red: 0.0, green: 0.55, blue: 0.0) // Green
        case "good first issue":
            return Color(red: 0.49, green: 0.31, blue: 0.64) // Magenta
        default:
            return .forestDark
        }
    }
}

// MARK: - Multi-Select Label Container

/// A container view for selecting multiple labels
struct LabelSelector: View {
    let availableLabels: [String]
    @Binding var selectedLabels: Set<String>

    var body: some View {
        FlowLayout(spacing: 8, verticalSpacing: 10) {
            ForEach(availableLabels, id: \.self) { label in
                LabelChip(
                    label: label,
                    isSelected: selectedLabels.contains(label)
                ) {
                    toggleLabel(label)
                }
            }
        }
    }

    private func toggleLabel(_ label: String) {
        if selectedLabels.contains(label) {
            selectedLabels.remove(label)
        } else {
            selectedLabels.insert(label)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(alignment: .leading, spacing: 24) {
        Text("Label Chips")
            .font(.headline)

        // Individual chips
        HStack {
            LabelChip(label: "enhancement", isSelected: true) { }
            LabelChip(label: "bug", isSelected: false) { }
            LabelChip(label: "documentation", isSelected: true) { }
        }

        Divider()

        // Selector demo
        Text("Label Selector")
            .font(.headline)

        LabelSelectorPreview()
    }
    .padding()
}

private struct LabelSelectorPreview: View {
    @State private var selected: Set<String> = ["enhancement"]

    var body: some View {
        LabelSelector(
            availableLabels: ["enhancement", "bug", "documentation", "ui", "performance", "refactor"],
            selectedLabels: $selected
        )
    }
}
