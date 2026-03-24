import SwiftUI

struct ActionIcon: View {
    let systemName: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(QSSurface.base.opacity(0.80))
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(tint.opacity(0.35), lineWidth: 1)
                )
                .shadow(color: tint.opacity(0.25), radius: 8, x: 0, y: 2)
        }
    }
}

struct ActionIconStack: View {
    let capture: Capture

    var availableActions: [(icon: String, tag: String, color: Color)] {
        var actions: [(String, String, Color)] = []
        let tagsByName = Dictionary(uniqueKeysWithValues: capture.tags.map { ($0.name, $0) })
        let enrichment = capture.enrichment

        if let tag = tagsByName["Contact"], enrichment?.contact != nil {
            actions.append(("person.crop.circle.badge.plus", "Contact", Color(hex: tag.colorHex)))
        }
        if let tag = tagsByName["Event"], enrichment?.event != nil {
            actions.append(("calendar.badge.plus", "Event", Color(hex: tag.colorHex)))
        }
        if let tag = tagsByName["Receipt"], enrichment?.receipt != nil {
            actions.append(("doc.text", "Receipt", Color(hex: tag.colorHex)))
        }
        return actions
    }

    var showIcons: Bool {
        !capture.isProcessingOCR && !availableActions.isEmpty
    }

    var onAction: ((String) -> Void)?

    var body: some View {
        if showIcons {
            VStack(spacing: 8) {
                ForEach(availableActions, id: \.tag) { action in
                    ActionIcon(systemName: action.icon, tint: action.color) {
                        onAction?(action.tag)
                    }
                }
            }
        }
    }
}
