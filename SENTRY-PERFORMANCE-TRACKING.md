# Sentry Performance Tracking - Implementation Summary

**Date:** 2026-01-03  
**Status:** ✅ **Implemented**

---

## What Was Added

I've added comprehensive Sentry performance transaction tracking to your most critical functions. Now you'll see detailed performance data in Sentry for:

### 1. Camera Capture Flow (`CameraViewModel.processImage()`)
- **Transaction**: `CameraViewModel.processImage`
- **Spans tracked**:
  - Image orientation correction
  - OCR text recognition (with text length, confidence, low-confidence words)
  - LLM enhancement (with note type, text changes)
  - Database save (with note type, section index)
- **Context data**: Image size, sections saved, completion status

### 2. OCR Processing (`OCRService.recognizeTextWithConfidence()`)
- **Transaction**: `OCRService.recognizeTextWithConfidence`
- **Spans tracked**:
  - Image preprocessing
  - Vision framework OCR (with text length, confidence, line count)
- **Context data**: Image size, OCR results

### 3. LLM Enhancement (`LLMService.enhanceOCRText()`)
- **Transaction**: `LLMService.enhanceOCRText`
- **Spans tracked**:
  - Prompt building
  - Claude API request
  - Text diff calculation
- **Context data**: Note type, text lengths, changes count

### 4. Voice Transcription (`VoiceViewModel.transcribeAndSave()`)
- **Transaction**: `VoiceViewModel.transcribeAndSave`
- **Spans tracked**:
  - Speech recognition
  - Text classification/splitting
  - Database save (per section)
- **Context data**: Audio duration, sections saved

---

## What You'll See in Sentry

### Performance Dashboard
- **Transaction names**: Clear operation names (e.g., "CameraViewModel.processImage")
- **Duration**: Total time for each operation
- **Spans**: Breakdown of time spent in each sub-operation
- **Context**: Image sizes, text lengths, note types, etc.

### Example Transaction View
```
CameraViewModel.processImage (2.3s)
├── image.orientation (0.1s)
├── ocr.recognize (1.5s)
│   ├── image.preprocess (0.2s)
│   └── ocr.vision (1.3s)
├── llm.enhance (0.6s)
│   ├── llm.prompt (0.0s)
│   ├── llm.api (0.5s)
│   └── llm.diff (0.1s)
└── database.save (0.1s)
```

### Performance Alerts
Sentry will automatically alert you when:
- Transactions exceed thresholds (configurable)
- Spans are slower than expected
- Error rates increase

---

## How to Use

### 1. View Performance Data
1. Go to Sentry → Performance
2. Look for transactions:
   - `CameraViewModel.processImage`
   - `OCRService.recognizeTextWithConfidence`
   - `LLMService.enhanceOCRText`
   - `VoiceViewModel.transcribeAndSave`

### 2. Identify Bottlenecks
- Click on a transaction to see span breakdown
- Slow spans are highlighted
- Context data shows what was being processed

### 3. Share with Cursor for Analysis
```
"Review this Sentry performance issue:
Transaction: CameraViewModel.processImage
Duration: 3.2s
Slow spans:
- OCR: 1.8s
- LLM: 1.1s

Analyze and suggest optimizations."
```

### 4. Set Performance Targets
In Sentry, you can set:
- **P50 target**: 50% of transactions should be under X seconds
- **P95 target**: 95% of transactions should be under X seconds
- **P99 target**: 99% of transactions should be under X seconds

**Recommended targets:**
- `CameraViewModel.processImage`: < 2s (P95)
- `OCRService.recognizeTextWithConfidence`: < 1.5s (P95)
- `LLMService.enhanceOCRText`: < 2s (P95)
- `VoiceViewModel.transcribeAndSave`: < 3s (P95)

---

## Files Modified

1. **ViewModels/CameraViewModel.swift**
   - Added transaction tracking to `processImage()`
   - Added spans for OCR, LLM, and save operations
   - Added error status tracking

2. **Services/OCRService.swift**
   - Added transaction tracking to `recognizeTextWithConfidence()`
   - Added spans for preprocessing and Vision OCR

3. **Services/LLMService.swift**
   - Added transaction tracking to `enhanceOCRText()`
   - Added spans for prompt building, API call, and diff calculation

4. **ViewModels/VoiceViewModel.swift**
   - Added transaction tracking to `transcribeAndSave()`
   - Added spans for transcription, classification, and save

---

## Next Steps

### Immediate
1. **Test the app** - Capture a note and check Sentry for the new transactions
2. **Review performance** - See baseline performance data
3. **Set alerts** - Configure Sentry to alert on slow transactions

### Ongoing
1. **Weekly review** - Check Sentry performance dashboard
2. **Share issues with Cursor** - Use Cursor to analyze and fix bottlenecks
3. **Monitor trends** - Watch for performance regressions

### Future Enhancements
- Add tracking to more functions (search, export, etc.)
- Add custom metrics (e.g., words processed per second)
- Set up automated performance regression detection

---

## API Key Storage

Your Sentry API key is stored securely in:
- `.sentry-api-key` (gitignored)
- Can be used for fetching issues programmatically

**Note:** The API key may need additional permissions for full API access. The performance tracking code works regardless of API access.

---

## Troubleshooting

### Not seeing transactions in Sentry?
1. Check that `tracesSampleRate = 1.0` in `QuillStackApp.swift`
2. Verify Sentry DSN is correct
3. Make sure you're testing on a device (not simulator)
4. Check Sentry dashboard filters (date range, environment)

### Transactions missing spans?
- Spans are created automatically when child operations run
- If an operation fails early, some spans may not appear
- Check transaction status (ok, error, etc.)

### Performance data seems off?
- First few transactions may be slower (cold start)
- Test multiple times for accurate averages
- Check device performance (older devices are slower)

---

## Example: Using Cursor to Fix Performance Issues

**Scenario:** Sentry shows OCR taking 2.5s (target: <1.5s)

**Step 1:** Share with Cursor
```
"Sentry shows OCRService.recognizeTextWithConfidence taking 2.5s.
Target is <1.5s. Analyze and optimize."
```

**Step 2:** Cursor analyzes
- Finds `OCRService.swift`
- Identifies bottlenecks
- Suggests optimizations (image resizing, caching, etc.)

**Step 3:** Implement fix
```
"Implement the image resizing optimization for OCR"
```

**Step 4:** Verify
- Test the app
- Check Sentry - should see improved performance
- Monitor over time

---

**You're all set!** Performance tracking is now active. Check Sentry after your next app test to see the data.

