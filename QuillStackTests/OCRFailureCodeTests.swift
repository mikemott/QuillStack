import Testing
import Foundation
@testable import QuillStack

@Suite("OCR Failure Codes")
struct OCRFailureCodeTests {

    @Test("Vision errors map to stable codes")
    func mapsVisionErrors() {
        #expect(OCRFailureCode(VisionOCRError.imageEncodingFailed) == .imageUnreadable)
        #expect(OCRFailureCode(VisionOCRError.emptyResponse) == .noTextFound)
        #expect(OCRFailureCode(VisionOCRError.extractionFailed("boom")) == .extractionFailed)
    }

    @Test("Unknown errors map to .unexpected")
    func mapsUnknownErrors() {
        struct Whatever: Error {}
        #expect(OCRFailureCode(Whatever()) == .unexpected)
        #expect(OCRFailureCode(CocoaError(.fileReadNoSuchFile)) == .unexpected)
    }

    /// Vision is deterministic for a given image, so re-running these produces
    /// an identical result. Offering Retry would be a button that cannot work.
    @Test("Deterministic failures are not retryable")
    func deterministicFailuresAreNotRetryable() {
        #expect(OCRFailureCode.noTextFound.isRetryable == false)
        #expect(OCRFailureCode.imageUnreadable.isRetryable == false)
        #expect(OCRFailureCode.noImages.isRetryable == false)
    }

    @Test("Transient failures are retryable")
    func transientFailuresAreRetryable() {
        #expect(OCRFailureCode.unexpected.isRetryable)
        #expect(OCRFailureCode.extractionFailed.isRetryable)
    }

    /// A photo of something with no readable text is a valid capture.
    @Test("noTextFound is an outcome, not an error")
    func noTextFoundIsNotAnError() {
        #expect(OCRFailureCode.noTextFound.isError == false)
        #expect(OCRFailureCode.imageUnreadable.isError)
        #expect(OCRFailureCode.unexpected.isError)
        #expect(OCRFailureCode.extractionFailed.isError)
    }

    @Test("Raw values round-trip for persistence")
    func rawValuesRoundTrip() {
        for code in [OCRFailureCode.noImages, .imageUnreadable, .noTextFound, .extractionFailed, .unexpected] {
            #expect(OCRFailureCode(rawValue: code.rawValue) == code)
        }
    }

    @Test("Every code has a user-facing message")
    func everyCodeHasAMessage() {
        for code in [OCRFailureCode.noImages, .imageUnreadable, .noTextFound, .extractionFailed, .unexpected] {
            #expect(!code.userMessage.isEmpty)
        }
    }

    @Test("Capture surfaces a decoded failure code")
    func captureDecodesFailureCode() {
        let capture = Capture()
        #expect(capture.ocrFailure == nil)

        capture.ocrFailureCode = OCRFailureCode.noTextFound.rawValue
        #expect(capture.ocrFailure == .noTextFound)

        capture.ocrFailureCode = "garbage-not-a-code"
        #expect(capture.ocrFailure == nil, "Unknown persisted values must not crash")
    }

    @Test("Empty image list fails with .noImages and writes no partial data")
    func emptyImagesFailsCleanly() async {
        let result = await CaptureProcessor().process(imageData: [], tagNames: [])
        #expect(result.success == false)
        #expect(result.failure == .noImages)
        #expect(result.ocrText.isEmpty)
        #expect(result.extractedTitle == nil)
        #expect(result.enrichmentJSON == nil)
    }
}
