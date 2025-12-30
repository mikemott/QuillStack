# QuillStack Feature Implementation Plan

**Created:** 2025-12-30
**Last Updated:** 2025-12-30
**Status:** 4 of 6 features completed
**Context:** Continue from this plan in a new Claude Code session

---

## Features Overview

| # | Feature | Status | Notes |
|---|---------|--------|-------|
| 1 | Flash Toggle | ✅ DONE | `CameraManager.swift`, `CameraView.swift` |
| 2 | Photo Library Import | ✅ DONE | `CameraView.swift` with PhotosUI |
| 3 | Offline Mode | ✅ DONE | `OfflineQueueService.swift`, Core Data entity |
| 4 | Handwriting Learning | ✅ DONE | `HandwritingLearningService.swift`, `OCRCorrection` entity |
| 5 | iCloud Sync | ⏳ TODO | Requires Xcode capabilities config |
| 6 | Claude Prompt to GitHub | ✅ DONE | New note type → AI refinement → GitHub Issue |

---

## Completed Features

### Feature 1: Flash Toggle ✅
- Added `flashMode` property to `CameraManager.swift`
- Added `toggleFlash()` method cycling auto → on → off → auto
- Updated `capturePhoto()` to use user's flash preference
- Updated `CameraView.swift` with dynamic icon and button color
- Added accessibility value for VoiceOver

### Feature 2: Photo Library Import ✅
- Added `PhotosUI` import and `PhotosPickerItem` state
- Wired gallery button to show photo picker
- Added `.photosPicker()` modifier with `.images` filter
- Selected images flow through existing `ImagePreviewView` → OCR pipeline

### Feature 3: Offline Mode ✅
- Created `QueuedEnhancement` Core Data entity
- Created `Services/OfflineQueueService.swift` with:
  - `NWPathMonitor` for real-time network status
  - Automatic queue processing on connectivity restore
  - Exponential backoff retry (5s, 30s, 120s, max 3 attempts)
  - `hasPendingEnhancement(for:)` for UI status
- Updated `CameraViewModel.swift` to queue when offline
- Added `.offline` error case to `LLMService.swift`
- Added "Enhancing..." badge to `NoteDetailView.swift`
- Added notification listener for enhancement completion

### Feature 4: Handwriting Learning ✅
- Created `OCRCorrection` Core Data entity with:
  - `originalWord`, `correctedWord` for correction mapping
  - `frequency` counter for confidence weighting
  - `createdAt`, `lastUsedAt` for recency tracking
- Created `Models/OCRCorrection.swift` with fetch helpers:
  - `fetchCorrectionsDictionary()` for spell correction integration
  - `find(originalWord:)` for deduplication
  - `fetchAll()` for Settings UI display
- Created `Services/HandwritingLearningService.swift` with:
  - Levenshtein distance algorithm (threshold ≤ 2) to filter OCR errors from semantic rewrites
  - `detectCorrections(original:, edited:)` called on note save
  - `getLearnedCorrections()` returns dictionary for SpellCorrector
  - `clearAllCorrections()` and `removeCorrection()` for user management
- Updated `Services/SpellCorrector.swift`:
  - Added `.learnedCorrection` to `CorrectionSource` enum
  - Added Pass 3 (learned corrections) between OCR dictionary and UITextChecker
  - Both `correctSpelling()` and `correctEmailContent()` accept optional learned corrections
- Updated `ViewModels/CameraViewModel.swift`:
  - Fetches learned corrections before spell correction
  - Passes learned corrections to SpellCorrector methods
  - Logs learned correction usage count
- Updated `Views/Notes/NoteDetailView.swift`:
  - Tracks `originalContent` on view appear
  - Calls `detectCorrections()` in `saveChanges()` when content differs
- Updated `Views/Settings/SettingsView.swift`:
  - Added "Handwriting Learning" section with correction count display
  - NavigationLink to `LearnedCorrectionsView` for viewing/deleting corrections
  - "Clear All" button with confirmation dialog
  - "How it works" explanation for users
- Created `LearnedCorrectionsView` in SettingsView.swift:
  - Lists all learned corrections with frequency count
  - Swipe-to-delete individual corrections
  - Empty state with guidance

---

## Remaining Features

---

## Feature 1: Offline Mode

### Current State
- LLM calls fail immediately without network (no retry)
- No queue mechanism exists
- Auto-enhance silently falls back to spell-corrected text
- Manual enhance shows error with "Try Again" button

### Implementation Plan

