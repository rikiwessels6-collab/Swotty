import Foundation
import UserNotifications

// MARK: - Revision reminders and the Sunday "week ahead" summary
struct PlannedNotification: Equatable {
    let id: String
    let fireDate: Date
    let title: String
    let body: String
}

enum StudyReminders {
    static let prefix = "study-"
    static let revisionKey = "revisionRemindersEnabled"
    static let summaryKey = "weeklySummaryEnabled"

    // ---- Planning (pure, so it can be tested) ----

    // Nudges on the suggested revision days for exams in the next two weeks.
    static func revisionPlan(items: [Assessment],
                             subjectName: (String) -> String,
                             hour: Int,
                             now: Date = Date(),
                             calendar: Calendar = .current,
                             withinDays: Int = 14) -> [PlannedNotification] {
        var planned: [PlannedNotification] = []
        let today = calendar.startOfDay(for: now)
        for exam in items where !exam.isCompleted && exam.type == .exam {
            let due = calendar.startOfDay(for: exam.dueDate)
            let away = calendar.dateComponents([.day], from: today, to: due).day ?? 0
            guard away >= 0, away <= withinDays else { continue }
            for day in Insights.revisionDays(for: exam, now: now, calendar: calendar) {
                guard let fire = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day),
                      fire > now else { continue }
                let toGo = calendar.dateComponents([.day], from: day, to: due).day ?? 0
                let when = toGo == 1 ? "tomorrow" : "in \(toGo) days"
                planned.append(PlannedNotification(
                    id: "\(prefix)\(exam.id.uuidString)-\(Int(day.timeIntervalSince1970))",
                    fireDate: fire,
                    title: "Time to revise",
                    body: "\(subjectName(exam.subjectID)) exam \(when). Do a revision session today."))
            }
        }
        return planned
    }

    // Sunday evening: what is due in the coming Monday to Sunday.
    static func weeklySummary(items: [Assessment],
                              now: Date = Date(),
                              calendar: Calendar = .current,
                              hour: Int = 18) -> PlannedNotification? {
        let today = calendar.startOfDay(for: now)
        var sunday: Date? = nil
        for offset in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  calendar.component(.weekday, from: day) == 1,
                  let fire = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day),
                  fire > now else { continue }
            sunday = day
            break
        }
        guard let sunday,
              let fire = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: sunday),
              let monday = calendar.date(byAdding: .day, value: 1, to: sunday),
              let nextMonday = calendar.date(byAdding: .day, value: 8, to: sunday) else { return nil }

        let due = items
            .filter { !$0.isCompleted && $0.dueDate >= monday && $0.dueDate < nextMonday }
            .sorted { $0.dueDate < $1.dueDate }
        guard let first = due.first else { return nil }

        let count = due.count == 1 ? "1 thing" : "\(due.count) things"
        let day = first.dueDate.formatted(.dateTime.weekday(.wide))
        return PlannedNotification(id: prefix + "weekly",
                                   fireDate: fire,
                                   title: "Your week ahead",
                                   body: "\(count) due this week. First up: \(first.title) on \(day).")
    }

    // ---- Scheduling ----
    static func reschedule(items: [Assessment], subjects: [Subject]) {
        let defaults = UserDefaults.standard
        let names: [String: String] = subjects.reduce(into: [:]) { $0[$1.id] = $1.name }
        var planned: [PlannedNotification] = []
        if defaults.bool(forKey: revisionKey) {
            planned += revisionPlan(items: items,
                                    subjectName: { names[$0] ?? "Your" },
                                    hour: ReminderScheduler.reminderHour)
        }
        if defaults.bool(forKey: summaryKey), let summary = weeklySummary(items: items) {
            planned.append(summary)
        }

        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let old = requests.map { $0.identifier }.filter { $0.hasPrefix(prefix) }
            center.removePendingNotificationRequests(withIdentifiers: old)
            guard !planned.isEmpty else { return }
            center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                guard granted else { return }
                for item in planned {
                    let content = UNMutableNotificationContent()
                    content.title = item.title
                    content.body = item.body
                    content.sound = .default
                    let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute],
                                                                from: item.fireDate)
                    let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
                    center.add(UNNotificationRequest(identifier: item.id, content: content, trigger: trigger))
                }
            }
        }
    }
}
