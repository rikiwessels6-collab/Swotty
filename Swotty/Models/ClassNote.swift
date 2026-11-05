import Foundation

// A note taken for one class on one particular day.
// It can be flagged "needs review" so it shows up in the Review list
// until the student ticks it off.
struct ClassNote: Identifiable, Codable, Equatable {
    var id = UUID()
    var date: Date                // the day of the class (start of that day)
    var subjectID: String
    var lessonID: UUID? = nil     // the timetable lesson it belongs to, if any
    var text: String
    var needsReview = false
    var isReviewed = false
    var isDemo = false            // added by "Start with demo data"

    init(date: Date, subjectID: String, lessonID: UUID? = nil,
         text: String, needsReview: Bool = false) {
        self.date = Calendar.current.startOfDay(for: date)
        self.subjectID = subjectID
        self.lessonID = lessonID
        self.text = text
        self.needsReview = needsReview
    }

    enum CodingKeys: String, CodingKey {
        case id, date, subjectID, lessonID, text, needsReview, isReviewed, isDemo
    }

    // Missing values get sensible defaults so saved data always loads.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        date = Calendar.current.startOfDay(
            for: try c.decodeIfPresent(Date.self, forKey: .date) ?? Date())
        subjectID = try c.decodeIfPresent(String.self, forKey: .subjectID) ?? Subject.otherID
        lessonID = try c.decodeIfPresent(UUID.self, forKey: .lessonID)
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        needsReview = try c.decodeIfPresent(Bool.self, forKey: .needsReview) ?? false
        isReviewed = try c.decodeIfPresent(Bool.self, forKey: .isReviewed) ?? false
        isDemo = try c.decodeIfPresent(Bool.self, forKey: .isDemo) ?? false
    }

    // Flagged for review and not yet ticked off.
    var isPendingReview: Bool { needsReview && !isReviewed }
}