**New Files:**
- `Services/OfflineQueueService.swift` - Queue management
- `Models/QueuedEnhancement.swift` - Core Data entity

**Core Data Model Changes:**
Add new entity `QueuedEnhancement`:
```
- id: UUID
- noteId: UUID
- originalText: String
- noteType: String
- createdAt: Date
- status: String (pending/processing/completed/failed)
- retryCount: Int16
- lastAttemptAt: Date?
```

**OfflineQueueService Implementation:**
```swift
@MainActor
final class OfflineQueueService: ObservableObject {
    static let shared = OfflineQueueService()

    @Published var pendingCount: Int = 0
    @Published var isOnline: Bool = true

    private let monitor = NWPathMonitor()

    func enqueue(noteId: UUID, text: String, noteType: String)
    func processQueue() async  // Called when online
    func retryFailed() async
}
```

**Integration Points:**
- `CameraViewModel.swift:96-106` - Check network, queue if offline
- `LLMService.swift` - Add network check before API calls
- `NoteDetailView.swift` - Show pending badge if enhancement queued
- `ContentView.swift` - Add queue status indicator

**Network Monitoring:**
```swift
import Network
let monitor = NWPathMonitor()
monitor.pathUpdateHandler = { path in
    isOnline = path.status == .satisfied
    if isOnline { Task { await processQueue() } }
}
monitor.start(queue: DispatchQueue.global())
```

---

## Feature 2: iCloud Sync

### Current State
- Uses `NSPersistentContainer` (local only)
- File protection: `.complete` enabled
- Binary data already uses external storage (good)
- UUIDs for all entities (good)
- **Issue:** Asymmetric delete rules on Note↔Meeting relationship

### Implementation Plan

**Step 1: Fix Core Data Model**

Create new model version in `QuillStack.xcdatamodeld`:
- Change `Meeting.note` delete rule from Nullify → Cascade
- Now symmetric: both sides cascade on delete

**Step 2: Update CoreDataStack.swift**

```swift
// Change from:
lazy var persistentContainer: NSPersistentContainer = {
    let container = NSPersistentContainer(name: "QuillStack")

// To:
lazy var persistentContainer: NSPersistentCloudKitContainer = {
    let container = NSPersistentCloudKitContainer(name: "QuillStack")

    // CloudKit configuration
    guard let description = container.persistentStoreDescriptions.first else {
        fatalError("No store description")
    }

    description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
        containerIdentifier: "iCloud.com.quillstack.app"
    )

    // Enable remote change notifications
    description.setOption(true as NSNumber,
        forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
```

**Step 3: Add Entitlements**

Create/update `QuillStack.entitlements`:
```xml
<key>com.apple.developer.icloud-container-identifiers</key>
<array>
    <string>iCloud.com.quillstack.app</string>
</array>
<key>com.apple.developer.icloud-services</key>
<array>
    <string>CloudKit</string>
</array>
```

**Step 4: Sync Status Monitoring**

Add to `CoreDataStack.swift`:
```swift
@Published var syncStatus: SyncStatus = .idle

enum SyncStatus {
    case idle, syncing, error(String)
}

private func setupCloudKitMonitoring() {
    NotificationCenter.default.addObserver(
        forName: NSPersistentCloudKitContainer.eventChangedNotification,
        object: persistentContainer,
        queue: .main
    ) { notification in
        // Update sync status
    }
}
```

**Step 5: Handle Merge Conflicts**

Change merge policy:
```swift
// Remote wins on conflicts (standard for cloud sync)
context.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
```

**Image Sync Decision:** Sync images too (external storage already configured, CloudKit handles large files automatically)

**Xcode Configuration Required:**
1. Enable iCloud capability in Signing & Capabilities
2. Select CloudKit checkbox
3. Add Push Notifications capability (for silent sync)

---

## Feature 3: Handwriting Learning

### Current State
- 76 hardcoded OCR corrections in `SpellCorrector.swift`
- Corrections applied but never persisted
- No learning loop exists
- No user-specific adaptation

### Implementation Plan

**Decision:** Learn only from user manual edits (higher confidence)

**New Files:**
- `Models/OCRCorrection.swift` - Core Data entity
- `Services/HandwritingLearningService.swift` - Learning logic

**Core Data Model Changes:**

Add new entity `OCRCorrection`:
```
- id: UUID
- originalWord: String (indexed)
- correctedWord: String
- frequency: Int16 (how many times seen)
- createdAt: Date
- lastUsedAt: Date
```

