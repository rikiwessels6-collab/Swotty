import Foundation

// MARK: - Workload and revision insights (pure logic, easy to test)
struct BusyWeek: Equatable {
    let start: Date
    let count: Int
    let titles: [String]
}

enum Insights {
    // Weeks in the next few weeks with several things due at once.
    static func busyWeeks(_ items: [Assessment],
                          now: Date = Date(),
                          calendar: Calendar = .current,
                          threshold: Int = 3,
                          lookAheadWeeks: Int = 4) -> [BusyWeek] {
        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now) else { return [] }
        let today = calendar.startOfDay(for: now)
        var result: [BusyWeek] = []
        for offset in 0..<lookAheadWeeks {
            guard let start = calendar.date(byAdding: .weekOfYear, value: offset, to: thisWeek.start),
                  let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) else { continue }
            let due = items
                .filter { !$0.isCompleted && $0.dueDate >= start && $0.dueDate < end && $0.dueDate >= today }
                .sorted { $0.dueDate < $1.dueDate }
            if due.count >= threshold {
                result.append(BusyWeek(start: start, count: due.count, titles: due.map { $0.title }))
            }
        }
        return result
    }

    // The nearest exam that hasn't happened yet.
    static func nextExam(_ items: [Assessment],
                         now: Date = Date(),
                         calendar: Calendar = .current) -> Assessment? {
        let today = calendar.startOfDay(for: now)
        return items
            .filter { !$0.isCompleted && $0.type == .exam && calendar.startOfDay(for: $0.dueDate) >= today }
            .min { $0.dueDate < $1.dueDate }
    }

    // Suggested revision days: a week, three days and one day before.
    static func revisionDays(for exam: Assessment,
                             now: Date = Date(),
                             calendar: Calendar = .current) -> [Date] {
        let today = calendar.startOfDay(for: now)
        let due = calendar.startOfDay(for: exam.dueDate)
        return [7, 3, 1]
            .compactMap { calendar.date(byAdding: .day, value: -$0, to: due) }
            .filter { $0 >= today }
            .sorted()
    }

    static func countdownText(days: Int) -> String {
        switch days {
        case ..<0: return "overdue"
        case 0: return "today"
        case 1: return "tomorrow"
        default: return "in \(days) days"
        }
    }
}

// MARK: - Quick add: "Maths exam Friday" becomes a task
struct QuickAddResult: Equatable {
    var title: String
    var date: Date?
    var type: AssessmentType
}

enum QuickAdd {
    private static let weekdays: [String: Int] = [
        "sun": 1, "sunday": 1, "mon": 2, "monday": 2, "tue": 3, "tues": 3, "tuesday": 3,
        "wed": 4, "weds": 4, "wednesday": 4, "thu": 5, "thur": 5, "thurs": 5, "thursday": 5,
        "fri": 6, "friday": 6, "sat": 7, "saturday": 7
    ]

    static func parse(_ text: String, now: Date = Date(), calendar: Calendar = .current) -> QuickAddResult {
        let original = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = original.split(separator: " ").map(String.init)
        let today = calendar.startOfDay(for: now)
        var kept: [String] = []
        var date: Date? = nil
        var i = 0
        while i < words.count {
            let word = words[i]
            let lower = word.lowercased().trimmingCharacters(in: .punctuationCharacters)
            if date == nil {
                if lower == "today" {
                    date = today; i += 1; continue
                }
                if lower == "tomorrow" || lower == "tmrw" {
                    date = calendar.date(byAdding: .day, value: 1, to: today); i += 1; continue
                }
                if lower == "next", i + 1 < words.count,
                   words[i + 1].lowercased().trimmingCharacters(in: .punctuationCharacters) == "week" {
                    date = calendar.date(byAdding: .day, value: 7, to: today); i += 2; continue
                }
                if let target = weekdays[lower] {
                    let current = calendar.component(.weekday, from: today)
                    var delta = (target - current + 7) % 7
                    if delta == 0 { delta = 7 }
                    date = calendar.date(byAdding: .day, value: delta, to: today); i += 1; continue
                }
            }
            kept.append(word)
            i += 1
        }
        if date != nil {
            while let last = kept.last, ["on", "by", "due", "for"].contains(last.lowercased()) {
                kept.removeLast()
            }
        }

        var title = kept.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty { title = original }
        if let first = title.first { title = first.uppercased() + title.dropFirst() }

        let lowered = original.lowercased()
        let type: AssessmentType
        if lowered.contains("exam") {
            type = .exam
        } else if lowered.contains("quiz") || lowered.contains("test") {
            type = .quiz
        } else {
            type = .assignment
        }
        return QuickAddResult(title: title, date: date, type: type)
    }
}
