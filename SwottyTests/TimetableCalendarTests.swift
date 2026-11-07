import XCTest
@testable import Swotty

final class TimetableCalendarTests: XCTestCase {
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

    private func lesson(weekday: Int, week: Int = 0) -> Lesson {
        Lesson(subjectID: "maths", weekday: weekday, startMinutes: 540, endMinutes: 585, week: week)
    }

    func testEveryWeekLessonRepeatsWeekly() {
        // Today is Thursday 5 Nov; a Monday lesson first happens on Monday 9 Nov.
        let result = CalendarSync.firstOccurrence(of: lesson(weekday: 2), twoWeek: false, anchor: 0,
                                                  weekStart: 2, from: date(2026, 11, 5), calendar: utc)
        XCTAssertEqual(result?.intervalWeeks, 1)
        XCTAssertEqual(utc.startOfDay(for: result!.firstDate), utc.startOfDay(for: date(2026, 11, 9)))
    }

    func testTodayCountsAsTheFirstOccurrence() {
        let result = CalendarSync.firstOccurrence(of: lesson(weekday: 5), twoWeek: false, anchor: 0,
                                                  weekStart: 2, from: date(2026, 11, 5), calendar: utc)
        XCTAssertEqual(utc.startOfDay(for: result!.firstDate), utc.startOfDay(for: date(2026, 11, 5)))
    }

    func testWeekALessonStartsInWeekAAndRepeatsEveryTwoWeeks() {
        // Thursday 5 Nov is in Week A, so a Week A Monday lesson first happens
        // on Monday 16 Nov (Week A again), not Monday 9 Nov (Week B).
        let result = CalendarSync.firstOccurrence(of: lesson(weekday: 2, week: 1), twoWeek: true, anchor: anchor,
                                                  weekStart: 2, from: date(2026, 11, 5), calendar: utc)
        XCTAssertEqual(result?.intervalWeeks, 2)
        XCTAssertEqual(utc.startOfDay(for: result!.firstDate), utc.startOfDay(for: date(2026, 11, 16)))
    }

    func testWeekBLessonStartsInWeekB() {
        let result = CalendarSync.firstOccurrence(of: lesson(weekday: 2, week: 2), twoWeek: true, anchor: anchor,
                                                  weekStart: 2, from: date(2026, 11, 5), calendar: utc)
        XCTAssertEqual(result?.intervalWeeks, 2)
        XCTAssertEqual(utc.startOfDay(for: result!.firstDate), utc.startOfDay(for: date(2026, 11, 9)))
    }

    func testBothWeeksLessonStillRepeatsWeeklyInAB() {
        let result = CalendarSync.firstOccurrence(of: lesson(weekday: 2, week: 0), twoWeek: true, anchor: anchor,
                                                  weekStart: 2, from: date(2026, 11, 5), calendar: utc)
        XCTAssertEqual(result?.intervalWeeks, 1)
        XCTAssertEqual(utc.startOfDay(for: result!.firstDate), utc.startOfDay(for: date(2026, 11, 9)))
    }

    func testWeekLabelsAreIgnoredWhenTimetableIsTheSameEveryWeek() {
        // A lesson tagged Week B in a single-week timetable still repeats weekly.
        let result = CalendarSync.firstOccurrence(of: lesson(weekday: 2, week: 2), twoWeek: false, anchor: 0,
                                                  weekStart: 2, from: date(2026, 11, 5), calendar: utc)
        XCTAssertEqual(result?.intervalWeeks, 1)
    }
}
