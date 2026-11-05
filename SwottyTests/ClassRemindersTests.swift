import XCTest
@testable import Swotty

final class ClassRemindersTests: XCTestCase {
    private func lesson(start: Int, weekday: Int = 3) -> Lesson {
        Lesson(subjectID: "maths", weekday: weekday, startMinutes: start, endMinutes: start + 45)
    }

    func testClassReminderFiresBeforeStart() {
        // 9:00 am class, 10 minutes before → 8:50 on a Tuesday (weekday 3)
        let parts = ClassReminders.triggerComponents(for: lesson(start: 540), minutesBefore: 10)
        XCTAssertEqual(parts?.weekday, 3)
        XCTAssertEqual(parts?.hour, 8)
        XCTAssertEqual(parts?.minute, 50)
    }

    func testClassReminderCrossingHourBoundary() {
        // 8:05 am class, 15 minutes before → 7:50
        let parts = ClassReminders.triggerComponents(for: lesson(start: 8 * 60 + 5), minutesBefore: 15)
        XCTAssertEqual(parts?.hour, 7)
        XCTAssertEqual(parts?.minute, 50)
    }

    func testClassReminderBeforeMidnightIsSkipped() {
        XCTAssertNil(ClassReminders.triggerComponents(for: lesson(start: 5), minutesBefore: 10))
    }

    func testReviewReminderIsLaterTodayIfTimeHasNotPassed() {
        let calendar = Calendar.current
        let tenAM = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: Date())!
        let fire = ClassReminders.nextReviewFireDate(after: tenAM, hour: 16, calendar: calendar)
        XCTAssertEqual(calendar.component(.hour, from: fire), 16)
        XCTAssertTrue(calendar.isDate(fire, inSameDayAs: tenAM))
    }

    func testReviewReminderMovesToTomorrowIfTimeHasPassed() {
        let calendar = Calendar.current
        let fivePM = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: Date())!
        let fire = ClassReminders.nextReviewFireDate(after: fivePM, hour: 16, calendar: calendar)
        XCTAssertEqual(calendar.component(.hour, from: fire), 16)
        XCTAssertTrue(calendar.isDate(fire, inSameDayAs: calendar.date(byAdding: .day, value: 1, to: fivePM)!))
    }
}
