import UIKit
import EventKit
import WidgetKit

// MARK: - Calendar sync (Apple Calendar app)
// Each assessment becomes an all-day event on its due date,
// in a calendar named after the app. Any calendar account
// on the device (iCloud, Google, Outlook) will sync it onwards.
final class CalendarSync {
    static let shared = CalendarSync()

    let eventStore = EKEventStore()
    private let enabledKey = "calendarSyncEnabled"
    private let calendarIDKey = "calendarSyncCalendarID"

    // ---- Timetable events (see "Timetable in Calendar" below) ----
    static let timetableCalendarTitle = "\(appName) Timetable"
    private let timetableEnabledKey = "timetableCalendarEnabled"
    private let timetableUntilKey = "timetableCalendarUntil"
    private let timetableCalendarIDKey = "timetableCalendarID"
    private let timetableEventIDsKey = "timetableEventIDs"

    private var cachedLessons: [Lesson] = []
    private var cachedSubjects: [Subject] = []
    private var timetableWorkItem: DispatchWorkItem?

    private init() {
        // Re-plan the timetable events when Week A / B or the week start changes.
        NotificationCenter.default.addObserver(forName: ScheduleSettings.didChangeNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            self?.scheduleTimetableSync()
        }
    }

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

    // MARK: - Timetable in Calendar
    // Every lesson becomes a repeating event in its own calendar. Lessons that
    // run in Week A or Week B repeat every second week, starting in the right week.
    // The widget reads these events too.

    // Where and how often a lesson's first event happens.
    struct TimetableOccurrence: Equatable {
        let firstDate: Date      // the first day the lesson falls on, from today
        let intervalWeeks: Int   // 1 = every week, 2 = every second week (Week A or B only)
    }

