import XCTest
@testable import Swotty

final class WeekABTests: XCTestCase {
    // A fixed calendar so the tests don't depend on the machine's time zone.
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        utc.date(from: DateComponents(timeZone: utc.timeZone, year: year, month: month, day: day, hour: hour))!
    }

    // Monday 2 November 2026 is in a Week A.
    private var anchor: TimeInterval { date(2026, 11, 2).timeIntervalSince1970 }

    // ---- Which week is it? ----
    func testWeeksAlternate() {
        func type(_ y: Int, _ m: Int, _ d: Int) -> Int {
            ScheduleSettings.weekType(for: date(y, m, d), anchor: anchor, weekStart: 2, calendar: utc)
        }
        XCTAssertEqual(type(2026, 11, 2), 1)    // Mon, anchor week      → A
        XCTAssertEqual(type(2026, 11, 4), 1)    // Wed, same week        → A
        XCTAssertEqual(type(2026, 11, 8), 1)    // Sun, still that week  → A (week starts Monday)
        XCTAssertEqual(type(2026, 11, 9), 2)    // next Monday           → B
        XCTAssertEqual(type(2026, 11, 16), 1)   // week after that       → A
        XCTAssertEqual(type(2026, 10, 31), 2)   // week before anchor    → B
        XCTAssertEqual(type(2026, 10, 26), 2)
        XCTAssertEqual(type(2026, 10, 19), 1)
    }

    func testNoAnchorMeansWeekA() {
        XCTAssertEqual(ScheduleSettings.weekType(for: date(2026, 11, 9), anchor: 0, weekStart: 2, calendar: utc), 1)
    }

    func testSettingTheCurrentWeek() {
        let wednesday = date(2026, 11, 11)   // in the week starting Monday 9 Nov
        let asB = ScheduleSettings.anchor(settingWeekOf: wednesday, to: 2, weekStart: 2, calendar: utc)
        XCTAssertEqual(ScheduleSettings.weekType(for: wednesday, anchor: asB, weekStart: 2, calendar: utc), 2)
        // The weeks alternate from there: 11 Nov is B, so 18 Nov is A and 25 Nov is B again.
        XCTAssertEqual(ScheduleSettings.weekType(for: date(2026, 11, 18), anchor: asB, weekStart: 2, calendar: utc), 1)
        XCTAssertEqual(ScheduleSettings.weekType(for: date(2026, 11, 25), anchor: asB, weekStart: 2, calendar: utc), 2)
        XCTAssertEqual(ScheduleSettings.weekType(for: date(2026, 11, 4), anchor: asB, weekStart: 2, calendar: utc), 1)

        let asA = ScheduleSettings.anchor(settingWeekOf: wednesday, to: 1, weekStart: 2, calendar: utc)
        XCTAssertEqual(ScheduleSettings.weekType(for: wednesday, anchor: asA, weekStart: 2, calendar: utc), 1)
    }

    func testSundayWeekStartMovesTheBoundary() {
        // With weeks starting on Sunday, Sunday 8 Nov begins the next week (B).
        let sunday = date(2026, 11, 8)
        let anchorSunday = ScheduleSettings.anchor(settingWeekOf: date(2026, 11, 4), to: 1, weekStart: 1, calendar: utc)
        XCTAssertEqual(ScheduleSettings.weekType(for: sunday, anchor: anchorSunday, weekStart: 1, calendar: utc), 2)
        XCTAssertEqual(ScheduleSettings.weekType(for: date(2026, 11, 7), anchor: anchorSunday, weekStart: 1, calendar: utc), 1)
    }

    // ---- Saved settings ----
    private func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "weekab-tests-\(UUID().uuidString)")!
    }

    func testSingleWeekTimetableHasNoWeekType() {
        let defaults = freshDefaults()
        XCTAssertNil(ScheduleSettings.weekType(on: Date(), defaults: defaults))
        ScheduleSettings.setTimetableWeeks(1, defaults: defaults)
        XCTAssertNil(ScheduleSettings.weekType(on: Date(), defaults: defaults))
    }

    func testTurningOnTwoWeeksMakesThisWeekA() {
        let defaults = freshDefaults()
        ScheduleSettings.setTimetableWeeks(2, defaults: defaults)
        XCTAssertEqual(ScheduleSettings.weekType(on: Date(), defaults: defaults), 1)
    }

    func testThisWeekCanBeSetToB() {
        let defaults = freshDefaults()
        ScheduleSettings.setTimetableWeeks(2, defaults: defaults)
        ScheduleSettings.setCurrentWeekType(2, defaults: defaults)
        XCTAssertEqual(ScheduleSettings.weekType(on: Date(), defaults: defaults), 2)
        let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
        XCTAssertEqual(ScheduleSettings.weekType(on: nextWeek, defaults: defaults), 1)
    }

    func testChangingWeekStartKeepsThisWeekTheSame() {
        let defaults = freshDefaults()
        ScheduleSettings.setTimetableWeeks(2, defaults: defaults)
        ScheduleSettings.setCurrentWeekType(2, defaults: defaults)
        ScheduleSettings.setWeekStart(1, defaults: defaults)      // Monday → Sunday
        XCTAssertEqual(ScheduleSettings.weekType(on: Date(), defaults: defaults), 2)
        ScheduleSettings.setWeekStart(7, defaults: defaults)      // → Saturday
        XCTAssertEqual(ScheduleSettings.weekType(on: Date(), defaults: defaults), 2)
    }

    // ---- Lessons ----
    func testLessonWeekFiltering() {
        let every = Lesson(subjectID: "x", weekday: 2, startMinutes: 540, endMinutes: 585)
        let weekA = Lesson(subjectID: "x", weekday: 2, startMinutes: 540, endMinutes: 585, week: 1)
        let weekB = Lesson(subjectID: "x", weekday: 2, startMinutes: 540, endMinutes: 585, week: 2)

        XCTAssertTrue(every.runs(inWeek: 1))
        XCTAssertTrue(every.runs(inWeek: 2))
        XCTAssertTrue(weekA.runs(inWeek: 1))
        XCTAssertFalse(weekA.runs(inWeek: 2))
        XCTAssertFalse(weekB.runs(inWeek: 1))
        XCTAssertTrue(weekB.runs(inWeek: 2))
        // A timetable that is the same every week shows everything.
        XCTAssertTrue(weekA.runs(inWeek: nil))
        XCTAssertTrue(weekB.runs(inWeek: nil))
    }

    func testLessonsSavedBeforeWeekABLoadAsEveryWeek() throws {
        let json = #"{"subjectID":"maths","weekday":3}"#.data(using: .utf8)!
        XCTAssertEqual(try JSONDecoder().decode(Lesson.self, from: json).week, 0)
    }

    func testInvalidWeekValueFallsBackToEveryWeek() throws {
        let json = #"{"subjectID":"maths","weekday":3,"week":9}"#.data(using: .utf8)!
        XCTAssertEqual(try JSONDecoder().decode(Lesson.self, from: json).week, 0)
    }

    func testWeekSurvivesBackup() throws {
        let lesson = Lesson(subjectID: "maths", weekday: 3, startMinutes: 540, endMinutes: 585, week: 2)
        let decoded = try BackupFile.decode(from: BackupFile(lessons: [lesson]).encoded())
        XCTAssertEqual(decoded.lessons.first?.week, 2)
    }

    // ---- Reminders ----
    func testReminderDatesFollowWeekAAndB() {
        let monday = 2
        let everyWeek = Lesson(subjectID: "x", weekday: monday, startMinutes: 9 * 60, endMinutes: 9 * 60 + 45)
        let weekA = Lesson(subjectID: "a", weekday: monday, startMinutes: 10 * 60, endMinutes: 10 * 60 + 45, week: 1)
        let weekB = Lesson(subjectID: "b", weekday: monday, startMinutes: 11 * 60, endMinutes: 11 * 60 + 45, week: 2)

        // Sunday 1 Nov: the next two Mondays are 2 Nov (Week A) and 9 Nov (Week B).
        let reminders = ClassReminders.upcomingReminders(
            lessons: [everyWeek, weekA, weekB], minutesBefore: 10, twoWeek: true,
            anchor: anchor, weekStart: 2, from: date(2026, 11, 1, hour: 8), calendar: utc)

        func fire(_ day: Int, _ hour: Int, _ minute: Int) -> Date {
            utc.date(from: DateComponents(timeZone: utc.timeZone, year: 2026, month: 11, day: day,
                                          hour: hour, minute: minute))!
        }
        XCTAssertEqual(reminders.map { $0.fireDate }, [
            fire(2, 8, 50),    // every-week lesson, Week A Monday
            fire(2, 9, 50),    // Week A lesson
            fire(9, 8, 50),    // every-week lesson, Week B Monday
            fire(9, 10, 50)    // Week B lesson
        ])
        XCTAssertEqual(reminders.map { $0.lesson.subjectID }, ["x", "a", "x", "b"])
    }

    func testReminderLimitKeepsTheEarliest() {
        let lesson = Lesson(subjectID: "x", weekday: 2, startMinutes: 9 * 60, endMinutes: 9 * 60 + 45)
        let reminders = ClassReminders.upcomingReminders(
            lessons: [lesson], minutesBefore: 10, twoWeek: true,
            anchor: anchor, weekStart: 2, from: date(2026, 11, 1, hour: 8), limit: 1, calendar: utc)
        XCTAssertEqual(reminders.count, 1)
    }

    func testPastRemindersAreSkipped() {
        let lesson = Lesson(subjectID: "x", weekday: 2, startMinutes: 9 * 60, endMinutes: 9 * 60 + 45)
        // It's already 9:30 on Monday 2 Nov, so that day's 8:50 reminder is gone.
        let reminders = ClassReminders.upcomingReminders(
            lessons: [lesson], minutesBefore: 10, twoWeek: false,
            anchor: 0, weekStart: 2, from: date(2026, 11, 2, hour: 9), calendar: utc)
        XCTAssertEqual(reminders.first?.fireDate,
                       utc.date(from: DateComponents(timeZone: utc.timeZone, year: 2026, month: 11, day: 9,
                                                     hour: 8, minute: 50)))
    }
}
