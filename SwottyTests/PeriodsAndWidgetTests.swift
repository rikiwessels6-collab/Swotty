import XCTest
@testable import Swotty

final class PeriodsAndWidgetTests: XCTestCase {
    // ---- Periods ----
    func testGeneratesEvenlySpacedPeriods() {
        let periods = ClassPeriod.generate(firstStart: 8 * 60, length: 45, gap: 5, count: 3)
        XCTAssertEqual(periods.map { $0.number }, [1, 2, 3])
        XCTAssertEqual(periods.map { $0.startMinutes }, [480, 530, 580])
        XCTAssertEqual(periods.map { $0.endMinutes }, [525, 575, 625])
    }

    func testNoPeriodsForAZeroCount() {
        XCTAssertTrue(ClassPeriod.generate(firstStart: 480, length: 45, gap: 5, count: 0).isEmpty)
    }

    func testPeriodsStopBeforeMidnight() {
        let periods = ClassPeriod.generate(firstStart: 23 * 60, length: 45, gap: 5, count: 5)
        XCTAssertEqual(periods.count, 1)
    }

    func testLessonPeriodDefaultsToNone() throws {
        let json = #"{"subjectID":"maths","weekday":3}"#.data(using: .utf8)!
        XCTAssertEqual(try JSONDecoder().decode(Lesson.self, from: json).period, 0)
        let negative = #"{"subjectID":"maths","weekday":3,"period":-4}"#.data(using: .utf8)!
        XCTAssertEqual(try JSONDecoder().decode(Lesson.self, from: negative).period, 0)
    }

    func testPeriodsSurviveBackupAndOldBackupsHaveNone() throws {
        let periods = ClassPeriod.generate(firstStart: 480, length: 45, gap: 5, count: 2)
        let decoded = try BackupFile.decode(from: BackupFile(periods: periods).encoded())
        XCTAssertEqual(decoded.periods.count, 2)
        XCTAssertEqual(decoded.periods.first?.startMinutes, 480)

        let old = #"{"version":1,"subjects":[],"items":[],"lessons":[]}"#.data(using: .utf8)!
        XCTAssertTrue(try BackupFile.decode(from: old).periods.isEmpty)
    }

    // ---- The data shared with the widget ----
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        utc.date(from: DateComponents(timeZone: utc.timeZone, year: year, month: month, day: day, hour: 12))!
    }

    private func lesson(_ id: String, start: Int, week: Int, weekday: Int = 2) -> SnapshotLesson {
        SnapshotLesson(id: id, subjectName: id, colorHex: 0xFFFFFF, weekday: weekday,
                       startMinutes: start, endMinutes: start + 45, room: "", teacher: "",
                       week: week, period: 0)
    }

    private func snapshot(twoWeek: Bool) -> WidgetSnapshot {
        WidgetSnapshot(generatedAt: Date(),
                       lessons: [lesson("b", start: 660, week: 2),
                                 lesson("every", start: 540, week: 0),
                                 lesson("a", start: 600, week: 1)],
                       tasks: [],
                       twoWeek: twoWeek,
                       weekAAnchor: date(2026, 11, 2).timeIntervalSince1970,
                       weekStart: 2,
                       showWeekend: false)
    }

    func testWidgetFollowsWeekAAndB() {
        let data = snapshot(twoWeek: true)
        // Monday 2 Nov is in Week A; Monday 9 Nov is in Week B.
        XCTAssertEqual(data.lessons(on: date(2026, 11, 2), calendar: utc).map { $0.id }, ["every", "a"])
        XCTAssertEqual(data.lessons(on: date(2026, 11, 9), calendar: utc).map { $0.id }, ["every", "b"])
        XCTAssertEqual(data.weekType(for: date(2026, 11, 2), calendar: utc), 1)
        XCTAssertEqual(data.weekType(for: date(2026, 11, 9), calendar: utc), 2)
    }

    func testWidgetShowsEveryLessonWhenTheTimetableIsTheSameEveryWeek() {
        let data = snapshot(twoWeek: false)
        XCTAssertEqual(data.lessons(on: date(2026, 11, 2), calendar: utc).map { $0.id }, ["every", "a", "b"])
        XCTAssertNil(data.weekType(for: date(2026, 11, 2), calendar: utc))
    }

    func testWidgetOnlyShowsLessonsForThatWeekday() {
        let data = snapshot(twoWeek: false)
        XCTAssertTrue(data.lessons(on: date(2026, 11, 3), calendar: utc).isEmpty)   // a Tuesday
    }

    func testSnapshotSurvivesEncodingAndDecoding() throws {
        var data = snapshot(twoWeek: true)
        let due = date(2026, 11, 20)
        data.tasks = [SnapshotTask(id: "t", title: "Algebra test", subjectName: "Maths",
                                   colorHex: 0xD1495B, typeName: "Exam", dueDate: due)]

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(WidgetSnapshot.self, from: encoder.encode(data))

        XCTAssertEqual(decoded.lessons.count, 3)
        XCTAssertEqual(decoded.tasks.first?.title, "Algebra test")
        XCTAssertEqual(decoded.tasks.first?.dueDate.timeIntervalSince1970 ?? 0, due.timeIntervalSince1970, accuracy: 1)
        XCTAssertTrue(decoded.twoWeek)
    }
}
