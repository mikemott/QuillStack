import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tag.name) private var tags: [Tag]
    @State private var locationService = LocationService()
    @State private var showNewTag = false
    @State private var newTagName = ""
    @State private var newTagColor = "#6B7280"
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
        Form {
            tagSection
            locationSection
            obsidianSection
            storageSection
            aboutSection
        }
        .navigationTitle("Settings")
        .alert("New Tag", isPresented: $showNewTag) {
            TextField("Tag name", text: $newTagName)
            Button("Cancel", role: .cancel) { newTagName = "" }
            Button("Create") { createTag() }
        } message: {
            Text("Choose a short, reusable name.")
        }
    }

    // MARK: - Tags

    private var tagSection: some View {
        Section {
            ForEach(tags) { tag in
                HStack {
                    Circle()
                        .fill(Color(hex: tag.colorHex))
                        .frame(width: 12, height: 12)
                    Text(tag.name)
                    Spacer()
                    Text("\(tag.captureCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onDelete(perform: deleteTags)

            Button {
                showNewTag = true
            } label: {
                Label("Add Tag", systemImage: "plus")
            }
        } header: {
            Text("Tags")
        } footer: {
            Text("Tags with 0 captures can be safely deleted.")
        }
    }

    // MARK: - Location

    private var locationSection: some View {
        Section("Location") {
            Toggle("Capture Location", isOn: Binding(
                get: { locationService.isEnabled },
                set: { newValue in
                    locationService.isEnabled = newValue
                    if newValue && !locationService.isAuthorized {
                        locationService.requestPermission()
                    }
                }
            ))

            if locationService.isEnabled {
                HStack {
                    Text("Permission")
                    Spacer()
                    Text(locationService.isAuthorized ? "Granted" : "Not Granted")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Obsidian

    private var obsidianSection: some View {
        Section {
            TextField("Vault Path", text: $vaultPath)
                .textContentType(.URL)
                .autocorrectionDisabled()
                .onChange(of: vaultPath) { _, newValue in
                    UserDefaults.standard.set(newValue, forKey: "obsidianVaultPath")
                }

            TextField("Attachment Folder", text: $attachmentFolder)
                .autocorrectionDisabled()
                .onChange(of: attachmentFolder) { _, newValue in
                    UserDefaults.standard.set(newValue, forKey: "obsidianAttachmentFolder")
                }

            TextField("Daily Note Folder (optional)", text: $dailyNoteFolder)
                .autocorrectionDisabled()
                .onChange(of: dailyNoteFolder) { _, newValue in
                    UserDefaults.standard.set(newValue, forKey: "obsidianDailyNoteFolder")
                }

            Toggle("Include OCR Text", isOn: $includeOCR)
                .onChange(of: includeOCR) { _, newValue in
                    UserDefaults.standard.set(newValue, forKey: "obsidianIncludeOCR")
                }
        } header: {
            Text("Obsidian")
        } footer: {
            Text("Set the full path to your Obsidian vault folder.")
        }
    }

    // MARK: - Storage

    private var storageSection: some View {
        Section("Storage") {
            HStack {
                Text("Captures")
                Spacer()
                let descriptor = FetchDescriptor<Capture>()
                let count = (try? modelContext.fetchCount(descriptor)) ?? 0
                Text("\(count)")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Actions

    private func deleteTags(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(tags[index])
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
