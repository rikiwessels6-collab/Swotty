import WidgetKit
import EventKit

// MARK: - What the widget shows
// The widget reads the timetable straight from the Calendar app: the app adds
// every class to a "Swotty Timetable" calendar (Settings > Calendar Sync), and
// due dates live in the "Swotty" calendar. This way the widget needs no shared
// storage, and Week A / Week B are already worked out by the calendar.

struct WidgetClass: Identifiable, Hashable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let room: String
    let teacher: String

    var timeRange: String {
        "\(start.formatted(date: .omitted, time: .shortened)) – \(end.formatted(date: .omitted, time: .shortened))"
    }
}

struct WidgetDue: Identifiable, Hashable {
    let id: String
    let title: String
    let date: Date
}

enum WidgetState {
    case ready          // classes loaded (there may be none left today)
    case needsAccess    // Calendar permission hasn't been granted in the app
    case notSynced      // the timetable hasn't been added to Calendar yet
}

struct TimetableEntry: TimelineEntry {
    let date: Date
    let state: WidgetState
    let classes: [WidgetClass]   // in progress or still to come at `date`, soonest first
    let due: [WidgetDue]         // due today or in the next few days
}

// MARK: - Reading the Calendar
enum CalendarLoader {
    // These must match the names the app uses.
    static let timetableCalendarTitle = "Swotty Timetable"
    static let dueCalendarTitle = "Swotty"

    private static var isAuthorized: Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(iOS 17.0, *) {
            return status == .fullAccess
        } else {
            return status == .authorized
        }
    }

    static func load(now: Date) -> (state: WidgetState, classes: [WidgetClass], due: [WidgetDue]) {
        guard isAuthorized else { return (.needsAccess, [], []) }

        let store = EKEventStore()
        let calendars = store.calendars(for: .event)
        guard let timetable = calendars.first(where: { $0.title == timetableCalendarTitle }) else {
            return (.notSynced, [], [])
        }

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        let twoDaysOn = calendar.date(byAdding: .day, value: 2, to: startOfToday) ?? now.addingTimeInterval(172_800)

        let classEvents = store.events(matching: store.predicateForEvents(withStart: startOfToday,
                                                                          end: twoDaysOn,
                                                                          calendars: [timetable]))
        let classes = classEvents
            .filter { !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }
            .map { event in
                WidgetClass(id: "\(event.eventIdentifier ?? UUID().uuidString)-\(event.startDate.timeIntervalSince1970)",
                            title: event.title ?? "Class",
                            start: event.startDate,
                            end: event.endDate,
                            room: event.location ?? "",
                            teacher: event.notes ?? "")
            }

        var due: [WidgetDue] = []
        if let dueCalendar = calendars.first(where: { $0.title == dueCalendarTitle }) {
            let threeDaysOn = calendar.date(byAdding: .day, value: 4, to: startOfToday) ?? twoDaysOn
            let dueEvents = store.events(matching: store.predicateForEvents(withStart: startOfToday,
                                                                            end: threeDaysOn,
                                                                            calendars: [dueCalendar]))
            due = dueEvents
                .filter { $0.isAllDay && !($0.title ?? "").hasPrefix("✓") }
                .sorted { $0.startDate < $1.startDate }
                .map { WidgetDue(id: $0.eventIdentifier ?? UUID().uuidString,
                                 title: $0.title ?? "Due",
                                 date: $0.startDate) }
        }
        return (.ready, classes, due)
    }
}

// MARK: - Timeline
struct TimetableProvider: TimelineProvider {
    func placeholder(in context: Context) -> TimetableEntry {
        sampleEntry()
    }

    func getSnapshot(in context: Context, completion: @escaping (TimetableEntry) -> Void) {
        if context.isPreview {
            completion(sampleEntry())
            return
        }
        let loaded = CalendarLoader.load(now: Date())
        completion(TimetableEntry(date: Date(), state: loaded.state,
                                  classes: loaded.classes.filter { $0.end > Date() }, due: loaded.due))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TimetableEntry>) -> Void) {
        let now = Date()
        let loaded = CalendarLoader.load(now: now)

        // A new entry at each class start and end, and at midnight, so the
        // widget moves on by itself without the app running.
        var moments: Set<Date> = [now]
        for item in loaded.classes {
            if item.start > now { moments.insert(item.start) }
            if item.end > now { moments.insert(item.end) }
        }
        if let midnight = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now)) {
            moments.insert(midnight)
        }

        let entries = Array(moments.sorted().prefix(14)).map { moment in
            TimetableEntry(date: moment, state: loaded.state,
                           classes: loaded.classes.filter { $0.end > moment },
                           due: loaded.due)
        }
        let refresh = Calendar.current.date(byAdding: .hour, value: 3, to: now) ?? now.addingTimeInterval(10_800)
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }

    private func sampleEntry() -> TimetableEntry {
        let now = Date()
        let sample = [
            WidgetClass(id: "1", title: "Maths", start: now.addingTimeInterval(-600), end: now.addingTimeInterval(2_400),
                        room: "R1.02", teacher: "Ms Patel"),
            WidgetClass(id: "2", title: "English", start: now.addingTimeInterval(3_000), end: now.addingTimeInterval(5_700),
                        room: "R2.04", teacher: "Mr Clarke"),
            WidgetClass(id: "3", title: "Science", start: now.addingTimeInterval(6_300), end: now.addingTimeInterval(9_000),
                        room: "Lab 3", teacher: "Dr Evans")
        ]
        return TimetableEntry(date: now, state: .ready, classes: sample,
                              due: [WidgetDue(id: "d", title: "Algebra test", date: now)])
    }
}
