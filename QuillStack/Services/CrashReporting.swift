import Foundation
import Sentry

enum CrashReporting {

    /// Breadcrumb `data` keys this app is allowed to transmit. Everything else —
    /// including SDK-generated keys carrying view names or paths — is stripped
    /// before leaving the device. No key here may hold user content.
    private static let allowedBreadcrumbKeys: Set<String> = [
        "pageCount", "tagCount", "engine", "charCount", "code", "type"
    ]

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
            // No URLSession in this app, and interaction traces name views —
            // both are off to keep transmitted data to crashes and performance.
            options.enableCaptureFailedRequests = false
            options.enableUserInteractionTracing = false
            options.tracesSampleRate = 0.2
            #if DEBUG
            options.environment = "development"
            #else
            options.environment = "production"
            #endif

            // Client-side IP scrubbing. Sentry's ingest also infers IP server-side;
            // "Prevent Storing of IP Addresses" must be enabled in the project too.
            options.beforeSend = { event in
                event.user?.ipAddress = nil
                return event
            }

            // Defense in depth: even if a caller regresses, only allowlisted
            // scalar keys survive.
            options.beforeBreadcrumb = { crumb in
                if let data = crumb.data {
                    crumb.data = data.filter { allowedBreadcrumbKeys.contains($0.key) }
                }
                return crumb
            }
        }
    }

    // MARK: - Breadcrumbs
    //
    // These carry counts and stable codes only — never tag names, OCR text,
    // extracted fields, or raw error strings.

    static func captureStarted(pageCount: Int) {
        let crumb = Breadcrumb(level: .info, category: "capture")
        crumb.message = "Capture started"
        crumb.data = ["pageCount": pageCount]
        SentrySDK.addBreadcrumb(crumb)
    }

    static func tagsSelected(count: Int) {
        let crumb = Breadcrumb(level: .info, category: "capture")
        crumb.message = "Tags selected"
        crumb.data = ["tagCount": count]
        SentrySDK.addBreadcrumb(crumb)
    }

    static func ocrRequested(engine: String, tagCount: Int) {
        let crumb = Breadcrumb(level: .info, category: "ocr")
        crumb.message = "OCR requested"
        crumb.data = ["engine": engine, "tagCount": tagCount]
        SentrySDK.addBreadcrumb(crumb)
    }

    static func ocrCompleted(charCount: Int) {
        let crumb = Breadcrumb(level: .info, category: "ocr")
        crumb.message = "OCR completed"
        crumb.data = ["charCount": charCount]
        SentrySDK.addBreadcrumb(crumb)
    }

    static func ocrFailed(code: OCRFailureCode) {
        let crumb = Breadcrumb(level: .error, category: "ocr")
        crumb.message = "OCR failed"
        crumb.data = ["code": code.rawValue]
        SentrySDK.addBreadcrumb(crumb)
    }

    static func actionTapped(_ actionType: String) {
        let crumb = Breadcrumb(level: .info, category: "action")
        crumb.message = "Quick action tapped"
        crumb.data = ["type": actionType]
        SentrySDK.addBreadcrumb(crumb)
    }

}