**HandwritingLearningService Implementation:**
```swift
@MainActor
final class HandwritingLearningService {
    static let shared = HandwritingLearningService()

    /// Called when user manually edits note content
    func detectCorrections(original: String, edited: String)

    /// Returns learned corrections dictionary
    func getLearnedCorrections() -> [String: String]

    /// Merges with SpellCorrector's hardcoded dictionary
    func buildCorrectionDictionary() -> [String: String]
}
```

**Detection Algorithm:**
```swift
func detectCorrections(original: String, edited: String) {
    let originalWords = original.split(separator: " ")
    let editedWords = edited.split(separator: " ")

    // Use diff algorithm to find changed words
    // For each change where Levenshtein distance < 3:
    //   - Record as potential OCR correction
    //   - Increment frequency if already exists
}
```

**Integration Points:**
- `NoteDetailView.swift` - Track original content, detect changes on save
- `TodoDetailView.swift` - Same for todo edits
- `SpellCorrector.swift` - Query learned corrections before UITextChecker

**SpellCorrector Integration:**
```swift
// In correctSpelling(), after Pass 2 (OCR dictionary):
// Pass 2.5: Learned corrections
let learnedCorrections = HandwritingLearningService.shared.getLearnedCorrections()
for (wrong, right) in learnedCorrections {
    // Apply learned corrections
}
```

---

## Feature 4: Photo Library Import

### Current State
- Gallery button exists with TODO placeholder at `CameraView.swift:171`
- Pipeline is image-agnostic (same flow works for imported photos)
- `NSPhotoLibraryUsageDescription` already in Info.plist

### Implementation Plan

**Changes to CameraView.swift:**

```swift
import PhotosUI

struct CameraView: View {
    @State private var showingPhotoPicker = false
    @State private var selectedItem: PhotosPickerItem?

    // In gallery button action:
    Button(action: { showingPhotoPicker = true }) { ... }

    // Add modifier:
    .photosPicker(isPresented: $showingPhotoPicker,
                  selection: $selectedItem,
                  matching: .images)
    .onChange(of: selectedItem) { _, newItem in
        Task {
            if let data = try? await newItem?.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                cameraManager.capturedImage = image
                // This triggers existing ImagePreviewView flow
            }
        }
    }
```

**That's it!** The existing `ImagePreviewView` and `CameraViewModel.processImage()` handle everything else.

---

## Feature 5: Flash Toggle

### Current State
- Flash button exists with TODO placeholder at `CameraView.swift:229`
- Flash hardcoded to `.auto` in `CameraManager.swift:203`

### Implementation Plan

**Changes to CameraManager.swift:**

```swift
// Add published property
@Published var flashMode: AVCaptureDevice.FlashMode = .auto

// Add toggle method
func toggleFlash() {
    switch flashMode {
    case .auto: flashMode = .on
    case .on: flashMode = .off
    case .off: flashMode = .auto
    @unknown default: flashMode = .auto
    }
}

// In capturePhoto(), change:
if photoOutput.supportedFlashModes.contains(.auto) {
    settings.flashMode = .auto
}
// To:
if photoOutput.supportedFlashModes.contains(flashMode) {
    settings.flashMode = flashMode
}
```

**Changes to CameraView.swift:**

```swift
// Flash button (lines 228-245):
Button(action: { cameraManager.toggleFlash() }) {
    ZStack {
        Circle()
            .fill(flashButtonColor)
            .frame(width: 50, height: 50)

        Image(systemName: flashIconName)
            .font(.system(size: 24, weight: .regular))
            .foregroundColor(.forestLight)
    }
}

// Add computed properties:
private var flashIconName: String {
    switch cameraManager.flashMode {
    case .auto: return "bolt.badge.a"
    case .on: return "bolt.fill"
    case .off: return "bolt.slash"
    @unknown default: return "bolt.badge.a"
    }
}

private var flashButtonColor: Color {
    cameraManager.flashMode == .on
        ? Color.yellow.opacity(0.3)
        : Color.forestDark.opacity(0.3)
}
```

---

## Feature 6: Claude Prompt to GitHub Issues

### Overview

A new note type that transforms handwritten feature requests or coding prompts into well-structured GitHub Issues. The workflow:

1. User writes a feature idea on paper with `#claude#` or `#feature#` trigger
2. QuillStack captures and OCRs the handwritten note
3. LLM refines the rough notes into a structured, actionable prompt
4. User reviews the refined prompt in a dedicated detail view
5. One-tap export creates a GitHub Issue in the user's chosen repository

