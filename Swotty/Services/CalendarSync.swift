import UIKit
import EventKit

// MARK: - Calendar sync (Apple Calendar app)
// Each assessment becomes an all-day event on its due date,
// in a calendar named after the app. Any calendar account
// on the device (iCloud, Google, Outlook) will sync it onwards.
final class CalendarSync {
    static let shared = CalendarSync()

    let eventStore = EKEventStore()
    private let enabledKey = "calendarSyncEnabled"
    private let calendarIDKey = "calendarSyncCalendarID"

    var hasAccess: Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(iOS 17.0, *) {
            return status == .fullAccess
        } else {
            return status == .authorized
        }
    }

    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: enabledKey) && hasAccess
    }

    func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: enabledKey)
    }

    func requestAccess(completion: @escaping (Bool) -> Void) {
        if #available(iOS 17.0, *) {
            eventStore.requestFullAccessToEvents { granted, _ in
                DispatchQueue.main.async { completion(granted) }
            }
        } else {
            eventStore.requestAccess(to: .event) { granted, _ in
                DispatchQueue.main.async { completion(granted) }
            }
        }
    }

    // Finds the app's calendar, or creates it.
    // Falls back to the device's default calendar if needed.
    private func studyCalendar() -> EKCalendar? {
        if let id = UserDefaults.standard.string(forKey: calendarIDKey),
           let existing = eventStore.calendar(withIdentifier: id) {
            // Renames the calendar if the app name has changed.
            if existing.title != appName && existing.allowsContentModifications {
                existing.title = appName
                try? eventStore.saveCalendar(existing, commit: true)
            }
            return existing
        }

        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = appName
        calendar.cgColor = UIColor.systemIndigo.cgColor
        calendar.source = eventStore.defaultCalendarForNewEvents?.source
            ?? eventStore.sources.first { $0.sourceType == .local }

        if calendar.source != nil {
            do {
                try eventStore.saveCalendar(calendar, commit: true)
                UserDefaults.standard.set(calendar.calendarIdentifier, forKey: calendarIDKey)
                return calendar
            } catch {
                // Some accounts don't allow new calendars.
            }
        }
        return eventStore.defaultCalendarForNewEvents
    }

    // Creates or updates the event. Returns its ID.
    func save(_ item: Assessment, subject: Subject) -> String? {
        guard isEnabled, let calendar = studyCalendar() else { return item.calendarEventID }

        let event: EKEvent
        if let id = item.calendarEventID, let existing = eventStore.event(withIdentifier: id) {
            event = existing
        } else {
            event = EKEvent(eventStore: eventStore)
            event.calendar = calendar
        }

        let tick = item.isCompleted ? "✓ " : ""
        event.title = "\(tick)\(subject.name) \(item.type.rawValue): \(item.title)"
        let day = Calendar.current.startOfDay(for: item.dueDate)
        event.startDate = day
        event.endDate = day
        event.isAllDay = true
        event.notes = eventNotes(for: item)

        do {
            try eventStore.save(event, span: .thisEvent, commit: true)
            return event.eventIdentifier
        } catch {
            return item.calendarEventID
        }
    }

    func remove(_ item: Assessment) {
        guard hasAccess,
              let id = item.calendarEventID,
              let event = eventStore.event(withIdentifier: id) else { return }
        try? eventStore.remove(event, span: .thisEvent, commit: true)
    }

    private func eventNotes(for item: Assessment) -> String {
        var lines: [String] = []
        if !item.notes.isEmpty { lines.append(item.notes) }
        if !item.steps.isEmpty {
            lines.append("")
            lines.append("Steps:")
            for step in item.steps {
                lines.append((step.isDone ? "☑︎ " : "☐ ") + step.text)
            }
        }
        lines.append("")
        lines.append("Added by \(appName)")
        return lines.joined(separator: "\n")
    }
}
