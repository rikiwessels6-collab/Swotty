import Foundation
import UserNotifications

// MARK: - Notifications (reminders and the Focus timer)
enum ReminderScheduler {
    // The hour chosen in Settings (4pm unless changed).
    static var reminderHour: Int {
        guard UserDefaults.standard.object(forKey: "reminderHour") != nil else { return 16 }
        return UserDefaults.standard.integer(forKey: "reminderHour")
    }

    // Turns 16 into "4:00 pm" in the device's own format.
    static func label(forHour hour: Int) -> String {
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }

    static func schedule(_ item: Assessment, subject: Subject) {
        cancel(item)
        guard let daysBefore = item.reminderDaysBefore, !item.isCompleted else { return }

        let calendar = Calendar.current
        guard let day = calendar.date(byAdding: .day, value: -daysBefore,
                                      to: calendar.startOfDay(for: item.dueDate)),
              let fireDate = calendar.date(bySettingHour: reminderHour, minute: 0, second: 0, of: day),
              fireDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(subject.name) \(item.type.rawValue.lowercased())"
        content.body = daysBefore == 1
            ? "\(item.title) is due tomorrow."
            : "\(item.title) is due in \(daysBefore) days."
        content.sound = .default

        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        add(UNNotificationRequest(identifier: item.id.uuidString, content: content, trigger: trigger))
    }

    static func cancel(_ item: Assessment) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [item.id.uuidString])
    }

    // ---- Focus timer ----
    static let timerID = "focusTimer"

    static func scheduleTimerEnd(after seconds: TimeInterval, isFocus: Bool) {
        cancelTimer()
        guard seconds > 1 else { return }
        let content = UNMutableNotificationContent()
        content.title = isFocus ? "Focus session done!" : "Break's over"
        content.body = isFocus ? "Nice work. Time for a short break." : "Ready for another focus session?"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        add(UNNotificationRequest(identifier: timerID, content: content, trigger: trigger))
    }

    static func cancelTimer() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [timerID])
    }

    // Asks permission the first time, then adds the notification.
    private static func add(_ request: UNNotificationRequest) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted { center.add(request) }
        }
    }
}
