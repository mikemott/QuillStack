import SwiftUI
import EventKitUI

struct EventActionView: UIViewControllerRepresentable {
    let extraction: EventExtraction
    let eventStore: EKEventStore
    var onDismiss: () -> Void

    func makeUIViewController(context: Context) -> EventHostController {
        let host = EventHostController()
        host.view.backgroundColor = .clear

        let event = EKEvent(eventStore: eventStore)
        event.title = extraction.title ?? "Untitled Event"

        let baseDate = parseDate(extraction.date)
        let startTime = parseTime(extraction.time)
        let endTime = parseTime(extraction.endTime)

        let startDate = combine(date: baseDate, time: startTime)
            ?? baseDate
            ?? Date()
        event.startDate = startDate
        event.endDate = combine(date: baseDate, time: endTime)
            ?? Calendar.current.date(byAdding: .hour, value: 1, to: startDate)
            ?? startDate

        if let location = extraction.location {
            event.location = location
        }

        if let desc = extraction.description {
            if let detectedURL = extractURL(from: desc) {
                event.url = detectedURL
                let remaining = desc.replacingOccurrences(of: detectedURL.absoluteString, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                if !remaining.isEmpty { event.notes = remaining }
            } else {
                event.notes = desc
            }
        }

        event.calendar = eventStore.defaultCalendarForNewEvents

        host.event = event
        host.store = eventStore
        host.delegate = context.coordinator
        return host
    }

    func updateUIViewController(_ uiViewController: EventHostController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onDismiss: onDismiss) }

    class Coordinator: NSObject, EKEventEditViewDelegate {
        let onDismiss: () -> Void

        init(onDismiss: @escaping () -> Void) {
            self.onDismiss = onDismiss
        }

        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            controller.dismiss(animated: true)
            onDismiss()
        }
    }
}

// MARK: - Date/Time Parsing

private func parseDate(_ string: String?) -> Date? {
    guard let string, !string.isEmpty else { return nil }
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withFullDate]
    if let d = iso.date(from: string) { return d }

    // Formats with explicit year
    for fmt in ["yyyy-MM-dd", "MM/dd/yyyy", "M/d/yyyy", "MMM d, yyyy", "MMMM d, yyyy", "dd/MM/yyyy"] {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = fmt
        if let d = df.date(from: string) { return d }
    }

    // Formats without year — default to current year
    let currentYear = Calendar.current.component(.year, from: Date())
    for fmt in ["MMM d", "MMMM d", "M/d", "MM/dd", "d MMM", "d MMMM"] {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = fmt
        // DateFormatter defaults missing year to 2000; replace with current year
        if let d = df.date(from: string) {
            var comps = Calendar.current.dateComponents([.month, .day], from: d)
            comps.year = currentYear
            return Calendar.current.date(from: comps)
        }
    }
    return nil
}

private func parseTime(_ string: String?) -> DateComponents? {
    guard var s = string?.trimmingCharacters(in: .whitespaces), !s.isEmpty else { return nil }

    // Handle range format: "11:00 - 11:30" → take first part
    if let dash = s.range(of: " - ") ?? s.range(of: "-") {
        s = String(s[s.startIndex..<dash.lowerBound]).trimmingCharacters(in: .whitespaces)
    }

    // 12-hour: "2:00 PM", "2:00PM", "2PM"
    let s_upper = s.uppercased()
    let isPM = s_upper.contains("PM")
    let isAM = s_upper.contains("AM")
    if isPM || isAM {
        let cleaned = s_upper
            .replacingOccurrences(of: "PM", with: "")
            .replacingOccurrences(of: "AM", with: "")
            .trimmingCharacters(in: .whitespaces)
        let parts = cleaned.split(separator: ":").compactMap { Int($0) }
        guard let hour = parts.first else { return nil }
        var h = hour
        if isPM && h != 12 { h += 12 }
        if isAM && h == 12 { h = 0 }
        let m = parts.count > 1 ? parts[1] : 0
        return DateComponents(hour: h, minute: m)
    }

    // 24-hour: "14:00", "9:30"
    let parts = s.split(separator: ":").compactMap { Int($0) }
    guard let hour = parts.first, hour >= 0, hour <= 23 else { return nil }
    let minute = parts.count > 1 ? parts[1] : 0
    return DateComponents(hour: hour, minute: minute)
}

private func combine(date: Date?, time: DateComponents?) -> Date? {
    guard let date, let time else { return nil }
    var cal = Calendar.current
    cal.timeZone = .current
    var comps = cal.dateComponents([.year, .month, .day], from: date)
    comps.hour = time.hour
    comps.minute = time.minute
    return cal.date(from: comps)
}

private func extractURL(from text: String) -> URL? {
    let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    let range = NSRange(text.startIndex..., in: text)
    return detector?.firstMatch(in: text, range: range).flatMap { $0.url }
}

class EventHostController: UIViewController {
    var event: EKEvent?
    var store: EKEventStore?
    weak var delegate: EKEventEditViewDelegate?
    private var didPresent = false

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didPresent, let event, let store else { return }
        didPresent = true

        let editor = EKEventEditViewController()
        editor.event = event
        editor.eventStore = store
        editor.editViewDelegate = delegate
        present(editor, animated: true)
    }
}
