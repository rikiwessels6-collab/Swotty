import Foundation

// Settings that shape the Schedule: which days show, which day the week
// starts on, and whether class times snap to 5 minutes.
// The views read these through @AppStorage using the keys below.
enum ScheduleSettings {
    static let showWeekendKey = "showWeekend"
    static let weekStartKey = "weekStart"
    static let roundedTimesKey = "roundedTimes"
    static let subjectFilterKey = "scheduleSubjectFilter"
    static let weeksKey = "timetableWeeks"          // 1 = same every week, 2 = Week A / Week B
    static let weekAAnchorKey = "weekAAnchor"       // seconds since 1970 of a day in a Week A

    // Weekdays in display order, using Calendar numbering
    // (1 = Sunday, 2 = Monday … 7 = Saturday).
    static func orderedDays(weekStart: Int, showWeekend: Bool) -> [Int] {
        let start = (1...7).contains(weekStart) ? weekStart : 2
        return (0..<7)
            .map { (start - 1 + $0) % 7 + 1 }
            .filter { showWeekend || (2...6).contains($0) }
    }

    // Snaps minutes-after-midnight to the nearest 5 (or another step),
    // keeping the result inside the same day.
    static func rounded(_ minutes: Int, step: Int = 5) -> Int {
        let snapped = Int((Double(minutes) / Double(step)).rounded()) * step
        return min(max(snapped, 0), 24 * 60 - step)
    }

    // ---- Week A / Week B ----

    static func weekLabel(_ type: Int) -> String {
        type == 2 ? "Week B" : "Week A"
    }

    private static func weekCalendar(weekStart: Int, base: Calendar) -> Calendar {
        var calendar = base
        calendar.firstWeekday = (1...7).contains(weekStart) ? weekStart : 2
        return calendar
    }

    // Which week a date falls in: 1 = Week A, 2 = Week B. The weeks simply
    // alternate from a known Week A (the "anchor"). With no anchor, it is Week A.
    static func weekType(for date: Date, anchor: TimeInterval, weekStart: Int,
                         calendar base: Calendar = .current) -> Int {
        guard anchor > 0 else { return 1 }
        let calendar = weekCalendar(weekStart: weekStart, base: base)
        let anchorDate = Date(timeIntervalSince1970: anchor)
        let anchorWeek = calendar.dateInterval(of: .weekOfYear, for: anchorDate)?.start ?? anchorDate
        let dateWeek = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        let days = calendar.dateComponents([.day], from: anchorWeek, to: dateWeek).day ?? 0
        let weeks = Int((Double(days) / 7).rounded())
        return ((weeks % 2) + 2) % 2 == 0 ? 1 : 2
    }

    // The anchor that makes the week containing `date` the given type.
    static func anchor(settingWeekOf date: Date, to type: Int, weekStart: Int,
                       calendar base: Calendar = .current) -> TimeInterval {
        let calendar = weekCalendar(weekStart: weekStart, base: base)
        let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        let anchorWeek = type == 2 ? (calendar.date(byAdding: .day, value: -7, to: start) ?? start) : start
        return anchorWeek.timeIntervalSince1970
    }

    // The week type for a date using the saved settings, or nil when the
    // timetable is the same every week.
    static func weekType(on date: Date, defaults: UserDefaults = .standard,
                         calendar: Calendar = .current) -> Int? {
        guard defaults.integer(forKey: weeksKey) == 2 else { return nil }
        let start = (defaults.object(forKey: weekStartKey) as? Int) ?? 2
        return weekType(for: date, anchor: defaults.double(forKey: weekAAnchorKey),
                        weekStart: start, calendar: calendar)
    }

    static func setTimetableWeeks(_ count: Int, defaults: UserDefaults = .standard) {
        defaults.set(count, forKey: weeksKey)
        // Turning A/B on: call the current week "Week A" until told otherwise.
        if count == 2, defaults.double(forKey: weekAAnchorKey) == 0 {
            setCurrentWeekType(1, defaults: defaults)
        }
    }

    // "This week is Week A / Week B."
    static func setCurrentWeekType(_ type: Int, defaults: UserDefaults = .standard) {
        let start = (defaults.object(forKey: weekStartKey) as? Int) ?? 2
        defaults.set(anchor(settingWeekOf: Date(), to: type, weekStart: start), forKey: weekAAnchorKey)
    }

    // Changing the first day of the week must not flip which week is A.
    static func setWeekStart(_ newStart: Int, defaults: UserDefaults = .standard) {
        let current = weekType(on: Date(), defaults: defaults)
        defaults.set(newStart, forKey: weekStartKey)
        if let current {
            defaults.set(anchor(settingWeekOf: Date(), to: current, weekStart: newStart),
                         forKey: weekAAnchorKey)
        }
    }

    // "Monday", "Sunday" … for the week-start picker.
    static let weekStartChoices: [(day: Int, name: String)] = [
        (2, "Monday"), (1, "Sunday"), (7, "Saturday")
    ]
}
