# Cursor + Sentry Integration Guide

This guide explains how to use Cursor to review and resolve Sentry performance issues in QuillStack.

## Overview

Cursor can help you:
- **Analyze** Sentry performance data
- **Identify** performance bottlenecks in your code
- **Suggest** optimizations
- **Implement** performance improvements
- **Add** performance tracking to new code

---

## Current Sentry Setup

Your app already has Sentry configured with:
- ✅ Performance monitoring enabled (`tracesSampleRate = 1.0`)
- ✅ Automatic breadcrumbs
- ✅ Error tracking with context
- ✅ Session tracking

**DSN**: `https://2b1c02a12b2cddac3d64fd412f5852be@o4510637025918976.ingest.us.sentry.io/4510641123426304`

---

## Workflow: Reviewing Sentry Performance Issues

### Step 1: Get Sentry Issue Details

**Option A: Share Sentry URL**
```
Paste the Sentry performance issue URL in Cursor Chat:
"Review this Sentry performance issue: [URL]"
```

**Option B: Share Performance Data**
```
Copy performance data from Sentry and paste:
- Transaction name
- Duration
- Slow spans
- Stack traces
- Device/OS info
```

**Option C: Use Sentry API** (Advanced)
```bash
# Fetch performance issue via API
curl -H "Authorization: Bearer YOUR_SENTRY_TOKEN" \
  "https://sentry.io/api/0/organizations/ORG/projects/PROJECT/events/EVENT_ID/"
```

### Step 2: Cursor Analysis

**Example Prompt:**
```
@Sentry performance issue
Transaction: "CameraViewModel.processImage"
Duration: 3.2s (target: <1s)
Slow spans:
- OCR processing: 1.8s
- LLM enhancement: 1.1s
- Core Data save: 0.3s

Device: iPhone 13, iOS 17.2
App version: 1.0.2

Analyze the code and suggest optimizations.
```

**Cursor will:**
1. Find relevant code (`CameraViewModel.swift`, `OCRService.swift`, etc.)
2. Analyze performance bottlenecks
3. Suggest specific optimizations
4. Show code changes needed

### Step 3: Implement Fixes

**Use Cursor Composer:**
```
@CameraViewModel.swift @OCRService.swift
Optimize processImage() to reduce duration from 3.2s to <1s:
- Parallelize OCR and image processing where possible
- Cache LLM results for similar text
- Use background context for Core Data saves
- Add performance tracking spans
```

**Or use Cursor Chat for iterative improvements:**
```
"Add Sentry performance tracking to OCRService.recognizeTextWithConfidence()"
```

---

## Adding Performance Tracking

### Pattern 1: Transaction Tracking

**Before (no tracking):**
```swift
func processImage(_ image: UIImage) async {
    // ... processing code ...
}
```

**After (with Sentry transaction):**
```swift
func processImage(_ image: UIImage) async {
    let transaction = SentrySDK.startTransaction(
        name: "CameraViewModel.processImage",
        operation: "camera.capture"
    )
    defer { transaction.finish() }
    
    // ... processing code ...
}
```

### Pattern 2: Span Tracking

**Track individual operations:**
```swift
func processImage(_ image: UIImage) async {
    let transaction = SentrySDK.startTransaction(
        name: "CameraViewModel.processImage",
        operation: "camera.capture"
    )
    defer { transaction.finish() }
    
    // OCR span
    let ocrSpan = transaction.startChild(
        operation: "ocr.recognize",
        description: "OCR text recognition"
    )
    let ocrResult = try await ocrService.recognizeTextWithConfidence(from: image)
    ocrSpan.finish()
    
    // LLM span
    let llmSpan = transaction.startChild(
        operation: "llm.enhance",
        description: "LLM text enhancement"
    )
    let enhanced = try await llmService.enhanceOCRText(ocrResult.fullText)
    llmSpan.finish()
    
    // Save span
    let saveSpan = transaction.startChild(
        operation: "database.save",
        description: "Save note to Core Data"
    )
    await saveNote(text: enhanced)
    saveSpan.finish()
}
```

### Pattern 3: Background Operation Tracking