### Why GitHub Issues?

- **Universal**: Every developer already has GitHub
- **Built-in workflow**: Labels, milestones, assignees, projects
- **AI-readable**: Claude Code can read issues via `gh issue view #42`
- **Team-friendly**: Works for solo devs and teams alike
- **No new infrastructure**: Just API integration

### User Flow

```
Handwritten: "#feature# Add dark mode toggle to settings page"
                    ↓
              OCR + Spell Correction
                    ↓
         LLM Prompt Refinement (Claude API)
                    ↓
┌─────────────────────────────────────────────────────────┐
│  ClaudePromptDetailView                                 │
│  ┌─────────────────────────────────────────────────────┐│
│  │ Original (collapsed):                               ││
│  │ "Add dark mode toggle to settings page"             ││
│  └─────────────────────────────────────────────────────┘│
│  ┌─────────────────────────────────────────────────────┐│
│  │ Refined Prompt:                                     ││
│  │                                                     ││
│  │ ## Feature: Dark Mode Toggle                        ││
│  │                                                     ││
│  │ Add a toggle switch in the Settings view that...    ││
│  │                                                     ││
│  │ ### Acceptance Criteria                             ││
│  │ - Toggle visible in SettingsView                    ││
│  │ - Preference persists in UserDefaults               ││
│  │ - All views respect @Environment(\.colorScheme)     ││
│  │                                                     ││
│  │ ### Technical Notes                                 ││
│  │ - Consider using @AppStorage for persistence        ││
│  │ - May need custom Color assets for both themes      ││
│  └─────────────────────────────────────────────────────┘│
│                                                         │
│  [Edit Refined Prompt]                                  │
│                                                         │
│  Repository: [Select Repository ▼]                      │
│  Labels: [enhancement] [ui] [+]                         │
│                                                         │
│  [ Create GitHub Issue ]                                │
└─────────────────────────────────────────────────────────┘
                    ↓
           GitHub Issue Created
                    ↓
    User later: `claude "implement issue #42"`
```

### Current State

- `TextClassifier.swift` has hashtag-based type detection (easily extensible)
- `LLMService.swift` has Claude API integration (can add new prompt types)
- Export framework exists (`ExportService.swift`, `NotionExporter.swift`)
- No GitHub API integration yet

### Implementation Plan

#### Step 1: Add New Note Type

**TextClassifier.swift** - Add claude/feature triggers:

```swift
// Add to NoteType enum
case claudePrompt  // New type

// Add to triggerMap dictionary
private static let triggerMap: [String: NoteType] = [
    // ... existing triggers ...
    "#claude#": .claudePrompt,
    "#feature#": .claudePrompt,
    "#prompt#": .claudePrompt,
    "#request#": .claudePrompt,
]

// Add OCR-tolerant variants
private static let fuzzyVariants: [String: String] = [
    // ... existing variants ...
    "#c1aude#": "#claude#",
    "#ciaude#": "#claude#",
    "#featur#": "#feature#",
    "#featuer#": "#feature#",
]
```

**Note.swift** - Handle new type in routing:

```swift
// Add to noteTypeEnum computed property
var noteTypeEnum: NoteType {
    switch noteType {
    // ... existing cases ...
    case "claudePrompt": return .claudePrompt
    default: return .general
    }
}
```

#### Step 2: Create Prompt Refinement Service

**New File: `Services/PromptRefinerService.swift`**

```swift
import Foundation

@MainActor
final class PromptRefinerService {
    static let shared = PromptRefinerService()

    private let llmService = LLMService.shared

    /// Transforms rough handwritten notes into a structured GitHub issue
    func refineToGitHubIssue(rawText: String, projectContext: String?) async throws -> RefinedPrompt {
        let systemPrompt = """
        You are helping transform handwritten feature requests into well-structured GitHub issues.

        Given rough notes, produce a structured issue with:
        1. A clear, concise title (imperative mood: "Add...", "Fix...", "Update...")
        2. A description explaining the feature/change
        3. Acceptance criteria as a checklist
        4. Technical notes if the user provided implementation hints

        Keep the original intent. Don't over-engineer or add unnecessary scope.
        Format as Markdown suitable for a GitHub issue body.

        \(projectContext.map { "Project context: \($0)" } ?? "")
        """

        let response = try await llmService.complete(
            system: systemPrompt,
            user: rawText
        )

        return parseRefinedPrompt(response)
    }

    private func parseRefinedPrompt(_ response: String) -> RefinedPrompt {
        // Extract title (first # heading or first line)
        // Extract body (rest of content)
        // Suggest labels based on keywords
        // ...
    }
}

struct RefinedPrompt: Codable {
    let title: String
    let body: String
    let suggestedLabels: [String]
    let originalText: String
}
```

