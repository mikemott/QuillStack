import SwiftUI
import EventKitUI

struct EventActionView: UIViewControllerRepresentable {
    let extraction: EventExtraction
    let eventStore: EKEventStore
    var onDismiss: () -> Void

    func makeUIViewController(context: Context) -> UINavigationController {
        let event = EKEvent(eventStore: eventStore)

        event.title = extraction.title ?? "Untitled Event"

        if let dateStr = extraction.date {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            if let date = formatter.date(from: dateStr) {
                event.startDate = date
                event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: date) ?? date
            }
        }

        if let location = extraction.location {
            event.location = location
        }

        if let notes = extraction.description {
            event.notes = notes
        }

        event.calendar = eventStore.defaultCalendarForNewEvents

        let vc = EKEventEditViewController()
        vc.event = event
        vc.eventStore = eventStore
        vc.editViewDelegate = context.coordinator

        let nav = UINavigationController(rootViewController: vc)
        return nav
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, EKEventEditViewDelegate {
        let parent: EventActionView

        init(_ parent: EventActionView) { self.parent = parent }

        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            parent.onDismiss()
        }
    }
}
