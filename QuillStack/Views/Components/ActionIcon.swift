import SwiftUI

struct ActionIcon: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(QSColor.onSurfaceVariant)
                .frame(width: 40, height: 40)
                .background(QSSurface.base.opacity(0.70))
                .background(.ultraThinMaterial.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
    }
}

struct ActionIconStack: View {
    let capture: Capture

    var availableActions: [(icon: String, tag: String)] {
        var actions: [(String, String)] = []
        let tagNames = Set(capture.tags.map(\.name))
        let enrichment = capture.enrichment

        if tagNames.contains("Contact"), enrichment?.contact != nil {
            actions.append(("person.crop.circle.badge.plus", "Contact"))
        }
        if tagNames.contains("Event"), enrichment?.event != nil {
            actions.append(("calendar.badge.plus", "Event"))
        }
        if tagNames.contains("Receipt"), enrichment?.receipt != nil {
            actions.append(("doc.text", "Receipt"))
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
                    ActionIcon(systemName: action.icon) {
                        onAction?(action.tag)
                    }
                }
            }
        }
    }
}