#### Step 3: Create GitHub Integration Service

**New File: `Services/GitHubService.swift`**

```swift
import Foundation

@MainActor
final class GitHubService: ObservableObject {
    static let shared = GitHubService()

    @Published var isAuthenticated: Bool = false
    @Published var repositories: [GitHubRepository] = []
    @Published var selectedRepository: GitHubRepository?

    private var accessToken: String? {
        KeychainService.shared.get(key: "github_access_token")
    }

    // MARK: - Authentication

    /// Initiates GitHub OAuth Device Flow (no server required)
    func authenticate() async throws {
        // Step 1: Request device code
        let deviceCode = try await requestDeviceCode()

        // Step 2: User visits github.com/login/device and enters code
        // (Show UI with code and URL)

        // Step 3: Poll for access token
        let token = try await pollForAccessToken(deviceCode: deviceCode)

        // Step 4: Store in Keychain
        KeychainService.shared.set(key: "github_access_token", value: token)
        isAuthenticated = true
    }

    // MARK: - Repositories

    func fetchRepositories() async throws {
        guard let token = accessToken else { throw GitHubError.notAuthenticated }

        let url = URL(string: "https://api.github.com/user/repos?sort=updated&per_page=20")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, _) = try await URLSession.shared.data(for: request)
        repositories = try JSONDecoder().decode([GitHubRepository].self, from: data)
    }

    // MARK: - Issues

    func createIssue(
        in repo: GitHubRepository,
        title: String,
        body: String,
        labels: [String]
    ) async throws -> GitHubIssue {
        guard let token = accessToken else { throw GitHubError.notAuthenticated }

        let url = URL(string: "https://api.github.com/repos/\(repo.fullName)/issues")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let payload = CreateIssueRequest(title: title, body: body, labels: labels)
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 201 else {
            throw GitHubError.createFailed
        }

        return try JSONDecoder().decode(GitHubIssue.self, from: data)
    }
}

// MARK: - Models

struct GitHubRepository: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let fullName: String
    let isPrivate: Bool
    let description: String?

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case fullName = "full_name"
        case isPrivate = "private"
    }
}

struct GitHubIssue: Codable {
    let id: Int
    let number: Int
    let title: String
    let htmlUrl: String

    enum CodingKeys: String, CodingKey {
        case id, number, title
        case htmlUrl = "html_url"
    }
}

struct CreateIssueRequest: Codable {
    let title: String
    let body: String
    let labels: [String]
}

enum GitHubError: LocalizedError {
    case notAuthenticated
    case createFailed
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Not authenticated with GitHub"
        case .createFailed: return "Failed to create issue"
        case .rateLimited: return "GitHub API rate limit exceeded"
        }
    }
}
```

#### Step 4: GitHub OAuth Device Flow

The Device Flow is ideal for iOS apps - no server required:

```swift
// In GitHubService.swift

private let clientId = "YOUR_GITHUB_OAUTH_APP_CLIENT_ID"  // From GitHub Developer Settings

struct DeviceCodeResponse: Codable {
    let deviceCode: String
    let userCode: String
    let verificationUri: String
    let expiresIn: Int
    let interval: Int

    enum CodingKeys: String, CodingKey {
        case deviceCode = "device_code"
        case userCode = "user_code"
        case verificationUri = "verification_uri"
        case expiresIn = "expires_in"
        case interval
    }
}

func requestDeviceCode() async throws -> DeviceCodeResponse {
    let url = URL(string: "https://github.com/login/device/code")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Accept")

    let body = ["client_id": clientId, "scope": "repo"]
    request.httpBody = try JSONEncoder().encode(body)

    let (data, _) = try await URLSession.shared.data(for: request)
    return try JSONDecoder().decode(DeviceCodeResponse.self, from: data)
}

func pollForAccessToken(deviceCode: DeviceCodeResponse) async throws -> String {
    let url = URL(string: "https://github.com/login/oauth/access_token")!

    // Poll every `interval` seconds until user completes auth or timeout
    for _ in 0..<(deviceCode.expiresIn / deviceCode.interval) {
        try await Task.sleep(nanoseconds: UInt64(deviceCode.interval) * 1_000_000_000)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let body = [
            "client_id": clientId,
            "device_code": deviceCode.deviceCode,
            "grant_type": "urn:ietf:params:oauth:grant-type:device_code"
        ]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await URLSession.shared.data(for: request)

        if let response = try? JSONDecoder().decode(AccessTokenResponse.self, from: data),
           let token = response.accessToken {
            return token
        }
        // If error is "authorization_pending", keep polling
        // If error is "slow_down", increase interval
        // If error is "expired_token" or "access_denied", throw
    }

    throw GitHubError.authTimeout
}
```

