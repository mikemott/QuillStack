import SwiftUI

struct TagChip: View {
    let name: String
    let colorHex: String
    var isSelected: Bool = false
    var action: (() -> Void)? = nil

    var body: some View {
        Text(name)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                isSelected
                    ? Color(hex: colorHex)
                    : Color(hex: colorHex).opacity(0.15)
            )
            .foregroundStyle(
                isSelected ? .white : Color(hex: colorHex)
            )
            .clipShape(Capsule())
            .onTapGesture { action?() }
    }
}
