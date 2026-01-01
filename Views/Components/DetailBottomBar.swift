//
//  DetailBottomBar.swift
//  QuillStack
//
//  Architecture refactoring Phase 3: Shared bottom toolbar for detail views.
//  Consolidates common action buttons (AI, export, share, copy) with support
//  for type-specific primary actions.
//

import SwiftUI

// MARK: - Detail Action

/// Represents a custom action button in the bottom bar
struct DetailAction: Identifiable {
    let id = UUID()
    let icon: String
    let label: String?
    let color: Color
    let action: () -> Void

    /// Create an icon-only action
    init(icon: String, color: Color = .textDark, action: @escaping () -> Void) {
        self.icon = icon
        self.label = nil
        self.color = color
        self.action = action
    }

    /// Create an action with icon and label (for primary actions)
    init(icon: String, label: String, color: Color, action: @escaping () -> Void) {
        self.icon = icon
        self.label = label
        self.color = color
        self.action = action
    }
}

// MARK: - Detail Bottom Bar

/// Reusable bottom toolbar for note detail views.
/// Provides consistent styling and common actions across all note types.
///
/// Usage:
/// ```swift
/// DetailBottomBar(
///     onExport: { showingExportSheet = true },
///     onShare: { shareNote() },
///     onCopy: { copyContent() },
///     primaryAction: DetailAction(
///         icon: "bell.badge",
///         label: "Add to Reminders",
///         color: .badgeReminder
///     ) { showingRemindersSheet = true }
/// )
/// ```
struct DetailBottomBar: View {
    // MARK: - Properties

    /// Called when export button is tapped
    let onExport: (() -> Void)?

    /// Called when share button is tapped
    let onShare: (() -> Void)?

    /// Called when copy button is tapped
    let onCopy: () -> Void

    /// AI menu actions (shown if API key is configured)
    var aiActions: [AIAction]?

    /// Additional custom actions (between standard actions and primary)
    var customActions: [DetailAction]?

    /// Primary action button (styled prominently on the right)
    var primaryAction: DetailAction?

    /// Access to settings for API key check
    @ObservedObject private var settings = SettingsManager.shared

    // MARK: - Initialization

    init(
        onExport: (() -> Void)? = nil,
        onShare: (() -> Void)? = nil,
        onCopy: @escaping () -> Void,
        aiActions: [AIAction]? = nil,
        customActions: [DetailAction]? = nil,
        primaryAction: DetailAction? = nil
    ) {
        self.onExport = onExport
        self.onShare = onShare
        self.onCopy = onCopy
        self.aiActions = aiActions
        self.customActions = customActions
        self.primaryAction = primaryAction
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 20) {
            // AI menu (only if API key configured and actions provided)
            if settings.hasAPIKey, let actions = aiActions, !actions.isEmpty {
                aiMenu(actions: actions)
            }

            // Custom actions
            if let actions = customActions {
                ForEach(actions) { action in
                    actionButton(action)
                }
            }

            // Export button
            if let onExport = onExport {
                Button(action: onExport) {
                    Image(systemName: "arrow.up.doc")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.textDark)
                }
                .accessibilityLabel("Export note")
            }

            // Share button
            if let onShare = onShare {
                Button(action: onShare) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.textDark)
                }
                .accessibilityLabel("Share note")
            }

            // Copy button
            Button(action: onCopy) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.textDark)
            }
            .accessibilityLabel("Copy to clipboard")

            Spacer()

            // Primary action (prominent styling)
            if let primary = primaryAction {
                primaryActionButton(primary)
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

    // MARK: - Subviews

    private func aiMenu(actions: [AIAction]) -> some View {
        Menu {
            ForEach(actions) { action in
                Button(action: action.action) {
                    Label(action.label, systemImage: action.icon)
                }
            }
        } label: {
            Image(systemName: "sparkles")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.forestDark)
        }
        .accessibilityLabel("AI actions")
    }

    private func actionButton(_ action: DetailAction) -> some View {
        Button(action: action.action) {
            Image(systemName: action.icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(action.color)
        }
    }

    private func primaryActionButton(_ action: DetailAction) -> some View {
        Button(action: action.action) {
            if let label = action.label {
                // Icon + label style
                HStack(spacing: 6) {
                    Image(systemName: action.icon)
                        .font(.system(size: 16, weight: .semibold))
                    Text(label)
                        .font(.serifBody(14, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [action.color, action.color.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(10)
            } else {
                // Icon-only style
                Image(systemName: action.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        LinearGradient(
                            colors: [action.color, action.color.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(10)
            }
        }
        .accessibilityLabel(action.label ?? "Primary action")
    }
}

// MARK: - AI Action

/// Represents an AI-powered action in the sparkles menu
struct AIAction: Identifiable {
    let id = UUID()
    let icon: String
    let label: String
    let action: () -> Void

    init(icon: String, label: String, action: @escaping () -> Void) {
        self.icon = icon
        self.label = label
        self.action = action
    }
}

// MARK: - Convenience Initializers

extension DetailBottomBar {
    /// Standard AI actions for most note types
    static func standardAIActions(
        onEnhance: @escaping () -> Void,
        onSummarize: @escaping () -> Void
    ) -> [AIAction] {
        [
            AIAction(icon: "wand.and.stars", label: "Enhance Text", action: onEnhance),
            AIAction(icon: "text.quote", label: "Summarize", action: onSummarize)
        ]
    }

    /// Summarize-only AI action
    static func summarizeOnlyAIActions(
        onSummarize: @escaping () -> Void
    ) -> [AIAction] {
        [
            AIAction(icon: "text.quote", label: "Summarize", action: onSummarize)
        ]
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Spacer()

        DetailBottomBar(
            onExport: { print("Export") },
            onShare: { print("Share") },
            onCopy: { print("Copy") },
            aiActions: [
                AIAction(icon: "wand.and.stars", label: "Enhance", action: {}),
                AIAction(icon: "text.quote", label: "Summarize", action: {})
            ],
            primaryAction: DetailAction(
                icon: "bell.badge",
                label: "Add to Reminders",
                color: .badgeReminder
            ) { print("Primary") }
        )
    }
    .background(Color.paperBeige)
}
