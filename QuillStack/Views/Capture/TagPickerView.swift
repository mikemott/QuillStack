import SwiftUI
import SwiftData

struct TagPickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tag.name) private var allTags: [Tag]
    @Binding var selectedTags: [Tag]
    @State private var showNewTag = false
    @State private var newTagName = ""
    @State private var newTagColor = "#6B7280"

    private var frequentTags: [Tag] {
        allTags
            .sorted { $0.captureCount > $1.captureCount }
            .prefix(5)
            .sorted { $0.name < $1.name }
            .map { $0 }
    }

    private var remainingTags: [Tag] {
        let frequentIDs = Set(frequentTags.map(\.id))
        return allTags.filter { !frequentIDs.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Quick access row
            if !frequentTags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick Tags")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(frequentTags) { tag in
                                TagChip(
                                    name: tag.name,
                                    colorHex: tag.colorHex,
                                    isSelected: isSelected(tag)
                                ) {
                                    toggle(tag)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }

            // All tags
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("All Tags")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        showNewTag = true
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)

                FlowLayout(spacing: 8) {
                    ForEach(remainingTags) { tag in
                        TagChip(
                            name: tag.name,
                            colorHex: tag.colorHex,
                            isSelected: isSelected(tag)
                        ) {
                            toggle(tag)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .alert("New Tag", isPresented: $showNewTag) {
            TextField("Tag name", text: $newTagName)
            Button("Cancel", role: .cancel) { newTagName = "" }
            Button("Create") { createTag() }
        } message: {
            Text("Choose a short, reusable name.")
        }
    }

    private func isSelected(_ tag: Tag) -> Bool {
        selectedTags.contains(where: { $0.id == tag.id })
    }

    private func toggle(_ tag: Tag) {
        withAnimation(.easeInOut(duration: 0.15)) {
            if let index = selectedTags.firstIndex(where: { $0.id == tag.id }) {
                selectedTags.remove(at: index)
            } else {
                selectedTags.append(tag)
            }
        }
    }

    private func createTag() {
        let name = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        guard !allTags.contains(where: { $0.name.lowercased() == name.lowercased() }) else {
            newTagName = ""
            return
        }
        let tag = Tag(name: name, colorHex: newTagColor)
        modelContext.insert(tag)
        selectedTags.append(tag)
        newTagName = ""
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (positions, CGSize(width: maxWidth, height: y + rowHeight))
    }
}
