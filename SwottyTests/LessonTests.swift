import XCTest
@testable import Swotty

final class LessonTests: XCTestCase {
    func testMinutesRoundTrip() {
        let date = Lesson.date(forMinutes: 8 * 60 + 45)
        XCTAssertEqual(Lesson.minutes(from: date), 525)
    }

    func testDetailsSkipsEmptyParts() {
        XCTAssertEqual(Lesson(subjectID: "x", weekday: 2, startMinutes: 540, endMinutes: 585).details, "")
        XCTAssertEqual(Lesson(subjectID: "x", weekday: 2, startMinutes: 540, endMinutes: 585,
                              room: "R1.02").details, "R1.02")
        XCTAssertEqual(Lesson(subjectID: "x", weekday: 2, startMinutes: 540, endMinutes: 585,
                              room: "R1.02", teacher: "Ms Patel").details, "R1.02 · Ms Patel")
    }

    func testIsOnNow() {
        // Build a date that falls on a Wednesday (weekday 4) at 10:00.
        var parts = DateComponents()
        parts.year = 2026; parts.month = 11; parts.day = 4   // Wed 4 Nov 2026
        parts.hour = 10; parts.minute = 0
        let wednesday = Calendar.current.date(from: parts)!

        let lesson = Lesson(subjectID: "x", weekday: 4, startMinutes: 9 * 60 + 30, endMinutes: 10 * 60 + 30)
        XCTAssertTrue(lesson.isOnNow(at: wednesday))

        let otherDay = Lesson(subjectID: "x", weekday: 5, startMinutes: 9 * 60 + 30, endMinutes: 10 * 60 + 30)
        XCTAssertFalse(otherDay.isOnNow(at: wednesday))

        let later = Lesson(subjectID: "x", weekday: 4, startMinutes: 11 * 60, endMinutes: 12 * 60)
        XCTAssertFalse(later.isOnNow(at: wednesday))
    }

    func testDecodesWithMissingFields() throws {
        let json = #"{"subjectID":"maths"}"#.data(using: .utf8)!
        let lesson = try JSONDecoder().decode(Lesson.self, from: json)
        XCTAssertEqual(lesson.subjectID, "maths")
        XCTAssertEqual(lesson.weekday, 2)
        XCTAssertFalse(lesson.isDemo)
    }

    func testAssessmentWithoutDemoFlagStillLoads() throws {
        // Data saved by version 1.0 has no "isDemo" key.
        let json = #"{"title":"Old","subject":"english"}"#.data(using: .utf8)!
        let item = try JSONDecoder().decode(Assessment.self, from: json)
        XCTAssertFalse(item.isDemo)
    }
}
