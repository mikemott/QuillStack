import SwiftUI
import SwiftData

struct TagToast: View {
    @Query(sort: \Tag.name) private var allTags: [Tag]
    @Bindable var capture: Capture
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("TAG THIS CAPTURE")
                    .font(QSFont.sectionHeader)
                    .tracking(2)
                    .foregroundStyle(QSColor.onSurfaceMuted)

                Spacer()

                Button {
                    onDismiss()
                } label: {
                    Text("DONE")
                        .font(QSFont.sectionHeader)
                        .tracking(1.5)
                        .foregroundStyle(QSColor.tertiary)
                }
            }

            FlowLayout(spacing: 8) {
                ForEach(allTags.sorted(by: { $0.captureCount > $1.captureCount })) { tag in
                    TagChip(
                        tag: tag,
                        isSelected: capture.tags.contains(where: { $0.id == tag.id }),
                        size: .regular
                    ) {
                        toggleTag(tag)
                    }
                }
            }
        }
        .padding(16)
        .background(QSSurface.containerHigh)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .qsAmbientShadow(radius: 30, opacity: 0.15)
        .padding(.horizontal, 16)
    }

    private func toggleTag(_ tag: Tag) {
        withAnimation(.easeInOut(duration: 0.15)) {
            if let index = capture.tags.firstIndex(where: { $0.id == tag.id }) {
                capture.tags.remove(at: index)
            } else {
                capture.tags.append(tag)
            }
        }
    }
}
