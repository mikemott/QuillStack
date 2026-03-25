import SwiftUI

struct ActionIcon: View {
    let systemName: String
    let backgroundColor: Color
    let foregroundColor: Color
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var glowing = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(foregroundColor)
                .frame(width: 44, height: 44)
                .background(backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                glowing = true
            }
        }
    }
}

struct ActionIconStack: View {
    let capture: Capture

    var availableActions: [(icon: String, tagName: String, bgColor: Color, fgColor: Color)] {
        var actions: [(String, String, Color, Color)] = []
        let tagsByName = Dictionary(uniqueKeysWithValues: capture.tags.map { ($0.name, $0) })
        let enrichment = capture.enrichment

        if let tag = tagsByName["Contact"], enrichment?.contact != nil {
            actions.append(("person.crop.circle.badge.plus", "Contact", Color(hex: tag.colorHex), tag.usesLightText ? .white : Color(hex: "#1a1c1c")))
        }
        if let tag = tagsByName["Event"], enrichment?.event != nil {
            actions.append(("calendar.badge.plus", "Event", Color(hex: tag.colorHex), tag.usesLightText ? .white : Color(hex: "#1a1c1c")))
        }
        if let tag = tagsByName["Receipt"], enrichment?.receipt != nil {
            actions.append(("doc.text", "Receipt", Color(hex: tag.colorHex), tag.usesLightText ? .white : Color(hex: "#1a1c1c")))
        }
        if let tag = tagsByName["To-Do"], enrichment?.todo != nil {
            actions.append(("checklist", "To-Do", Color(hex: tag.colorHex), tag.usesLightText ? .white : Color(hex: "#1a1c1c")))
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
                ForEach(availableActions, id: \.tagName) { action in
                    ActionIcon(systemName: action.icon, backgroundColor: action.bgColor, foregroundColor: action.fgColor) {
                        onAction?(action.tagName)
                    }
                }
            }
        }
    }
}
