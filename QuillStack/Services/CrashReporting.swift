import Foundation
import Sentry

enum CrashReporting {

    static func start() {
        guard let dsn = Bundle.main.object(forInfoDictionaryKey: "SENTRY_DSN") as? String,
              !dsn.isEmpty,
              dsn.hasPrefix("https://") else {
            return
        }

        SentrySDK.start { options in
            options.dsn = dsn
            options.enableAutoSessionTracking = true
            options.enableAppHangTracking = true
            options.enableCaptureFailedRequests = true
            options.enableUserInteractionTracing = true
            options.tracesSampleRate = 0.2
            #if DEBUG
            options.environment = "development"
            #else
            options.environment = "production"
            #endif
        }
    }

    // MARK: - Breadcrumbs

    static func captureStarted(pageCount: Int) {
        let crumb = Breadcrumb(level: .info, category: "capture")
        crumb.message = "Capture started"
        crumb.data = ["pageCount": pageCount]
        SentrySDK.addBreadcrumb(crumb)
    }

    static func tagsSelected(_ tagNames: [String]) {
        let crumb = Breadcrumb(level: .info, category: "capture")
        crumb.message = "Tags selected"
        crumb.data = ["tags": tagNames]
        SentrySDK.addBreadcrumb(crumb)
    }

    static func ocrRequested(engine: String, tagCount: Int) {
        let crumb = Breadcrumb(level: .info, category: "ocr")
        crumb.message = "OCR requested"
        crumb.data = ["engine": engine, "tagCount": tagCount]
        SentrySDK.addBreadcrumb(crumb)
    }

    static func ocrCompleted(charCount: Int, hasContact: Bool, hasEvent: Bool, hasReceipt: Bool) {
        let crumb = Breadcrumb(level: .info, category: "ocr")
        crumb.message = "OCR completed"
        crumb.data = [
            "charCount": charCount,
            "hasContact": hasContact,
            "hasEvent": hasEvent,
            "hasReceipt": hasReceipt
        ]
        SentrySDK.addBreadcrumb(crumb)
    }

    static func ocrFailed(error: String) {
        let crumb = Breadcrumb(level: .error, category: "ocr")
        crumb.message = "OCR failed"
        crumb.data = ["error": error]
        SentrySDK.addBreadcrumb(crumb)
    }

    static func actionTapped(_ actionType: String) {
        let crumb = Breadcrumb(level: .info, category: "action")
        crumb.message = "Quick action tapped"
        crumb.data = ["type": actionType]
        SentrySDK.addBreadcrumb(crumb)
    }

}
