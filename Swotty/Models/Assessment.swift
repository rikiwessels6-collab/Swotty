import SwiftUI

// MARK: - Small option lists
enum AssessmentType: String, CaseIterable, Identifiable, Codable {
    case exam = "Exam"
    case assignment = "Assignment"
    case quiz = "Quiz"

    var id: String { rawValue }
}

enum Grade: String, CaseIterable, Identifiable, Codable {
    case a = "A", b = "B", c = "C", d = "D", e = "E"

    var id: String { rawValue }
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - The data model
struct ChecklistStep: Identifiable, Codable, Equatable {
    var id = UUID()
    var text: String
    var isDone = false
}

struct Assessment: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var type: AssessmentType
    var subjectID: String
    var dueDate: Date
    var notes = ""
    var reminderDaysBefore: Int? = nil   // nil means no reminder
    var isCompleted = false
    var steps: [ChecklistStep] = []
    var score: Double? = nil             // e.g. 17
    var outOf: Double? = nil             // e.g. 20
    var grade: Grade? = nil
    var studyMinutes = 0                 // added by the Focus timer
    var calendarEventID: String? = nil   // link to the Calendar app event
    var isDemo = false                   // added by "Start with demo data"
    var weight = 1.0                     // how much it counts towards the subject average

    init(title: String, type: AssessmentType, subjectID: String, dueDate: Date) {
        self.title = title
        self.type = type
        self.subjectID = subjectID
        self.dueDate = dueDate
    }

    // Whole days until the due date. Negative means overdue.
    var daysRemaining: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let due = calendar.startOfDay(for: dueDate)
        return calendar.dateComponents([.day], from: today, to: due).day ?? 0
    }

    var percentage: Double? {
        guard let score, let outOf, outOf > 0 else { return nil }
        return score / outOf * 100
    }

    var hasResult: Bool { percentage != nil || grade != nil }

    var stepsDone: Int { steps.filter { $0.isDone }.count }

    // ---- Saving and loading ----
    // "subjectID" is saved under the old name "subject" so
    // tasks saved by the previous version still load.
    enum CodingKeys: String, CodingKey {
        case id, title, type, dueDate, notes, reminderDaysBefore, isCompleted
        case steps, score, outOf, grade, studyMinutes, calendarEventID, isDemo, weight
        case subjectID = "subject"
    }

    // Any missing value gets a sensible default, so older
    // saved data never fails to load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? "Untitled"
        type = (try? c.decode(AssessmentType.self, forKey: .type)) ?? .assignment
        subjectID = (try? c.decode(String.self, forKey: .subjectID)) ?? Subject.otherID
        dueDate = try c.decodeIfPresent(Date.self, forKey: .dueDate) ?? Date()
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        reminderDaysBefore = try c.decodeIfPresent(Int.self, forKey: .reminderDaysBefore)
        isCompleted = try c.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        steps = (try? c.decodeIfPresent([ChecklistStep].self, forKey: .steps)) ?? []
        score = try c.decodeIfPresent(Double.self, forKey: .score)
        outOf = try c.decodeIfPresent(Double.self, forKey: .outOf)
        grade = (try? c.decodeIfPresent(Grade.self, forKey: .grade)) ?? nil
        studyMinutes = try c.decodeIfPresent(Int.self, forKey: .studyMinutes) ?? 0
        calendarEventID = try c.decodeIfPresent(String.self, forKey: .calendarEventID)
        isDemo = try c.decodeIfPresent(Bool.self, forKey: .isDemo) ?? false
        let savedWeight = try c.decodeIfPresent(Double.self, forKey: .weight) ?? 1.0
        weight = savedWeight > 0 ? savedWeight : 1.0
    }
}

extension Array where Element == Assessment {
    // Average of all marked results, where a result with weight 2
    // counts twice as much as one with weight 1. Nil if nothing is marked.
    var weightedAveragePercentage: Double? {
        let marked = compactMap { item -> (pct: Double, weight: Double)? in
            guard let pct = item.percentage else { return nil }
            return (pct, item.weight)
        }
        let totalWeight = marked.reduce(0) { $0 + $1.weight }
        guard totalWeight > 0 else { return nil }
        return marked.reduce(0) { $0 + $1.pct * $1.weight } / totalWeight
    }
}

extension Assessment {
    // One sentence for VoiceOver instead of reading every badge separately.
    func accessibilitySummary(subjectName: String) -> String {
        var parts = ["\(subjectName) \(type.rawValue.lowercased()): \(title)"]
        if isCompleted {
            parts.append("completed")
        } else {
            let days = daysRemaining
            if days < 0 {
                parts.append(days == -1 ? "overdue by 1 day" : "overdue by \(-days) days")
            } else if days == 0 {
                parts.append("due today")
            } else if days == 1 {
                parts.append("due tomorrow")
            } else {
                parts.append("due in \(days) days")
            }
        }
        if !steps.isEmpty { parts.append("\(stepsDone) of \(steps.count) steps done") }
        if let percentage { parts.append("scored \(Int(percentage.rounded())) percent") }
        return parts.joined(separator: ", ")
    }
}

extension Assessment {
    // A fresh, unfinished copy (for repeating a similar task).
    func duplicated() -> Assessment {
        var copy = self
        copy.id = UUID()
        copy.title = title + " (copy)"
        copy.isCompleted = false
        copy.score = nil
        copy.outOf = nil
        copy.grade = nil
        copy.studyMinutes = 0
        copy.calendarEventID = nil
        copy.isDemo = false
        copy.steps = steps.map { step in
            var fresh = step
            fresh.id = UUID()
            fresh.isDone = false
            return fresh
        }
        return copy
    }

    // True if the text appears in the title, notes or subject name.
    func matches(search text: String, subjectName: String) -> Bool {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty { return true }
        return title.localizedCaseInsensitiveContains(query)
            || notes.localizedCaseInsensitiveContains(query)
            || subjectName.localizedCaseInsensitiveContains(query)
    }
}

// MARK: - Grade targets
enum GradeTarget {
    // The percentage the next result (with the given weight) must reach
    // for the weighted average to hit the target.
    static func scoreNeeded(items: [Assessment], target: Double, nextWeight: Double = 1) -> Double {
        var totalWeight = 0.0
        var weightedSum = 0.0
        for item in items {
            if let pct = item.percentage {
                totalWeight += item.weight
                weightedSum += pct * item.weight
            }
        }
        let weight = nextWeight > 0 ? nextWeight : 1
        return (target * (totalWeight + weight) - weightedSum) / weight
    }

    static func advice(items: [Assessment], target: Double) -> String {
        let goal = Int(target.rounded())
        let needed = scoreNeeded(items: items, target: target)
        if needed > 100 {
            return "\(goal)% target: out of reach with one more result"
        }
        let aim = max(0, Int(needed.rounded(.up)))
        if let average = items.weightedAveragePercentage, average >= target {
            return "On track for \(goal)%. Keep scoring \(aim)% or more"
        }
        return "Aim for \(aim)% next to reach \(goal)%"
    }
}
