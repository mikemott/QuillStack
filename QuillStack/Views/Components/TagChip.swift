import SwiftUI
import SwiftData

struct TagChip: View {
    let tag: Tag
    /// Retained for API compatibility. Per STYLE_GUIDE.md: "All chips fully vibrant at all times (no dimming)"
    var isSelected: Bool = false
    var size: ChipSize = .regular
    var action: (() -> Void)? = nil

    enum ChipSize {
        case compact, regular, large

        var fontSize: CGFloat {
            switch self {
            case .compact: 8
            case .regular: 10
            case .large: 10
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .compact: 6
            case .regular: 10
            case .large: 12
            }
        }

        var verticalPadding: CGFloat {
            switch self {
            case .compact: 4
            case .regular: 6
            case .large: 6
            }
        }
    }

    private var chipColor: Color { Color(hex: tag.colorHex) }
    private var textColor: Color { tag.usesLightText ? .white : Color(hex: "#1a1c1c") }

    var body: some View {
        Text("#\(tag.name.uppercased())")
            .font(QSFont.mono(size: size.fontSize))
            .fontWeight(.bold)
            .tracking(1.5)
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .background(chipColor)
            .foregroundStyle(textColor)
            .contentShape(.rect)
            .onTapGesture { action?() }
            .allowsHitTesting(action != nil)
            .accessibilityIdentifier("tag-\(tag.name)")
    }
}
