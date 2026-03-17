import SwiftUI
import SwiftData

struct CaptureCard: View {
    let capture: Capture

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .topTrailing) {
                thumbnailImage
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fill)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(borderColor, lineWidth: 2)
                    )

                if capture.isStack {
                    Text("\(capture.pageCount)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(6)
                }
            }

            if let title = capture.extractedTitle {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var thumbnailImage: some View {
        if let data = capture.thumbnail, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            Rectangle()
                .fill(Color(.systemGray5))
                .overlay {
                    Image(systemName: "photo")
                        .foregroundStyle(.quaternary)
                }
        }
    }

    private var borderColor: Color {
        if let tag = capture.primaryTag {
            return Color(hex: tag.colorHex)
        }
        return .clear
    }
}
