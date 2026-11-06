import Foundation

// A weekly repeating lesson in the timetable.
struct Lesson: Identifiable, Codable, Equatable {
    var id = UUID()
    var subjectID: String
    var weekday: Int          // Calendar numbering: 2 = Monday … 6 = Friday
    var startMinutes: Int     // minutes after midnight, e.g. 540 = 9:00
    var endMinutes: Int
    var room = ""
    var teacher = ""
    var isDemo = false        // added by "Start with demo data"
    var week = 0              // 0 = every week, 1 = Week A only, 2 = Week B only

    init(subjectID: String, weekday: Int, startMinutes: Int, endMinutes: Int,
         room: String = "", teacher: String = "", isDemo: Bool = false, week: Int = 0) {
        self.subjectID = subjectID
        self.weekday = weekday
        self.startMinutes = startMinutes
        self.endMinutes = endMinutes
        self.room = room
        self.teacher = teacher
        self.isDemo = isDemo
        self.week = week
    }

    enum CodingKeys: String, CodingKey {
        case id, subjectID, weekday, startMinutes, endMinutes, room, teacher, isDemo, week
    }

    // Missing values get sensible defaults so saved data always loads.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        subjectID = try c.decodeIfPresent(String.self, forKey: .subjectID) ?? Subject.otherID
        weekday = try c.decodeIfPresent(Int.self, forKey: .weekday) ?? 2
        startMinutes = try c.decodeIfPresent(Int.self, forKey: .startMinutes) ?? 540
        endMinutes = try c.decodeIfPresent(Int.self, forKey: .endMinutes) ?? 585
        room = try c.decodeIfPresent(String.self, forKey: .room) ?? ""
        teacher = try c.decodeIfPresent(String.self, forKey: .teacher) ?? ""
        isDemo = try c.decodeIfPresent(Bool.self, forKey: .isDemo) ?? false
        let savedWeek = try c.decodeIfPresent(Int.self, forKey: .week) ?? 0
        week = (0...2).contains(savedWeek) ? savedWeek : 0
    }

    // Does this lesson run in the given week? A nil week means the
    // timetable is the same every week, so everything applies.
    func runs(inWeek week: Int?) -> Bool {
        guard let week else { return true }
        return self.week == 0 || self.week == week
    }

    // "Room · Teacher", skipping whichever is empty.
    var details: String {
        [room, teacher].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    var timeRange: String {
        "\(Lesson.label(forMinutes: startMinutes)) – \(Lesson.label(forMinutes: endMinutes))"
    }

    func isOnNow(at date: Date = Date()) -> Bool {
        guard Calendar.current.component(.weekday, from: date) == weekday else { return false }
        let minutes = Lesson.minutes(from: date)
        return minutes >= startMinutes && minutes < endMinutes
    }

    // ---- Time helpers ----
    static func date(forMinutes minutes: Int) -> Date {
        Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60,
                              second: 0, of: Date()) ?? Date()
    }

    static func minutes(from date: Date) -> Int {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    // "9:00 am" in the device's own format.
    static func label(forMinutes minutes: Int) -> String {
        date(forMinutes: minutes).formatted(date: .omitted, time: .shortened)
    }
}
