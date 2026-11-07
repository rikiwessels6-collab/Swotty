import XCTest
@testable import Swotty

final class ScheduleSettingsTests: XCTestCase {
    func testMondayStartWithoutWeekend() {
        XCTAssertEqual(ScheduleSettings.orderedDays(weekStart: 2, showWeekend: false), [2, 3, 4, 5, 6])
    }

    func testMondayStartWithWeekend() {
        // Monday … Saturday, then Sunday
        XCTAssertEqual(ScheduleSettings.orderedDays(weekStart: 2, showWeekend: true), [2, 3, 4, 5, 6, 7, 1])
    }

    func testSundayStartWithWeekend() {
        XCTAssertEqual(ScheduleSettings.orderedDays(weekStart: 1, showWeekend: true), [1, 2, 3, 4, 5, 6, 7])
    }

    func testSundayStartWithoutWeekendHidesBoth() {
        XCTAssertEqual(ScheduleSettings.orderedDays(weekStart: 1, showWeekend: false), [2, 3, 4, 5, 6])
    }

    func testInvalidWeekStartFallsBackToMonday() {
        XCTAssertEqual(ScheduleSettings.orderedDays(weekStart: 0, showWeekend: false), [2, 3, 4, 5, 6])
        XCTAssertEqual(ScheduleSettings.orderedDays(weekStart: 9, showWeekend: false), [2, 3, 4, 5, 6])
    }

    func testRoundingToFiveMinutes() {
        XCTAssertEqual(ScheduleSettings.rounded(9 * 60 + 12), 9 * 60 + 10)   // 9:12 → 9:10
        XCTAssertEqual(ScheduleSettings.rounded(9 * 60 + 13), 9 * 60 + 15)   // 9:13 → 9:15
        XCTAssertEqual(ScheduleSettings.rounded(9 * 60 + 15), 9 * 60 + 15)   // already on a step
        XCTAssertEqual(ScheduleSettings.rounded(0), 0)
    }

    func testRoundingStaysInsideTheDay() {
        XCTAssertLessThan(ScheduleSettings.rounded(24 * 60 - 1), 24 * 60)
    }

    func testAccentColourStillDecodesFromOldValues() throws {
        // Saved settings from before the redesign must still load.
        for raw in ["indigo", "red", "grey", "gold", "emerald"] {
            XCTAssertNotNil(SubjectColour(rawValue: raw), raw)
        }
    }
}