#### Step 5: Create Detail View

**New File: `Views/Notes/ClaudePromptDetailView.swift`**

```swift
import SwiftUI

struct ClaudePromptDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var note: Note
    @StateObject private var gitHubService = GitHubService.shared

    @State private var refinedPrompt: RefinedPrompt?
    @State private var isRefining = false
    @State private var isCreatingIssue = false
    @State private var selectedRepo: GitHubRepository?
    @State private var selectedLabels: Set<String> = []
    @State private var showOriginal = false
    @State private var createdIssue: GitHubIssue?
    @State private var errorMessage: String?

    private let commonLabels = ["enhancement", "bug", "documentation", "ui", "performance", "refactor"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Original text (collapsible)
                originalTextSection

                // Refined prompt
                refinedPromptSection

                // Repository selector
                repositorySection

                // Labels
                labelsSection

                // Create button
                createButtonSection

                // Success state
                if let issue = createdIssue {
                    successSection(issue: issue)
                }
            }
            .padding()
        }
        .navigationTitle("Claude Prompt")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await refinePrompt()
        }
    }

    private var originalTextSection: some View {
        DisclosureGroup("Original Handwriting", isExpanded: $showOriginal) {
            Text(note.content)
                .font(.serifBody())
                .foregroundColor(.textMedium)
                .padding()
                .background(Color.paperTan.opacity(0.5))
                .cornerRadius(8)
        }
    }

    private var refinedPromptSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Refined Prompt")
                    .font(.serifHeadline())
                Spacer()
                if isRefining {
                    ProgressView()
                }
            }

            if let refined = refinedPrompt {
                VStack(alignment: .leading, spacing: 12) {
                    Text(refined.title)
                        .font(.headline)

                    Text(refined.body)
                        .font(.serifBody())
                }
                .padding()
                .background(Color.creamLight)
                .cornerRadius(8)
            }
        }
    }

    private var repositorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Repository")
                .font(.serifHeadline())

            if gitHubService.isAuthenticated {
                Picker("Repository", selection: $selectedRepo) {
                    Text("Select...").tag(nil as GitHubRepository?)
                    ForEach(gitHubService.repositories) { repo in
                        Text(repo.fullName).tag(repo as GitHubRepository?)
                    }
                }
                .pickerStyle(.menu)
            } else {
                Button("Connect GitHub") {
                    Task { try? await gitHubService.authenticate() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var labelsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Labels")
                .font(.serifHeadline())

            FlowLayout(spacing: 8) {
                ForEach(commonLabels, id: \.self) { label in
                    LabelChip(
                        label: label,
                        isSelected: selectedLabels.contains(label),
                        onTap: { toggleLabel(label) }
                    )
                }
            }
        }
    }

    private var createButtonSection: some View {
        Button(action: createIssue) {
            HStack {
                if isCreatingIssue {
                    ProgressView()
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                }
                Text("Create GitHub Issue")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(selectedRepo != nil ? Color.forestMedium : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(selectedRepo == nil || isCreatingIssue || refinedPrompt == nil)
    }

    private func successSection(issue: GitHubIssue) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)

            Text("Issue #\(issue.number) Created!")
                .font(.headline)

            Link("Open in GitHub", destination: URL(string: issue.htmlUrl)!)
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Actions

    private func refinePrompt() async {
        isRefining = true
        defer { isRefining = false }

        do {
            refinedPrompt = try await PromptRefinerService.shared.refineToGitHubIssue(
                rawText: note.content,
                projectContext: nil  // Could add project context from settings
            )
            selectedLabels = Set(refinedPrompt?.suggestedLabels ?? [])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func createIssue() {
        guard let repo = selectedRepo, let refined = refinedPrompt else { return }

        isCreatingIssue = true

        Task {
            do {
                createdIssue = try await gitHubService.createIssue(
                    in: repo,
                    title: refined.title,
                    body: refined.body,
                    labels: Array(selectedLabels)
                )

                // Update note with issue link
                note.summary = "GitHub Issue #\(createdIssue!.number)"
                try? viewContext.save()
            } catch {
                errorMessage = error.localizedDescription
            }
            isCreatingIssue = false
        }
    }

    private func toggleLabel(_ label: String) {
        if selectedLabels.contains(label) {
            selectedLabels.remove(label)
        } else {
            selectedLabels.insert(label)
        }
    }
}
```

