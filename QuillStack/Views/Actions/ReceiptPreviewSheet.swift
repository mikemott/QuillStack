import SwiftUI

struct ReceiptPreviewSheet: View {
    let receipt: ReceiptExtraction
    let capture: Capture
    var onExport: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header fields
                    VStack(spacing: 0) {
                        if let vendor = receipt.vendor {
                            fieldRow("Vendor", value: vendor)
                        }
                        if let total = receipt.total {
                            fieldRow("Total", value: formatTotal(total, currency: receipt.currency))
                        }
                        if let date = receipt.date {
                            fieldRow("Date", value: date)
                        }
                    }
                    .background(QSSurface.container)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    // Line items
                    if let items = receipt.items, !items.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("ITEMS")
                                .font(QSFont.sectionHeader)
                                .tracking(2)
                                .foregroundStyle(QSColor.onSurfaceMuted)

                            VStack(spacing: 0) {
                                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                                    HStack {
                                        Text(item.name ?? "Unknown item")
                                            .font(QSFont.sans(size: 15))
                                            .foregroundStyle(QSColor.onSurface)
                                        if let qty = item.quantity, qty > 1 {
                                            Text("×\(qty)")
                                                .font(QSFont.mono(size: 13))
                                                .foregroundStyle(QSColor.onSurfaceMuted)
                                        }
                                        Spacer()
                                        Text(item.price ?? "")
                                            .font(QSFont.mono(size: 13))
                                            .foregroundStyle(QSColor.onSurfaceVariant)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }
                            }
                            .background(QSSurface.container)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(QSSurface.base)
            .navigationTitle("Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { onDismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Export") { onExport() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func fieldRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(QSFont.sans(size: 15))
                .foregroundStyle(QSColor.onSurface)
            Spacer()
            Text(value)
                .font(QSFont.mono(size: 13))
                .foregroundStyle(QSColor.onSurfaceVariant)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func formatTotal(_ total: String, currency: String?) -> String {
        if let currency, !total.contains(currency) {
            return "\(currency) \(total)"
        }
        return total
    }
}
