# Classification Accuracy Testing

This directory contains tools for testing and measuring the accuracy of QuillStack's note type classification system.

## Overview

The classification accuracy testing framework evaluates how well the LLM-powered classification performs against known test cases. This helps inform decisions about:

1. Whether auto-detection is reliable enough
2. Which note types need hashtags vs can rely on LLM
3. When to proceed with spatial segmentation
4. Where prompt engineering improvements are needed

## Files

### `ClassificationTestCases.swift`
Comprehensive test suite with ~40 test cases covering:
- All 12 note types
- Easy, medium, and hard difficulty levels
- Edge cases (quotes vs text-with-quotes, reminders vs todos, etc.)
- Ambiguous cases (multiple valid interpretations)

Test cases are categorized:
- **Obvious**: Should be 100% accurate (e.g., clear business card)
- **Edge Case**: Challenging but should work (e.g., meeting note with quote)
- **Ambiguous**: Multiple valid interpretations (e.g., "pick up dry cleaning")

### `ClassificationAccuracyTest.swift`
Test runner that:
- Executes all test cases through the actual classification system
- Measures accuracy overall, by type, and by difficulty
- Identifies specific failures with details
- Provides actionable recommendations
- Exports results as JSON

### `ClassificationTestView.swift`
SwiftUI debug view accessible from Settings > Debug Tools that:
- Shows test progress in real-time
- Displays results with visual indicators
- Lists failures with context
- Provides strategic recommendations
- Can be run on device or simulator

## Running Tests

### Option 1: Via Settings (Recommended for Manual Testing)

1. Build and run QuillStack in Debug mode
2. Go to **Settings** tab
3. Scroll to **Debug Tools** section
4. Tap **Classification Accuracy Test**
5. Tap **Run All Tests**
6. Wait 2-3 minutes for completion (includes API rate limiting delays)
7. Review results

### Option 2: Via Code (For Automated Testing)

```swift
// In any async context:
Task {
    await runClassificationAccuracyTests()
}
```

Results will be printed to console with full analysis.

## Setup Instructions

### 1. Add Files to Xcode Project

These files need to be added to the Xcode project target:

```
Tests/
  ├── ClassificationTestCases.swift
  ├── ClassificationAccuracyTest.swift
  └── README.md

Views/Debug/
  └── ClassificationTestView.swift
```

**Steps:**
1. In Xcode, right-click on project navigator
2. Select "Add Files to QuillStack..."
3. Select the `Tests` folder and `Views/Debug/ClassificationTestView.swift`
4. Ensure "QuillStack" target is checked
5. Build to verify compilation

### 2. Ensure Claude API Key is Set

Tests require a valid Claude API key in Settings to test LLM classification.

**Note:** Tests will consume API tokens (~40 calls × 20 tokens = ~800 tokens total ≈ $0.002)

### 3. Disable Rate Limiting (Optional)

For faster test runs during development, you can temporarily increase rate limits in `LLMRateLimiter.swift`:

```swift
// Temporarily increase for testing
private let maxCallsPerMinute = 60  // from 10
private let maxCallsPerHour = 300   // from 100
```

**Remember to revert before committing!**

## Interpreting Results

### Accuracy Thresholds

| Accuracy | Status | Action |
|----------|--------|--------|
| ≥ 90% | ✅ Excellent | Type is ready for auto-detection |
| 70-89% | ⚠️ Good | Improve prompts, consider auto-detection |
| < 70% | ❌ Needs Work | Keep hashtags, improve prompts |

### Overall Recommendations

**≥ 85% Overall Accuracy:**
- ✅ LLM classification is performing well
- → Proceed with spatial segmentation (Step 3)
- → Make hashtags optional (override only)

**70-84% Overall Accuracy:**
- ⚠️ LLM classification needs improvement
- → Focus on prompt engineering (Step 2)
- → Keep hashtags primary for low-accuracy types
- → Consider hybrid approach

**< 70% Overall Accuracy:**
- ❌ LLM classification needs significant work
- → Major prompt engineering effort needed
- → May need more heuristic rules
- → Consider keeping hashtags as primary method

## Test Cases Explained

### Critical Cases

**Quote Detection (Most Important)**
```swift
// Pure quote - should be .general (no .quote type yet)
"The best time to plant a tree was 20 years ago."
- Chinese Proverb

// Meeting with quote - should be .meeting, NOT quote
Quote from today's meeting:
"We need to ship by Friday"
```

**Intent vs Content**
```swift
// Intent-based (should be .reminder)
Remember to call Mom on Sunday

// Content-based (should be .contact)
John Smith
john@example.com
555-1234
```

### Edge Cases

- **Todo vs Reminder**: "Pick up dry cleaning" (ambiguous)
- **Idea vs Meeting**: "Ideas from brainstorm session" (could be either)
- **Email vs General**: Text that mentions email but isn't a draft

## Expected Results (Baseline)

Based on current implementation, expected accuracy by type:

| Type | Expected Accuracy | Rationale |
|------|------------------|-----------|
| Contact | 95%+ | Strong heuristics + LLM |
| Receipt/Expense | 90%+ | Clear patterns ($ amounts, totals) |
| Shopping | 90%+ | List format + specific items |
| Recipe | 85%+ | Ingredients + instructions keywords |
| Meeting | 85%+ | Agenda, attendees keywords |
| Event | 80%+ | Date/time/location patterns |
| Email | 80%+ | To/From/Subject headers |
| Todo | 75%+ | Checklist patterns |
| Reminder | 70%+ | Similar to todo, hard to distinguish |
| Idea | 70%+ | Subjective, varies |
| Claude Prompt | 65%+ | Only clear with explicit mention |
| General | 60%+ | Catch-all for unclear notes |

## Next Steps After Testing

Based on results:

1. **If accuracy ≥ 85%:**
   - Document which types work well
   - Proceed to Step 3: Spatial Segmentation
   - Update QUI-105 with confidence in auto-detection

2. **If accuracy 70-84%:**
   - Identify problem types
   - Proceed to Step 2: Improve prompts
   - Consider few-shot examples
   - Re-run tests after improvements

3. **If accuracy < 70%:**
   - Major prompt engineering session needed
   - Consider architectural changes
   - May need to keep hashtags as primary
   - Re-evaluate auto-detection strategy

## Troubleshooting

### "No API key" error
- Go to Settings and add Claude API key
- Restart tests

### "Rate limited" error
- Wait a few minutes and try again
- Or increase rate limits temporarily (see Setup #3)

### Tests fail to compile
- Ensure all files are added to Xcode project
- Check that `NoteType` includes all expected types
- Verify imports are correct

### Unexpected results
- Check LLM prompt in `TextClassifier.swift:206-222`
- Verify test expectations match current `NoteType` enum
- Consider if test case is truly unambiguous

## Contributing Test Cases

To add new test cases:

1. Add to `ClassificationTestCases.swift` in `allTests` array
2. Specify expected type, category, and difficulty
3. Add notes explaining the test case
4. Run tests to verify
5. Update expected accuracy table if needed

## Future Enhancements

- [ ] Export detailed JSON results for analysis
- [ ] Track accuracy over time (regression detection)
- [ ] Add image-based test cases
- [ ] Test multi-note segmentation accuracy
- [ ] Automated CI/CD integration
- [ ] Compare different LLM models (Haiku vs Sonnet)
- [ ] A/B test different prompt variations
