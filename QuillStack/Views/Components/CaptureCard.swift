import SwiftUI
import SwiftData

struct CaptureCard: View {
    let capture: Capture
    var onShare: (() -> Void)? = nil
    var onAction: ((String) -> Void)? = nil

    var body: some View {
        GeometryReader { geo in
            let imageHeight = geo.size.height * 0.58
            VStack(spacing: 0) {
                // Image section
                ZStack {
                    thumbnailImage(width: geo.size.width, height: imageHeight)

                    // Share + quick actions (top-right, vertical)
                    VStack(spacing: 8) {
                        if onShare != nil {
                            Button {
                                onShare?()
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(QSColor.onPrimaryDark)
                                    .frame(width: 44, height: 44)
                                    .background(QSColor.primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
                            }
                        }

                        ActionIconStack(capture: capture) { tag in
                            onAction?(tag)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(14)
                }

                // Metadata — glass & gradient recipe from the design doc
                metadataArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .qsGlass(
                        glow: QSColor.tertiaryDim,
                        center: .topLeading,
                        intensity: 0.20,
                        surfaceOpacity: 0.65
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .qsAmbientShadow(radius: 50, opacity: 0.10)
        }
    }

    // MARK: - Metadata

    private var metadataArea: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title
            if let title = capture.extractedTitle {
                Text(title)
                    .font(QSFont.cardTitle)
                    .foregroundStyle(QSColor.onSurface)
                    .lineLimit(2)
                    .padding(.bottom, 4)
            }

            // Timestamp — Plex Mono for data
            HStack(spacing: 5) {
                Image(systemName: "clock")
                    .font(.system(size: 9))
                Text(capture.createdAt.cardDetailTimestamp)
                    .font(QSFont.cardTimestamp)
            }
            .foregroundStyle(QSColor.onSurfaceMuted)
            .padding(.bottom, 16)

            // Tags — generous spacing between them
            if !capture.tags.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(capture.tags) { tag in
                        TagChip(tag: tag, isSelected: true)
                    }
                }
                .padding(.bottom, capture.enrichment?.aiTags.isEmpty == false ? 8 : 16)
            }

            // AI topic tags
            if let aiTags = capture.enrichment?.aiTags, !aiTags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(aiTags, id: \.self) { tag in
                        AITagChip(label: tag)
                    }
                }
                .padding(.bottom, 16)
            }

            // Bottom row: location + stack info
            HStack(alignment: .bottom) {
                if let location = capture.locationName {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("LOCATION")
                            .font(QSFont.cardLabel)
                            .tracking(1.8)
                            .foregroundStyle(QSColor.onSurfaceMuted)
                        Text(location)
                            .font(QSFont.cardBody)
                            .foregroundStyle(QSColor.onSurfaceVariant)
                    }
                }

                Spacer(minLength: 12)

                if capture.isStack {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc.fill")
                            .font(.system(size: 10))
                        Text("\(capture.pageCount) pages")
                            .font(QSFont.cardPageCount)
                    }
                    .foregroundStyle(QSColor.onSurfaceMuted)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
    }

    // MARK: - Thumbnail

    private func thumbnailImage(width: CGFloat, height: CGFloat) -> some View {
        Group {
            if let data = capture.thumbnail, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipped()
            } else {
                Rectangle()
                    .fill(QSSurface.container)
                    .frame(width: width, height: height)
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "photo")
                                .font(.system(size: 36, weight: .ultraLight))
                            Text("NO IMAGE")
                                .font(QSFont.cardLabel)
                                .tracking(2)
                        }
                        .foregroundStyle(QSColor.onSurfaceMuted.opacity(0.3))
                    }
            }
        }
    }
}
