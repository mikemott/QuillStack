import SwiftUI

struct AITagChip: View {
    let label: String

    var body: some View {
        Text(label.lowercased())
            .font(QSFont.mono(size: 9))
            .fontWeight(.medium)
            .tracking(1.0)
            .foregroundStyle(QSColor.onSurfaceMuted)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .overlay(
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .strokeBorder(QSColor.onSurfaceMuted.opacity(0.25), lineWidth: 1)
            )
    }
}
