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
        case steps, score, outOf, grade, studyMinutes, calendarEventID, isDemo
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
    }
}
