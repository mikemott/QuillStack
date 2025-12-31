//
//  TemplateOverlayView.swift
//  QuillStack
//
//  Created on 2025-12-30.
//

import SwiftUI

/// Semi-transparent overlay showing template structure guides on camera preview
struct TemplateOverlayView: View {
    let template: NoteTemplate

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Semi-transparent background for guide visibility
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.3))
                    .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 0) {
                    // Template hashtag at top
                    if let hashtag = template.triggerHashtag {
                        HStack {
                            Text(hashtag)
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.forestLight)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.forestDark.opacity(0.7))
                                .cornerRadius(4)

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    }

                    // Guide sections
                    if !template.guideSections.isEmpty {
                        VStack(alignment: .leading, spacing: sectionSpacing(for: geometry.size.height)) {
                            ForEach(template.guideSections) { section in
                                TemplateSectionGuide(section: section)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                    }

                    Spacer()
                }
            }
        }
    }

    private func sectionSpacing(for height: CGFloat) -> CGFloat {
        let sections = template.guideSections.count
        guard sections > 1 else { return 0 }

        // Calculate spacing to distribute sections evenly
        let availableHeight = height - 80 // Account for padding and hashtag
        let sectionHeight: CGFloat = 60
        let totalSectionHeight = CGFloat(sections) * sectionHeight
        let spacing = (availableHeight - totalSectionHeight) / CGFloat(sections)

        return max(16, min(spacing, 40))
    }
}

// MARK: - Section Guide

struct TemplateSectionGuide: View {
    let section: TemplateSection

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Label
            Text(section.label)
                .font(.system(size: 13, weight: .semibold, design: .default))
                .foregroundColor(.forestLight)
                .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)

            // Placeholder line
            HStack(spacing: 8) {
                Text(section.placeholder)
                    .font(.system(size: 11, weight: .regular, design: .default))
                    .foregroundColor(.forestLight.opacity(0.6))
                    .italic()

                // Dashed line extending to edge
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: 1)
                    .background(
                        GeometryReader { geo in
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: 0.5))
                                path.addLine(to: CGPoint(x: geo.size.width, y: 0.5))
                            }
                            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                            .foregroundColor(.forestLight.opacity(0.4))
                        }
                    )
            }
        }
    }
}

// MARK: - Compact Badge (for camera header)

struct TemplateBadge: View {
    let template: NoteTemplate
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: template.icon)
                    .font(.system(size: 12, weight: .semibold))

                Text(template.name)
                    .font(.serifCaption(12, weight: .semibold))

                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(.forestLight)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(template.color.opacity(0.3))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(template.color.opacity(0.5), lineWidth: 1)
            )
            .cornerRadius(8)
        }
    }
}

#Preview("Meeting Notes Template") {
    ZStack {
        Color.gray
        TemplateOverlayView(template: .meetingNotes)
            .frame(width: 300, height: 400)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview("Daily Todo Template") {
    ZStack {
        Color.gray
        TemplateOverlayView(template: .dailyTodo)
            .frame(width: 300, height: 400)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
