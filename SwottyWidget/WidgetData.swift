import Foundation
import EventKit

// MARK: - What the widgets display
struct DayClass: Identifiable, Hashable {
    let id: String
    let title: String
    let colorHex: UInt32
    let start: Date
    let end: Date
    let room: String
    let teacher: String
    let period: Int

    var startText: String { start.formatted(date: .omitted, time: .shortened) }
    var timeRange: String {
        "\(start.formatted(date: .omitted, time: .shortened)) – \(end.formatted(date: .omitted, time: .shortened))"
    }
}

struct TaskItem: Identifiable, Hashable {
    let id: String
    let title: String
    let subjectName: String
    let colorHex: UInt32
    let typeName: String
    let due: Date
}

// MARK: - Where the data comes from
// 1. The app's own timetable, shared through the App Group (preferred).
// 2. If that isn't available, the Swotty calendars in the Calendar app.
struct WidgetContent {
    var snapshot: WidgetSnapshot?
    var calendarClasses: [DayClass] = []
    var calendarTasks: [TaskItem] = []
    var ready: Bool

    func classes(on date: Date) -> [DayClass] {
        let calendar = Calendar.current
        if let snapshot {
            return snapshot.lessons(on: date).compactMap { lesson in
                guard let start = calendar.date(bySettingHour: lesson.startMinutes / 60,
                                                minute: lesson.startMinutes % 60, second: 0, of: date),
                      let end = calendar.date(bySettingHour: lesson.endMinutes / 60,
                                              minute: lesson.endMinutes % 60, second: 0, of: date)
                else { return nil }
                return DayClass(id: "\(lesson.id)-\(Int(start.timeIntervalSince1970))",
                                title: lesson.subjectName, colorHex: lesson.colorHex,
                                start: start, end: end, room: lesson.room,
                                teacher: lesson.teacher, period: lesson.period)
            }
        }
        return calendarClasses.filter { calendar.isDate($0.start, inSameDayAs: date) }
    }

    func weekType(for date: Date) -> Int? {
        snapshot?.weekType(for: date)
    }

    var tasks: [TaskItem] {
        if let snapshot {
            return snapshot.tasks.map {
                TaskItem(id: $0.id, title: $0.title, subjectName: $0.subjectName,
                         colorHex: $0.colorHex, typeName: $0.typeName, due: $0.dueDate)
            }
        }
        return calendarTasks
    }
}

enum WidgetLoader {
    static func load(now: Date) -> WidgetContent {
        if let snapshot = WidgetSnapshot.read() {
            return WidgetContent(snapshot: snapshot, ready: true)
        }
        return CalendarFallback.load(now: now)
    }
}

// MARK: - Calendar fallback
enum CalendarFallback {
    // These must match the names the app uses.
    static let timetableCalendarTitle = "Swotty Timetable"
    static let dueCalendarTitle = "Swotty"
    private static let defaultColor: UInt32 = 0xE3B25A

    private static var isAuthorized: Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(iOS 17.0, *) {
            return status == .fullAccess
        } else {
            return status == .authorized
        }
    }

    static func load(now: Date) -> WidgetContent {
        guard isAuthorized else { return WidgetContent(ready: false) }

        let store = EKEventStore()
        let calendars = store.calendars(for: .event)
        guard let timetable = calendars.first(where: { $0.title == timetableCalendarTitle }) else {
            return WidgetContent(ready: false)
        }

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        let weekOn = calendar.date(byAdding: .day, value: 8, to: startOfToday) ?? now.addingTimeInterval(691_200)

        let classes = store.events(matching: store.predicateForEvents(withStart: startOfToday, end: weekOn,
                                                                      calendars: [timetable]))
            .filter { !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }
            .map { event in
                DayClass(id: "\(event.eventIdentifier ?? UUID().uuidString)-\(Int(event.startDate.timeIntervalSince1970))",
                         title: event.title ?? "Class", colorHex: defaultColor,
                         start: event.startDate, end: event.endDate,
                         room: event.location ?? "", teacher: event.notes ?? "", period: 0)
            }

        var tasks: [TaskItem] = []
        if let dueCalendar = calendars.first(where: { $0.title == dueCalendarTitle }) {
            tasks = store.events(matching: store.predicateForEvents(withStart: startOfToday, end: weekOn,
                                                                    calendars: [dueCalendar]))
                .filter { $0.isAllDay && !($0.title ?? "").hasPrefix("✓") }
                .sorted { $0.startDate < $1.startDate }
                .map { TaskItem(id: $0.eventIdentifier ?? UUID().uuidString, title: $0.title ?? "Due",
                                subjectName: "", colorHex: defaultColor, typeName: "", due: $0.startDate) }
        }
        return WidgetContent(calendarClasses: classes, calendarTasks: tasks, ready: true)
    }
}