**For Core Data operations:**
```swift
func saveNote(text: String) async {
    let span = SentrySDK.startTransaction(
        name: "Note.save",
        operation: "database.save"
    )
    defer { span.finish() }
    
    let context = CoreDataStack.shared.newBackgroundContext()
    await context.perform {
        // ... save logic ...
        span.setData(value: ["note_length": text.count], key: "note_info")
    }
}
```

---

## Common Performance Issues & Cursor Solutions

### Issue 1: Slow OCR Processing

**Sentry shows:** OCR taking 2+ seconds

**Cursor Analysis:**
```
@OCRService.swift
The OCR processing is taking 2+ seconds. Analyze:
1. Is image preprocessing optimized?
2. Can we reduce image size before OCR?
3. Are we using the latest Vision API revision?
4. Can we cache results for similar images?
```

**Cursor Suggestions:**
- Resize large images before OCR
- Use `VNRecognizeTextRequestRevision3` (already using)
- Cache OCR results for identical images
- Process in background thread (already doing)

### Issue 2: LLM API Latency

**Sentry shows:** LLM calls taking 1.5+ seconds

**Cursor Analysis:**
```
@LLMService.swift
LLM API calls are slow. Check:
1. Are we batching requests?
2. Can we reduce prompt size?
3. Should we queue requests?
4. Is the API proxy adding latency?
```

**Cursor Suggestions:**
- Use existing `OfflineQueueService` for queuing
- Reduce prompt size by removing unnecessary context
- Add request timeout handling
- Consider caching common responses

### Issue 3: Core Data Save Bottleneck

**Sentry shows:** Database saves taking 500ms+

**Cursor Analysis:**
```
@CoreDataStack.swift @CameraViewModel.swift
Core Data saves are slow. Check:
1. Are we using background contexts?
2. Are we batching saves?
3. Is the data model optimized?
4. Are we doing unnecessary fetches?
```

**Cursor Suggestions:**
- Already using background contexts ✅
- Batch multiple saves together
- Use batch inserts for bulk operations
- Optimize Core Data model relationships

### Issue 4: UI Blocking Operations

**Sentry shows:** Main thread blocking

**Cursor Analysis:**
```
@ViewModels/CameraViewModel.swift
Check for @MainActor operations that block UI:
1. Are heavy operations on main thread?
2. Can we move work to background?
3. Are we updating UI too frequently?
```

**Cursor Suggestions:**
- Ensure heavy operations use `Task` or background queues
- Use `@MainActor` only for UI updates
- Debounce UI updates
- Use `async/await` properly

---

## Performance Monitoring Best Practices

### 1. Add Transactions for Key Operations

**Add to these locations:**
- `CameraViewModel.processImage()` - Image capture flow
- `VoiceViewModel.transcribeAndSave()` - Voice note flow
- `LLMService.enhanceOCRText()` - LLM calls
- `OCRService.recognizeTextWithConfidence()` - OCR operations
- `CoreDataStack.save()` - Database operations

### 2. Track Custom Metrics

```swift
// Track custom metrics
SentrySDK.metrics.increment(
    key: "ocr.words_processed",
    value: wordCount,
    unit: .none,
    tags: ["note_type": noteType.rawValue]
)

SentrySDK.metrics.distribution(
    key: "llm.response_time",
    value: responseTime,
    unit: .millisecond
)
```

### 3. Set Performance Targets

```swift
// Set performance targets
let transaction = SentrySDK.startTransaction(...)
transaction.setMeasurement(
    name: "app_start_time",
    value: startTime,
    unit: .millisecond
)

// Sentry will alert if target exceeded
```

### 4. Add Context to Performance Issues

```swift
transaction.setData(value: [
    "image_size": "\(image.size.width)x\(image.size.height)",
    "note_type": noteType.rawValue,
    "ocr_confidence": ocrResult.averageConfidence
], key: "performance_context")
```

---

## Cursor Workflow Examples

### Example 1: Review Slow Transaction

**You:** "Review this Sentry performance issue: [URL]"

**Cursor:**
1. Analyzes Sentry data
2. Finds relevant code files
3. Identifies bottlenecks
4. Suggests optimizations

**You:** "Implement the OCR optimization"