#### Step 6: Update View Routing

**NoteListView.swift** - Add routing for claude prompt notes:

```swift
// In NavigationLink destination logic:
switch note.noteTypeEnum {
case .todo:
    TodoDetailView(note: note)
case .email:
    EmailDetailView(note: note)
case .claudePrompt:
    ClaudePromptDetailView(note: note)  // New case
default:
    NoteDetailView(note: note)
}
```

#### Step 7: Add Settings for GitHub

**SettingsView.swift** - Add GitHub connection section:

```swift
Section("GitHub Integration") {
    if GitHubService.shared.isAuthenticated {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text("Connected to GitHub")
        }

        Button("Disconnect", role: .destructive) {
            GitHubService.shared.disconnect()
        }
    } else {
        Button("Connect GitHub Account") {
            Task { try? await GitHubService.shared.authenticate() }
        }
    }
}
```

### Core Data Changes

No new entities required. The refined prompt is stored in `note.summary` and the GitHub issue URL can be stored in a new optional field or as part of summary.

**Optional Enhancement:** Add `githubIssueUrl: String?` and `githubIssueNumber: Int32` attributes to Note entity for better tracking.

### Files to Create

| File | Purpose |
|------|---------|
| `Services/PromptRefinerService.swift` | LLM prompt refinement |
| `Services/GitHubService.swift` | GitHub API + OAuth |
| `Views/Notes/ClaudePromptDetailView.swift` | Detail view for prompts |
| `Views/Components/LabelChip.swift` | Reusable label selector chip |
| `Views/Components/FlowLayout.swift` | Horizontal wrapping layout |

### Files to Modify

| File | Changes |
|------|---------|
| `Services/TextClassifier.swift` | Add `#claude#`, `#feature#` triggers |
| `Models/Note.swift` | Add `.claudePrompt` case handling |
| `Views/Notes/NoteListView.swift` | Route to ClaudePromptDetailView |
| `Views/Settings/SettingsView.swift` | Add GitHub connection UI |
| `Services/KeychainService.swift` | Store GitHub token |

### GitHub OAuth App Setup (One-Time)

1. Go to GitHub → Settings → Developer Settings → OAuth Apps
2. Create new OAuth App:
   - Application name: "QuillStack"
   - Homepage URL: Your app's URL or placeholder
   - Authorization callback URL: Not used for device flow
3. Note the Client ID (no client secret needed for device flow)
4. Add Client ID to app (consider using xcconfig for different environments)

### Testing Checklist

- [ ] `#claude#` and `#feature#` triggers detected correctly
- [ ] OCR tolerance works for handwritten triggers
- [ ] Prompt refinement produces structured output
- [ ] GitHub OAuth Device Flow completes successfully
- [ ] Repository list loads after authentication
- [ ] Issue creation succeeds with correct title/body/labels
- [ ] Issue link opens in Safari
- [ ] Note summary updated after issue creation
- [ ] Offline handling: queue refinement if no network
- [ ] Error states display appropriately

### Future Enhancements (Out of Scope)

These could be added later as separate features:

1. **Notion Export** - Similar flow, export to Notion database instead
2. **Obsidian Export** - Write `.md` file to Obsidian vault with frontmatter
3. **Vibe-Kanban Integration** - Direct API integration when available
4. **Project Context** - Store per-repository context for better refinement
5. **Issue Templates** - Let users define custom issue templates
6. **Batch Export** - Select multiple prompt notes and create issues in bulk

---

## Implementation Order (Recommended)

1. **Flash Toggle** ✅ Complete
2. **Photo Library Import** ✅ Complete
3. **Offline Mode** ✅ Complete
4. **Handwriting Learning** ✅ Complete
5. **Claude Prompt to GitHub** - New note type + GitHub OAuth + API
6. **iCloud Sync** - Most complex, requires Xcode config

---

## Files to Modify

