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
