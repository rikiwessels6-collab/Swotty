import Foundation

// One slot in the school day's bell schedule: "Period 1, 8:00 – 8:45".
// Lessons can sit in a period instead of having their own start and end time.
struct ClassPeriod: Identifiable, Codable, Equatable {
    var id = UUID()
    var number: Int
    var startMinutes: Int     // minutes after midnight
    var endMinutes: Int

    init(number: Int, startMinutes: Int, endMinutes: Int) {
        self.number = number
        self.startMinutes = startMinutes
        self.endMinutes = endMinutes
    }

    enum CodingKeys: String, CodingKey {
        case id, number, startMinutes, endMinutes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        number = try c.decodeIfPresent(Int.self, forKey: .number) ?? 1
        startMinutes = try c.decodeIfPresent(Int.self, forKey: .startMinutes) ?? 540
        endMinutes = try c.decodeIfPresent(Int.self, forKey: .endMinutes) ?? 585
    }

    var timeRange: String {
        "\(Lesson.label(forMinutes: startMinutes)) – \(Lesson.label(forMinutes: endMinutes))"
    }

    // Evenly spaced periods, e.g. first at 8:00, 45 minutes long, 5 minutes between.
    static func generate(firstStart: Int, length: Int, gap: Int, count: Int) -> [ClassPeriod] {
        guard count >= 1, length >= 1 else { return [] }
        var periods: [ClassPeriod] = []
        var start = firstStart
        for number in 1...count {
            let end = start + length
            guard end < 24 * 60 else { break }
            periods.append(ClassPeriod(number: number, startMinutes: start, endMinutes: end))
            start = end + max(gap, 0)
        }
        return periods
    }
}