    static func firstOccurrence(of lesson: Lesson, twoWeek: Bool, anchor: TimeInterval,
                                weekStart: Int, from now: Date,
                                calendar: Calendar = .current) -> TimetableOccurrence? {
        let alternates = twoWeek && lesson.week != 0
        let start = calendar.startOfDay(for: now)
        for offset in 0..<14 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start),
                  calendar.component(.weekday, from: day) == lesson.weekday else { continue }
            if alternates {
                let type = ScheduleSettings.weekType(for: day, anchor: anchor,
                                                     weekStart: weekStart, calendar: calendar)
                guard type == lesson.week else { continue }
            }
            return TimetableOccurrence(firstDate: day, intervalWeeks: alternates ? 2 : 1)
        }
        return nil
    }

    var timetableEnabled: Bool {
        UserDefaults.standard.bool(forKey: timetableEnabledKey) && hasAccess
    }

    func setTimetableEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: timetableEnabledKey)
    }

    // The last day the repeating events run (about ten weeks unless changed).
    var timetableUntil: Date {
        let stored = UserDefaults.standard.double(forKey: timetableUntilKey)
        if stored > 0 { return Date(timeIntervalSince1970: stored) }
        return Calendar.current.date(byAdding: .weekOfYear, value: 10, to: Date()) ?? Date()
    }

    func setTimetableUntil(_ date: Date) {
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: timetableUntilKey)
    }

    // Remembers the latest lessons and subjects without syncing.
    func updateTimetableSource(lessons: [Lesson], subjects: [Subject]) {
        cachedLessons = lessons
        cachedSubjects = subjects
    }

    // Syncs a moment from now, so a burst of edits becomes a single update.
    func scheduleTimetableSync(lessons: [Lesson]? = nil, subjects: [Subject]? = nil) {
        if let lessons { cachedLessons = lessons }
        if let subjects { cachedSubjects = subjects }
        timetableWorkItem?.cancel()
        guard timetableEnabled else { return }
        let item = DispatchWorkItem { [weak self] in self?.syncTimetableNow() }
        timetableWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: item)
    }

    // Removes the old events and creates one repeating event per lesson.
    func syncTimetableNow() {
        timetableWorkItem?.cancel()
        guard timetableEnabled, let calendar = timetableCalendar() else { return }

        removeTimetableEvents()

        let defaults = UserDefaults.standard
        let twoWeek = defaults.integer(forKey: ScheduleSettings.weeksKey) == 2
        let anchor = defaults.double(forKey: ScheduleSettings.weekAAnchorKey)
        let weekStart = (defaults.object(forKey: ScheduleSettings.weekStartKey) as? Int) ?? 2
        let until = Calendar.current.date(bySettingHour: 23, minute: 59, second: 0, of: timetableUntil) ?? timetableUntil
        let now = Date()

        var ids: [String: String] = [:]
        for lesson in cachedLessons {
            guard let occurrence = Self.firstOccurrence(of: lesson, twoWeek: twoWeek, anchor: anchor,
                                                        weekStart: weekStart, from: now),
                  occurrence.firstDate <= until,
                  let start = Calendar.current.date(bySettingHour: lesson.startMinutes / 60,
                                                    minute: lesson.startMinutes % 60,
                                                    second: 0, of: occurrence.firstDate),
                  let end = Calendar.current.date(bySettingHour: lesson.endMinutes / 60,
                                                  minute: lesson.endMinutes % 60,
                                                  second: 0, of: occurrence.firstDate)
            else { continue }

            let event = EKEvent(eventStore: eventStore)
            event.calendar = calendar
            event.title = cachedSubjects.first { $0.id == lesson.subjectID }?.name ?? "Class"
            event.location = lesson.room.isEmpty ? nil : lesson.room
            event.notes = lesson.teacher.isEmpty ? nil : lesson.teacher
            event.startDate = start
            event.endDate = end
            event.isAllDay = false
            event.addRecurrenceRule(EKRecurrenceRule(recurrenceWith: .weekly,
                                                     interval: occurrence.intervalWeeks,
                                                     end: EKRecurrenceEnd(end: until)))
            do {
                try eventStore.save(event, span: .futureEvents, commit: true)
                if let id = event.eventIdentifier { ids[lesson.id.uuidString] = id }
            } catch {
                // Skip a lesson that can't be saved; the rest still sync.
            }
        }
        defaults.set(ids, forKey: timetableEventIDsKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // Deletes the repeating events this app created for the timetable.
    func removeTimetableEvents(deleteCalendar: Bool = false) {
        guard hasAccess else { return }
        let defaults = UserDefaults.standard
        let ids = (defaults.dictionary(forKey: timetableEventIDsKey) as? [String: String]) ?? [:]
        for id in ids.values {
            if let event = eventStore.event(withIdentifier: id) {
                try? eventStore.remove(event, span: .futureEvents, commit: false)
            }
        }
        try? eventStore.commit()
        defaults.removeObject(forKey: timetableEventIDsKey)

        if deleteCalendar,
           let id = defaults.string(forKey: timetableCalendarIDKey),
           let calendar = eventStore.calendar(withIdentifier: id) {
            try? eventStore.removeCalendar(calendar, commit: true)
            defaults.removeObject(forKey: timetableCalendarIDKey)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    // Finds the timetable calendar, or creates it.
    private func timetableCalendar() -> EKCalendar? {
        let defaults = UserDefaults.standard
        if let id = defaults.string(forKey: timetableCalendarIDKey),
           let existing = eventStore.calendar(withIdentifier: id) {
            return existing
        }
        if let byName = eventStore.calendars(for: .event)
            .first(where: { $0.title == Self.timetableCalendarTitle && $0.allowsContentModifications }) {
            defaults.set(byName.calendarIdentifier, forKey: timetableCalendarIDKey)
            return byName
        }

        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = Self.timetableCalendarTitle
        calendar.cgColor = UIColor(Theme.gold).cgColor
        calendar.source = eventStore.defaultCalendarForNewEvents?.source
            ?? eventStore.sources.first { $0.sourceType == .local }
        guard calendar.source != nil else { return eventStore.defaultCalendarForNewEvents }
        do {
            try eventStore.saveCalendar(calendar, commit: true)
            defaults.set(calendar.calendarIdentifier, forKey: timetableCalendarIDKey)
            return calendar
        } catch {
            return eventStore.defaultCalendarForNewEvents
        }
    }
}
