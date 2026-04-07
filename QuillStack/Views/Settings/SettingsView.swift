import SwiftUI
import SwiftData
import CloudKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tag.name) private var tags: [Tag]
    @State private var locationService = LocationService()
    @State private var showNewTag = false
    @State private var newTagName = ""
    @State private var newTagColor = "#6B7280"
    @State private var showResetConfirm = false
    @State private var isAPIConfigured = false
    @State private var icloudAvailable = false
    @State private var vaultPath = UserDefaults.standard.string(forKey: "obsidianVaultPath") ?? ""
    @State private var attachmentFolder = UserDefaults.standard.string(forKey: "obsidianAttachmentFolder") ?? "attachments"
    @State private var dailyNoteFolder = UserDefaults.standard.string(forKey: "obsidianDailyNoteFolder") ?? ""
    @State private var includeOCR = UserDefaults.standard.bool(forKey: "obsidianIncludeOCR")

    private let colorOptions = [
        "#D4910A", "#4682B4", "#5A8F5A", "#6B7280",
        "#9CA3AF", "#7C3AED", "#0D9488", "#EA8B2D",
        "#DC2626", "#DB2777", "#2563EB", "#059669",
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                tagSection
                locationSection
                obsidianSection
                storageSection
                ocrSection
                icloudSection
                aboutSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(QSSurface.base)
        .navigationTitle("Settings")
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            isAPIConfigured = await DatalabOCRService.shared.isConfigured
            let status = try? await CKContainer.default().accountStatus()
            icloudAvailable = status == .available
        }
        .alert("New Tag", isPresented: $showNewTag) {
            TextField("Tag name", text: $newTagName)
            Button("Cancel", role: .cancel) { newTagName = "" }
            Button("Create") { createTag() }
        } message: {
            Text("Choose a short, reusable name.")
        }
    }

    // MARK: - Tags
    // No dividers between items. Use spacing-8 (28pt) between section groups.

    private var tagSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("TAGS")

            // Tag list — grouped in a tonal tray
            VStack(spacing: 0) {
                ForEach(tags) { tag in
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Color(hex: tag.colorHex))
                            .frame(width: 14, height: 14)
                            .shadow(color: Color(hex: tag.colorHex).opacity(0.3), radius: 4)
                        Text(tag.name)
                            .font(QSFont.sans(size: 15))
                            .foregroundStyle(QSColor.onSurface)
                        Spacer()
                        Text("\(tag.captureCount)")
                            .font(QSFont.monoLight(size: 13))
                            .foregroundStyle(QSColor.onSurfaceMuted)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
            .background(QSSurface.container)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Button {
                showNewTag = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                    Text("ADD TAG")
                        .font(QSFont.sectionHeader)
                        .tracking(1.5)
                }
                .foregroundStyle(QSColor.tertiary)
            }
            .padding(.leading, 4)

            Text("Tags with 0 captures can be safely deleted.")
                .font(QSFont.monoLight(size: 11))
                .foregroundStyle(QSColor.onSurfaceMuted)
                .padding(.leading, 4)
        }
    }

    // MARK: - Location

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("LOCATION")

            VStack(spacing: 0) {
                settingsRow("Capture Location") {
                    Toggle("", isOn: Binding(
                        get: { locationService.isEnabled },
                        set: { newValue in
                            locationService.isEnabled = newValue
                            if newValue && !locationService.isAuthorized {
                                locationService.requestPermission()
                            }
                        }
                    ))
                    .tint(QSColor.primary)
                    .labelsHidden()
                }

                if locationService.isEnabled {
                    settingsRow("Permission") {
                        Text(locationService.isAuthorized ? "Granted" : "Not Granted")
                            .font(QSFont.mono(size: 13))
                            .foregroundStyle(QSColor.onSurfaceMuted)
                    }
                }
            }
            .background(QSSurface.container)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    // MARK: - Obsidian

    private var obsidianSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("OBSIDIAN")

            VStack(spacing: 0) {
                settingsInput("Vault Path", text: $vaultPath, key: "obsidianVaultPath")
                settingsInput("Attachment Folder", text: $attachmentFolder, key: "obsidianAttachmentFolder")
                settingsInput("Daily Note Folder", text: $dailyNoteFolder, key: "obsidianDailyNoteFolder")

                settingsRow("Include OCR Text") {
                    Toggle("", isOn: $includeOCR)
                        .tint(QSColor.primary)
                        .labelsHidden()
                        .onChange(of: includeOCR) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: "obsidianIncludeOCR")
                        }
                }
            }
            .background(QSSurface.container)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text("Set the full path to your Obsidian vault folder.")
                .font(QSFont.monoLight(size: 11))
                .foregroundStyle(QSColor.onSurfaceMuted)
                .padding(.leading, 4)
        }
    }

    // MARK: - Storage

    private var storageSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("STORAGE")

            VStack(spacing: 0) {
                settingsRow("Captures") {
                    let descriptor = FetchDescriptor<Capture>()
                    let count = (try? modelContext.fetchCount(descriptor)) ?? 0
                    Text("\(count)")
                        .font(QSFont.mono(size: 13))
                        .foregroundStyle(QSColor.onSurfaceMuted)
                }

                Button {
                    showResetConfirm = true
                } label: {
                    HStack {
                        Text("Reset All Data")
                            .font(QSFont.sans(size: 15))
                            .foregroundStyle(.red)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .confirmationDialog("Delete all captures and reset tags to defaults?", isPresented: $showResetConfirm, titleVisibility: .visible) {
                    Button("Reset All Data", role: .destructive) { resetData() }
                }
            }
            .background(QSSurface.container)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text("Reset deletes all captures and restores default tags.")
                .font(QSFont.monoLight(size: 11))
                .foregroundStyle(QSColor.onSurfaceMuted)
                .padding(.leading, 4)
        }
    }

    // MARK: - OCR

    private var ocrSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("OCR")

            VStack(spacing: 0) {
                settingsRow("Engine") {
                    Text("Datalab Chandra")
                        .font(QSFont.mono(size: 13))
                        .foregroundStyle(QSColor.onSurfaceMuted)
                }

                settingsRow("API Key") {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(QSColor.onSurfaceMuted)
                            .frame(width: 8, height: 8)
                            .opacity(isAPIConfigured ? 1.0 : 0.3)
                        Text(isAPIConfigured ? "Configured" : "Missing")
                            .font(QSFont.mono(size: 13))
                            .foregroundStyle(QSColor.onSurfaceMuted)
                    }
                }
            }
            .background(QSSurface.container)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text("API key is set in Secrets.xcconfig. Get one at datalab.to/app/keys.")
                .font(QSFont.monoLight(size: 11))
                .foregroundStyle(QSColor.onSurfaceMuted)
                .padding(.leading, 4)
        }
    }

    // MARK: - iCloud

    private var icloudSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("ICLOUD BACKUP")

            VStack(spacing: 0) {
                settingsRow("Status") {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(QSColor.onSurfaceMuted)
                            .frame(width: 8, height: 8)
                            .opacity(icloudAvailable ? 1.0 : 0.3)
                        Text(icloudAvailable ? "Active" : "Unavailable")
                            .font(QSFont.mono(size: 13))
                            .foregroundStyle(QSColor.onSurfaceMuted)
                    }
                }

                settingsRow("Account") {
                    Text(icloudAvailable ? "Signed In" : "Not Signed In")
                        .font(QSFont.mono(size: 13))
                        .foregroundStyle(QSColor.onSurfaceMuted)
                }
            }
            .background(QSSurface.container)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text("Captures and tags sync to iCloud automatically. Data restores when you reinstall.")
                .font(QSFont.monoLight(size: 11))
                .foregroundStyle(QSColor.onSurfaceMuted)
                .padding(.leading, 4)
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("ABOUT")

            VStack(spacing: 0) {
                settingsRow("Version") {
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0")
                        .font(QSFont.mono(size: 13))
                        .foregroundStyle(QSColor.onSurfaceMuted)
                }
            }
            .background(QSSurface.container)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    // MARK: - Reusable Components

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(QSFont.sectionHeader)
            .tracking(2.5)
            .foregroundStyle(QSColor.secondary)
    }

    private func settingsRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(QSFont.sans(size: 15))
                .foregroundStyle(QSColor.onSurface)
            Spacer()
            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func settingsInput(_ placeholder: String, text: Binding<String>, key: String) -> some View {
        HStack {
            Text(placeholder)
                .font(QSFont.sans(size: 15))
                .foregroundStyle(QSColor.onSurface)
                .frame(maxWidth: .infinity, alignment: .leading)
            TextField("", text: text)
                .font(QSFont.mono(size: 13))
                .foregroundStyle(QSColor.onSurfaceVariant)
                .multilineTextAlignment(.trailing)
                .autocorrectionDisabled()
                .onChange(of: text.wrappedValue) { _, newValue in
                    UserDefaults.standard.set(newValue, forKey: key)
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Actions

    private func resetData() {
        // Delete images first to avoid external storage fault on cascade
        let imageDescriptor = FetchDescriptor<CaptureImage>()
        if let images = try? modelContext.fetch(imageDescriptor) {
            for image in images { modelContext.delete(image) }
        }
        try? modelContext.save()

        // Delete captures
        let captureDescriptor = FetchDescriptor<Capture>()
        if let captures = try? modelContext.fetch(captureDescriptor) {
            for capture in captures { modelContext.delete(capture) }
        }
        try? modelContext.save()

        // Delete all tags and re-seed defaults
        let tagDescriptor = FetchDescriptor<Tag>()
        if let existingTags = try? modelContext.fetch(tagDescriptor) {
            for tag in existingTags { modelContext.delete(tag) }
        }
        for tag in Tag.defaults {
            modelContext.insert(Tag(name: tag.name, colorHex: tag.hex))
        }

        try? modelContext.save()
    }

    private func createTag() {
        let name = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        guard !tags.contains(where: { $0.name.lowercased() == name.lowercased() }) else {
            newTagName = ""
            return
        }
        let tag = Tag(name: name, colorHex: newTagColor)
        modelContext.insert(tag)
        try? modelContext.save()
        newTagName = ""
    }
}
