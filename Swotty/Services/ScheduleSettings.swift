import Foundation

// Settings that shape the Schedule: which days show, which day the week
// starts on, and whether class times snap to 5 minutes.
// The views read these through @AppStorage using the keys below.
enum ScheduleSettings {
    static let showWeekendKey = "showWeekend"
    static let weekStartKey = "weekStart"
    static let roundedTimesKey = "roundedTimes"
    static let subjectFilterKey = "scheduleSubjectFilter"

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

    // "Monday", "Sunday" … for the week-start picker.
    static let weekStartChoices: [(day: Int, name: String)] = [
        (2, "Monday"), (1, "Sunday"), (7, "Saturday")
    ]
}
