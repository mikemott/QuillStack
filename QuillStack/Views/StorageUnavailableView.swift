import SwiftUI

/// Shown when the persistent store cannot be opened.
///
/// Deliberately does NOT fall back to an in-memory container: the app would
/// look healthy while every new capture vanished on quit. Nothing here deletes
/// or rewrites the store — the user's data stays exactly as it is on disk.
struct StorageUnavailableView: View {
    let detail: String
    let onRetry: () -> Void

    @State private var showDetail = false

    var body: some View {
        ZStack {
            QSSurface.base.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(QSColor.onSurface)
                    .accessibilityHidden(true)

                Text("Storage unavailable")
                    .font(QSFont.detailTitle)
                    .foregroundStyle(QSColor.onSurface)
                    .accessibilityIdentifier("storage-unavailable")

                Text("QuillStack couldn't open its database. Your existing captures are still on this device and have not been deleted.")
                    .font(QSFont.detailBody)
                    .foregroundStyle(QSColor.onSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Capturing is disabled until the database opens, so nothing you add can be lost. Try restarting, and make sure iOS is up to date.")
                    .font(QSFont.detailBody)
                    .foregroundStyle(QSColor.onSurfaceMuted)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: onRetry) {
                    Text("TRY AGAIN")
                        .font(QSFont.mono(size: 11))
                        .fontWeight(.bold)
                        .tracking(1.5)
                        .foregroundStyle(QSColor.onPrimaryDark)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(QSColor.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("storage-retry")
                .accessibilityLabel("Try opening the database again")

                diagnosticsSection

                Spacer()
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var diagnosticsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { showDetail.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Text("DIAGNOSTICS")
                        .font(QSFont.mono(size: 9))
                        .fontWeight(.bold)
                        .tracking(1.5)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .rotationEffect(.degrees(showDetail ? 0 : -90))
                    Spacer()
                }
                .foregroundStyle(QSColor.onSurfaceMuted)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("storage-diagnostics-toggle")
            .accessibilityLabel(showDetail ? "Hide diagnostics" : "Show diagnostics")

            if showDetail {
                ScrollView {
                    Text(detail)
                        .font(QSFont.monoLight(size: 11))
                        .foregroundStyle(QSColor.onSurfaceVariant)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 160)
                .padding(12)
                .background(QSSurface.container)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }
}