**Cursor:**
1. Modifies `OCRService.swift`
2. Adds image resizing
3. Adds performance tracking
4. Updates tests if needed

### Example 2: Add Performance Tracking

**You:** "Add Sentry performance tracking to `CameraViewModel.processImage()`"

**Cursor:**
1. Adds transaction tracking
2. Adds spans for each operation
3. Adds context data
4. Ensures proper cleanup

### Example 3: Optimize Based on Sentry Data

**You:** "Sentry shows LLM calls taking 1.5s. Optimize `LLMService.enhanceOCRText()`"

**Cursor:**
1. Analyzes current implementation
2. Suggests optimizations:
   - Reduce prompt size
   - Add request caching
   - Use streaming responses
   - Add timeout handling
3. Implements selected optimizations

---

## Sentry API Integration (Optional)

### Fetch Performance Issues via API

Create a script to fetch Sentry issues for Cursor:

```bash
#!/bin/bash
# fetch-sentry-issues.sh

SENTRY_TOKEN="your-auth-token"
ORG="your-org"
PROJECT="quillstack"

# Fetch slow transactions
curl -H "Authorization: Bearer $SENTRY_TOKEN" \
  "https://sentry.io/api/0/organizations/$ORG/events/?project=$PROJECT&query=transaction.duration:>1000" \
  > sentry-performance-issues.json

# Format for Cursor
jq -r '.[] | "Transaction: \(.transaction)\nDuration: \(.measurements.duration.value)ms\nURL: \(.permalink)\n---\n"' \
  sentry-performance-issues.json > sentry-issues-for-cursor.md
```

Then share `sentry-issues-for-cursor.md` with Cursor.

---

## Quick Reference

### Cursor Commands for Sentry Issues

```
# Review performance issue
"Review this Sentry performance issue: [URL or data]"

# Add performance tracking
"Add Sentry transaction tracking to [function]"

# Optimize based on Sentry data
"Sentry shows [operation] taking [time]. Optimize [file]"

# Analyze slow spans
"Analyze why [span] is slow in [file]"

# Add performance monitoring
"Add Sentry performance spans to [operation]"
```

### Sentry Performance Patterns

```swift
// Pattern 1: Simple transaction
let transaction = SentrySDK.startTransaction(name: "Operation", operation: "type")
defer { transaction.finish() }

// Pattern 2: Transaction with spans
let span = transaction.startChild(operation: "sub.operation")
// ... work ...
span.finish()

// Pattern 3: Background operation
Task.detached {
    let transaction = SentrySDK.startTransaction(...)
    // ... work ...
    transaction.finish()
}

// Pattern 4: With context
transaction.setData(value: ["key": "value"], key: "context")
```

---

## Integration with Your Workflow

### 1. Daily Review

**Morning routine:**
1. Check Sentry for new performance issues
2. Share top 3 issues with Cursor
3. Cursor analyzes and suggests fixes
4. Create Linear issue (QUI-XX) for each
5. Use Cursor to implement fixes

### 2. Before Release

**Pre-release checklist:**
1. Review Sentry performance dashboard
2. Identify regressions
3. Use Cursor to analyze and fix
4. Test optimizations
5. Monitor post-release

### 3. Performance Regression

**When Sentry alerts:**
1. Get Sentry issue details
2. Share with Cursor: "Analyze this performance regression"
3. Cursor identifies cause
4. Use Cursor to implement fix
5. Create PR with performance improvement

---

## Best Practices

1. **Always add performance tracking** when implementing new features
2. **Review Sentry weekly** for performance trends
3. **Set performance budgets** (e.g., OCR < 1s, LLM < 2s)
4. **Use Cursor to analyze** before optimizing (understand first)
5. **Test optimizations** before deploying
6. **Monitor after changes** to verify improvements

---

## Next Steps

1. **Add performance tracking** to key operations (use Cursor to help)
2. **Set up Sentry alerts** for performance regressions
3. **Create weekly review** workflow with Cursor
4. **Document performance targets** in code comments
5. **Use Cursor to optimize** based on Sentry data

---

**Remember:** Cursor is your performance debugging assistant. Share Sentry data, and Cursor will help you understand and fix performance issues faster.

