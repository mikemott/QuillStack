//
//  FlowLayout.swift
//  QuillStack
//
//  A flexible flow layout that wraps content horizontally.
//

import SwiftUI

struct FlowLayout<Content: View>: View {
    let spacing: CGFloat
    let verticalSpacing: CGFloat
    let content: () -> Content

    init(spacing: CGFloat = 8, verticalSpacing: CGFloat? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.verticalSpacing = verticalSpacing ?? spacing
        self.content = content
    }

    var body: some View {
        GeometryReader { geometry in
            self.generateContent(in: geometry)
        }
    }

    private func generateContent(in geometry: GeometryProxy) -> some View {
        var width: CGFloat = 0
        var height: CGFloat = 0
        var lastHeight: CGFloat = 0

        let items = content().asCollection()

        return ZStack(alignment: .topLeading) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                item
                    .alignmentGuide(.leading) { dimension in
                        if abs(width - dimension.width) > geometry.size.width {
                            width = 0
                            height -= lastHeight + verticalSpacing
                        }
                        let result = width
                        if index == items.count - 1 {
                            width = 0
                        } else {
                            width -= dimension.width + spacing
                        }
                        return result
                    }
                    .alignmentGuide(.top) { dimension in
                        let result = height
                        if index == items.count - 1 {
                            height = 0
                        }
                        lastHeight = dimension.height
                        return result
                    }
            }
        }
        .frame(height: calculateHeight(in: geometry))
    }

    private func calculateHeight(in geometry: GeometryProxy) -> CGFloat {
        var width: CGFloat = 0
        var height: CGFloat = 0
        var lineHeight: CGFloat = 0

        let items = content().asCollection()

        for item in items {
            let itemSize = item.measure(in: geometry.size)

            if width + itemSize.width > geometry.size.width && width > 0 {
                width = 0
                height += lineHeight + verticalSpacing
                lineHeight = 0
            }

            width += itemSize.width + spacing
            lineHeight = max(lineHeight, itemSize.height)
        }

        return height + lineHeight
    }
}

// Helper extensions
extension View {
    func asCollection() -> [AnyView] {
        return [AnyView(self)]
    }

    func measure(in size: CGSize) -> CGSize {
        let hosting = UIHostingController(rootView: self)
        let targetSize = CGSize(width: size.width, height: UIView.layoutFittingCompressedSize.height)
        hosting.view.setNeedsLayout()
        hosting.view.layoutIfNeeded()
        let measuredSize = hosting.view.systemLayoutSizeFitting(
            targetSize,
            withHorizontalFittingPriority: .fittingSizeLevel,
            verticalFittingPriority: .fittingSizeLevel
        )
        return measuredSize
    }
}

// Support for variadic content
extension FlowLayout where Content == TupleView<([AnyView])> {
    init(spacing: CGFloat = 8, verticalSpacing: CGFloat? = nil, @ViewBuilder content: @escaping () -> TupleView<([AnyView])>) {
        self.spacing = spacing
        self.verticalSpacing = verticalSpacing ?? spacing
        self.content = content
    }
}
