import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Capture.createdAt, order: .reverse) private var captures: [Capture]
    @Query(sort: \Tag.name) private var tags: [Tag]
    @State private var selectedTag: Tag?
    @State private var showCamera = false
    @State private var searchText = ""
    @State private var isDrawerMode = false
    @State private var currentIndex = 0
    @State private var shareItem: ShareableCapture?
    @State private var showSearch = false
    @FocusState private var searchFocused: Bool
    private var vlmStatus = VLMStatus.shared

    private var filteredCaptures: [Capture] {
        var result = captures
        if let tag = selectedTag {
            result = result.filter { $0.tags.contains(where: { $0.id == tag.id }) }
        }
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { capture in
                (capture.extractedTitle?.lowercased().contains(query) ?? false)
                || (capture.ocrText?.lowercased().contains(query) ?? false)
                || (capture.enrichment?.summary.lowercased().contains(query) ?? false)
                || (capture.locationName?.lowercased().contains(query) ?? false)
                || capture.tags.contains(where: { $0.name.lowercased().contains(query) })
            }
        }
        return result
    }

    private var groupedByDate: [(date: Date, captures: [Capture])] {
        let grouped = Dictionary(grouping: filteredCaptures) { $0.createdAt.startOfDay }
        return grouped
            .sorted { $0.key > $1.key }
            .map { (date: $0.key, captures: $0.value) }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                // Base layer — deepest surface
                QSSurface.base.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    HStack(alignment: .center) {
                        Text("QUILLSTACK")
                            .font(.system(size: 26, weight: .black, design: .default))
                            .tracking(8)
                            .foregroundStyle(QSColor.primary)
                            .shadow(color: QSColor.primary.opacity(0.20), radius: 20, x: 0, y: 0)
                            .shadow(color: QSColor.primary.opacity(0.08), radius: 50, x: 0, y: 0)

                        Spacer()

                        HStack(spacing: 18) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isDrawerMode.toggle()
                                }
                            } label: {
                                Image(systemName: isDrawerMode ? "rectangle.stack" : "square.grid.2x2")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(QSColor.onSurfaceMuted)
                            }
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showSearch.toggle()
                                    if showSearch { searchFocused = true }
                                }
                            } label: {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(QSColor.onSurfaceMuted)
                            }
                            NavigationLink(destination: SettingsView()) {
                                Image(systemName: "gearshape")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(QSColor.onSurfaceMuted)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    .background(QSSurface.base)

                    vlmStatusBar

                    // Search field (expandable)
                    if showSearch {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 14))
                                .foregroundStyle(QSColor.onSurfaceMuted)
                            TextField("Search captures", text: $searchText)
                                .font(QSFont.sans(size: 15))
                                .foregroundStyle(QSColor.onSurface)
                                .focused($searchFocused)
                            if !searchText.isEmpty {
                                Button {
                                    searchText = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(QSColor.onSurfaceMuted)
                                }
                            }
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showSearch = false
                                    searchText = ""
                                    searchFocused = false
                                }
                            } label: {
                                Text("Cancel")
                                    .font(QSFont.sans(size: 14))
                                    .foregroundStyle(QSColor.onSurfaceMuted)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(QSSurface.container)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Tag filter
                    tagFilterBar

                    if isDrawerMode {
                        drawerView
                            .transition(.opacity)
                    } else {
                        cardPagerView
                            .transition(.opacity)
                    }
                }

                captureButton
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .fullScreenCover(isPresented: $showCamera) {
                CaptureFlowView()
            }
            .sheet(item: $shareItem) { item in
                ActivityView(activityItems: item.activityItems)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - VLM Status Bar

    @ViewBuilder
    private var vlmStatusBar: some View {
        switch vlmStatus.state {
        case .idle:
            EmptyView()
        case .downloading(let progress):
            VStack(spacing: 4) {
                HStack {
                    Text("Downloading model")
                        .font(QSFont.mono(size: 11))
                        .foregroundStyle(QSColor.onSurfaceMuted)
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(QSFont.mono(size: 11))
                        .foregroundStyle(QSColor.onSurfaceMuted)
                }
                ProgressView(value: progress)
                    .tint(QSColor.primary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(QSSurface.containerLow)
        case .loading:
            HStack {
                Text("Loading model")
                    .font(QSFont.mono(size: 11))
                    .foregroundStyle(QSColor.onSurfaceMuted)
                Spacer()
                ProgressView()
                    .controlSize(.small)
                    .tint(QSColor.onSurfaceMuted)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(QSSurface.containerLow)
        case .ready, .failed:
            EmptyView()
        }
    }

    // MARK: - Tag Filter Bar
    // Tonal step: containerLow sits above base, creating structural boundary without a line

    private var tagFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(tags.sorted { $0.captureCount > $1.captureCount }) { tag in
                    let isActive = selectedTag?.id == tag.id
                    let isVisible = selectedTag == nil || isActive

                    if isVisible {
                        TagChip(
                            tag: tag,
                            isSelected: isActive,
                            size: .large
                        ) {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                selectedTag = isActive ? nil : tag
                            }
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(QSSurface.containerLow)
    }

    // MARK: - Card Pager

    private var cardPagerView: some View {
        GeometryReader { geo in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(filteredCaptures.enumerated()), id: \.element.id) { index, capture in
                        NavigationLink(destination: CaptureDetailView(capture: capture)) {
                            CaptureCard(capture: capture) {
                                shareCapture(capture)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 8)
                            .frame(height: geo.size.height * 0.90)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
        }
    }

    // MARK: - Drawer View

    private var drawerView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20, pinnedViews: [.sectionHeaders]) {
                ForEach(groupedByDate, id: \.date) { group in
                    Section {
                        LazyVStack(spacing: 12) {
                            ForEach(group.captures) { capture in
                                NavigationLink(destination: CaptureDetailView(capture: capture)) {
                                    drawerCard(capture)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                    } header: {
                        drawerDateHeader(group.date, count: group.captures.count)
                    }
                }
            }
            .padding(.bottom, 100)
        }
    }

    private func drawerDateHeader(_ date: Date, count: Int) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(date.timelineHeader)
                .font(QSFont.dateHeader)
                .foregroundStyle(QSColor.onSurface)
            Spacer()
            Text("\(count)")
                .font(QSFont.dateHeaderCount)
                .foregroundStyle(QSColor.onSurfaceMuted)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(QSSurface.base)
    }

    private func drawerCard(_ capture: Capture) -> some View {
        HStack(spacing: 12) {
            // Thumbnail
            if let data = capture.thumbnail, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(QSSurface.container)
                    .frame(width: 72, height: 72)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.system(size: 16))
                            .foregroundStyle(QSColor.onSurfaceMuted.opacity(0.3))
                    }
            }

            // Metadata
            VStack(alignment: .leading, spacing: 4) {
                if let title = capture.extractedTitle {
                    Text(title)
                        .font(QSFont.sansMedium(size: 14))
                        .foregroundStyle(QSColor.onSurface)
                        .lineLimit(1)
                }

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 8))
                    Text(capture.createdAt.cardTimestamp)
                        .font(QSFont.mono(size: 10))
                }
                .foregroundStyle(QSColor.onSurfaceMuted)

                if let location = capture.locationName {
                    HStack(spacing: 4) {
                        Image(systemName: "location")
                            .font(.system(size: 8))
                        Text(location)
                            .font(QSFont.mono(size: 10))
                            .lineLimit(1)
                    }
                    .foregroundStyle(QSColor.onSurfaceMuted)
                }

                if !capture.tags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(capture.tags.prefix(3)) { tag in
                            TagChip(tag: tag, size: .compact)
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(QSSurface.containerHigh)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: - Sharing

    private func shareCapture(_ capture: Capture) {
        guard let data = capture.sortedImages.first?.imageData,
              let image = UIImage(data: data) else { return }
        shareItem = ShareableCapture(image: image, title: capture.extractedTitle)
    }

    // MARK: - Capture Button

    private var captureButton: some View {
        Button {
            showCamera = true
        } label: {
            Image(systemName: "camera.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(QSColor.onPrimaryDark)
                .frame(width: 64, height: 64)
                .background(QSColor.primary)
                .clipShape(Circle())
                .shadow(color: QSColor.primary.opacity(0.25), radius: 12, x: 0, y: 4)
                .shadow(color: QSColor.primary.opacity(0.08), radius: 30, x: 0, y: 6)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 28)
    }
}

// MARK: - Share Support

struct ShareableCapture: Identifiable {
    let id = UUID()
    let image: UIImage
    let title: String?

    var activityItems: [Any] {
        var items: [Any] = [image]
        if let title { items.insert(title, at: 0) }
        return items
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