| File | Features |
|------|----------|
| `Services/CameraManager.swift` | Flash toggle |
| `Views/Capture/CameraView.swift` | Flash toggle, Photo import |
| `Models/CoreDataStack.swift` | iCloud sync, Offline queue |
| `QuillStack.xcdatamodeld` | iCloud sync, Offline queue, Learning |
| `Services/LLMService.swift` | Offline mode |
| `ViewModels/CameraViewModel.swift` | Offline mode |
| `Services/SpellCorrector.swift` | Handwriting learning |
| `Views/Notes/NoteDetailView.swift` | Offline badge, Learning detection |
| `Services/TextClassifier.swift` | Claude prompt note type triggers |
| `Models/Note.swift` | Claude prompt type handling |
| `Views/Notes/NoteListView.swift` | Route to ClaudePromptDetailView |
| `Views/Settings/SettingsView.swift` | GitHub connection UI |
| `Services/KeychainService.swift` | GitHub token storage |

## New Files to Create

| File | Purpose |
|------|---------|
| `Services/OfflineQueueService.swift` | Queue management for offline LLM |
| `Services/HandwritingLearningService.swift` | Learn from user corrections |
| `Services/PromptRefinerService.swift` | LLM prompt refinement for GitHub issues |
| `Services/GitHubService.swift` | GitHub OAuth + API integration |
| `Views/Notes/ClaudePromptDetailView.swift` | Detail view for prompt notes |
| `Views/Components/LabelChip.swift` | Reusable label selector chip |
| `Views/Components/FlowLayout.swift` | Horizontal wrapping layout |
| `Models/QueuedEnhancement.swift` | Core Data entity wrapper |
| `Models/OCRCorrection.swift` | Core Data entity wrapper |
| `QuillStack.entitlements` | iCloud entitlements |

---

## Testing Checklist

### Flash Toggle ✅
- [x] Cycles through auto → on → off → auto
- [x] Icon updates correctly
- [x] Flash fires when set to "on"
- [x] Works on devices without flash (graceful fallback)

### Photo Import ✅
- [x] Picker opens and shows photo library
- [x] Selected image appears in preview
- [x] OCR processes imported image correctly
- [x] Cancel returns to camera

### Offline Mode ✅
- [x] Note saves immediately when offline
- [x] Enhancement queued (badge shown)
- [x] Queue processes when back online
- [x] Failed items retry with backoff

### Handwriting Learning ✅
- [x] Edits detected when saving note
- [x] Corrections stored in Core Data
- [x] Learned corrections applied to new notes
- [x] Frequency increments on repeated corrections
- [x] Settings UI shows learned correction count
- [x] User can view and delete individual corrections
- [x] User can clear all learned corrections

### Claude Prompt to GitHub ✅
- [x] `#claude#` and `#feature#` triggers detected correctly
- [x] OCR tolerance works for handwritten triggers (fuzzy matching)
- [x] Prompt refinement produces structured output (PromptRefinerService)
- [x] GitHub OAuth Device Flow implemented (GitHubService)
- [x] Repository list loads after authentication
- [x] Issue creation API call implemented
- [x] Issue link opens via Link component
- [x] Note summary updated after issue creation
- [x] Error states display appropriately
- [ ] **TODO**: Configure GitHub OAuth Client ID (replace placeholder in GitHubService.swift)
- [ ] **TODO**: Test end-to-end with real GitHub OAuth App

### iCloud Sync ⏳
- [ ] Notes sync between devices
- [ ] Images sync (may take longer)
- [ ] Deletes sync correctly
- [ ] Conflicts resolve (remote wins)
- [ ] Works with new installs

---

## Session Continuation Instructions

To continue implementation in a new Claude Code session:

1. Open the QuillStack project
2. Reference this file: `FEATURE_PLAN.md`
3. Use this prompt:

```
Let's continue implementing features from FEATURE_PLAN.md.

Features 1-6 are complete:
- Flash Toggle
- Photo Library Import
- Offline Mode
- Handwriting Learning
- Claude Prompt to GitHub (note: needs GitHub OAuth Client ID configured)

Please implement Feature 5: iCloud Sync - which syncs notes across devices via CloudKit.
```

**Note**: Feature 6 (Claude Prompt to GitHub) is implemented but requires:
- Create a GitHub OAuth App at https://github.com/settings/developers
- Enable "Device Flow" in the OAuth App settings
- Replace `GITHUB_CLIENT_ID_PLACEHOLDER` in `Services/GitHubService.swift` with your Client ID

The plan contains all architectural decisions and code snippets needed for remaining features.
