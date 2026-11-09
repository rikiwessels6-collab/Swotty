import Foundation
import UserNotifications

// MARK: - Class and review reminders
// 1. A weekly repeating reminder a few minutes before each class.
// 2. A one-off reminder at the user's reminder time when notes are
//    waiting to be reviewed (re-planned every time the notes change).
// Both are off until switched on in Settings.
enum ClassReminders {
    static let classEnabledKey = "classRemindersEnabled"
    static let classMinutesKey = "classReminderMinutes"
    static let reviewEnabledKey = "reviewRemindersEnabled"

    private static let lessonPrefix = "lesson-"
    private static let reviewID = "reviewNotes"

    static var classRemindersOn: Bool {
        UserDefaults.standard.bool(forKey: classEnabledKey)
    }

    // 10 minutes unless changed in Settings.
    static var minutesBefore: Int {
        guard UserDefaults.standard.object(forKey: classMinutesKey) != nil else { return 10 }
        let saved = UserDefaults.standard.integer(forKey: classMinutesKey)
        return saved > 0 ? saved : 10
    }

    static var reviewRemindersOn: Bool {
        UserDefaults.standard.bool(forKey: reviewEnabledKey)
    }

    // ---- Pure helpers (unit tested) ----

    // When a weekly reminder should fire, or nil if it would fall before midnight.
    static func triggerComponents(for lesson: Lesson, minutesBefore: Int) -> DateComponents? {
        let fireMinutes = lesson.startMinutes - minutesBefore
        guard fireMinutes >= 0 else { return nil }
        var parts = DateComponents()
        parts.weekday = lesson.weekday
        parts.hour = fireMinutes / 60
        parts.minute = fireMinutes % 60
        return parts
    }

    // The next time the review reminder time (e.g. 4pm) comes round.
    static func nextReviewFireDate(after now: Date, hour: Int,
                                   calendar: Calendar = .current) -> Date {
        let today = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: now) ?? now
        if today > now { return today }
        return calendar.date(byAdding: .day, value: 1, to: today) ?? today
    }

    // ---- Scheduling ----

    // One reminder due at a specific moment.
    struct UpcomingReminder: Equatable {
        let lesson: Lesson
        let fireDate: Date
    }

    // Reminders for classes in the next `days` days, following Week A / Week B.
    // Used when the timetable alternates, because a weekly repeating
    // notification can't skip every other week. (Unit tested.)
    static func upcomingReminders(lessons: [Lesson], minutesBefore: Int, twoWeek: Bool,
                                  anchor: TimeInterval, weekStart: Int, from now: Date,
                                  days: Int = 14, limit: Int = 50,
                                  calendar: Calendar = .current) -> [UpcomingReminder] {
        var result: [UpcomingReminder] = []
        let startOfToday = calendar.startOfDay(for: now)

        for offset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startOfToday) else { continue }
            let weekday = calendar.component(.weekday, from: day)
            let weekType: Int? = twoWeek
                ? ScheduleSettings.weekType(for: day, anchor: anchor, weekStart: weekStart, calendar: calendar)
                : nil

            for lesson in lessons where lesson.weekday == weekday && lesson.runs(inWeek: weekType) {
                let fireMinutes = lesson.startMinutes - minutesBefore
                guard fireMinutes >= 0,
                      let fire = calendar.date(bySettingHour: fireMinutes / 60, minute: fireMinutes % 60,
                                               second: 0, of: day),
                      fire > now else { continue }
                result.append(UpcomingReminder(lesson: lesson, fireDate: fire))
            }
        }
        return Array(result.sorted { $0.fireDate < $1.fireDate }.prefix(limit))
    }

    private static func content(for lesson: Lesson, subjects: [Subject], minutes: Int) -> UNMutableNotificationContent {
        let name = subjects.first { $0.id == lesson.subjectID }?.name ?? "Class"
        let content = UNMutableNotificationContent()
        content.title = "\(name) in \(minutes) minutes"
        content.body = lesson.details.isEmpty
            ? "Starts at \(Lesson.label(forMinutes: lesson.startMinutes))."
            : "\(Lesson.label(forMinutes: lesson.startMinutes)) · \(lesson.details)"
        content.sound = .default
        return content
    }

    // Replaces all class reminders with ones matching the timetable.
    static func rescheduleLessons(_ lessons: [Lesson], subjects: [Subject]) {
        let center = UNUserNotificationCenter.current()
        let enabled = classRemindersOn
        let minutes = minutesBefore

        let defaults = UserDefaults.standard
        let twoWeek = defaults.integer(forKey: ScheduleSettings.weeksKey) == 2
        let anchor = defaults.double(forKey: ScheduleSettings.weekAAnchorKey)
        let weekStart = (defaults.object(forKey: ScheduleSettings.weekStartKey) as? Int) ?? 2

        center.getPendingNotificationRequests { requests in
            let old = requests.map { $0.identifier }.filter { $0.hasPrefix(lessonPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: old)
            guard enabled else { return }

            center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                guard granted else { return }

                if twoWeek {
                    // Dated reminders for the next two weeks, refreshed whenever the app opens.
                    let upcoming = upcomingReminders(lessons: lessons, minutesBefore: minutes, twoWeek: true,
                                                     anchor: anchor, weekStart: weekStart, from: Date())
                    for item in upcoming {
                        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute],
                                                                    from: item.fireDate)
                        let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
                        let id = "\(lessonPrefix)\(item.lesson.id.uuidString)-\(Int(item.fireDate.timeIntervalSince1970))"
                        center.add(UNNotificationRequest(identifier: id,
                                                         content: content(for: item.lesson, subjects: subjects, minutes: minutes),
                                                         trigger: trigger))
                    }
                } else {
                    // Same every week: one repeating weekly reminder per lesson.
                    for lesson in lessons {
                        guard let parts = triggerComponents(for: lesson, minutesBefore: minutes) else { continue }
                        let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: true)
                        center.add(UNNotificationRequest(identifier: lessonPrefix + lesson.id.uuidString,
                                                         content: content(for: lesson, subjects: subjects, minutes: minutes),
                                                         trigger: trigger))
                    }
                }
            }
        }
    }

    // Plans (or cancels) the "notes to review" reminder.
    static func rescheduleReview(pendingCount: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [reviewID])
        guard reviewRemindersOn, pendingCount > 0 else { return }

        let fireDate = nextReviewFireDate(after: Date(), hour: ReminderScheduler.reminderHour)
        let content = UNMutableNotificationContent()
        content.title = "Notes to review"
        content.body = pendingCount == 1
            ? "You have 1 note to review."
            : "You have \(pendingCount) notes to review."
        content.sound = .default

        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)

        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            center.add(UNNotificationRequest(identifier: reviewID, content: content, trigger: trigger))
        }
    }
}
