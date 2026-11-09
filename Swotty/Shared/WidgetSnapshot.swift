import Foundation

// MARK: - What the app shares with the widget
// The app writes this file into the shared App Group container whenever the
// timetable or assessments change. The widget reads it, so it shows the app's
// own timetable (no Calendar needed). This file is compiled into both the app
// and the widget, so it must only use Foundation.

struct SnapshotLesson: Codable, Hashable {
    var id: String
    var subjectName: String
    var colorHex: UInt32
    var weekday: Int          // 1 = Sunday … 7 = Saturday
    var startMinutes: Int
    var endMinutes: Int
    var room: String
    var teacher: String
    var week: Int             // 0 = every week, 1 = Week A, 2 = Week B
    var period: Int           // 0 = none
}

struct SnapshotTask: Codable, Hashable {
    var id: String
    var title: String
    var subjectName: String
    var colorHex: UInt32
    var typeName: String      // Exam / Assignment / Quiz
    var dueDate: Date
}

struct WidgetSnapshot: Codable {
    var generatedAt: Date
    var lessons: [SnapshotLesson]
    var tasks: [SnapshotTask]          // unfinished assessments
    var twoWeek: Bool
    var weekAAnchor: Double
    var weekStart: Int
    var showWeekend: Bool

    static let appGroupID = "group.com.boundaryline.swotty"
    private static let fileName = "widget-snapshot.json"

    // nil when the App Group isn't available (the widget then falls back to Calendar).
    static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(fileName)
    }

    @discardableResult
    func write() -> Bool {
        guard let url = Self.fileURL else { return false }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(self) else { return false }
        do {
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    static func read() -> WidgetSnapshot? {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }

    // The week type (1 = A, 2 = B) for a date, or nil if the timetable is the same every week.
    func weekType(for date: Date, calendar: Calendar = .current) -> Int? {
        twoWeek
            ? ScheduleSettings.weekType(for: date, anchor: weekAAnchor, weekStart: weekStart, calendar: calendar)
            : nil
    }

    // The classes on a date, earliest first, following Week A / Week B.
    func lessons(on date: Date, calendar: Calendar = .current) -> [SnapshotLesson] {
        let weekday = calendar.component(.weekday, from: date)
        let week = weekType(for: date, calendar: calendar)
        return lessons
            .filter { lesson in
                lesson.weekday == weekday
                    && (week == nil || lesson.week == 0 || lesson.week == week)
            }
            .sorted { $0.startMinutes < $1.startMinutes }
    }
}
