import XCTest
@testable import Swotty

final class InsightsTests: XCTestCase {
    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    // Monday 10 Nov 2025, 09:00
    private var now: Date {
        cal.date(from: DateComponents(year: 2025, month: 11, day: 10, hour: 9))!
    }

    private func date(_ day: Int) -> Date {
        cal.date(from: DateComponents(year: 2025, month: 11, day: day, hour: 12))!
    }

    private func item(_ title: String, day: Int, type: AssessmentType = .assignment) -> Assessment {
        Assessment(title: title, type: type, subjectID: Subject.maths.id, dueDate: date(day))
    }

    func testBusyWeekNeedsThreeItems() {
        let items = [item("a", day: 11), item("b", day: 12), item("c", day: 14)]
        let busy = Insights.busyWeeks(items, now: now, calendar: cal)
        XCTAssertEqual(busy.count, 1)
        XCTAssertEqual(busy.first?.count, 3)
        XCTAssertTrue(Insights.busyWeeks(Array(items.prefix(2)), now: now, calendar: cal).isEmpty)
    }

    func testBusyWeekIgnoresCompleted() {
        var done = item("c", day: 14)
        done.isCompleted = true
        let items = [item("a", day: 11), item("b", day: 12), done]
        XCTAssertTrue(Insights.busyWeeks(items, now: now, calendar: cal).isEmpty)
    }

    func testNextExamSkipsPastAndNonExams() {
        let items = [item("old", day: 8, type: .exam), item("task", day: 11),
                     item("later", day: 20, type: .exam), item("soon", day: 13, type: .exam)]
        XCTAssertEqual(Insights.nextExam(items, now: now, calendar: cal)?.title, "soon")
    }

    func testRevisionDaysAreBeforeExamAndNotInPast() {
        // Exam Mon 17 Nov: 10, 14 and 16 Nov.
        let far = item("e", day: 17, type: .exam)
        XCTAssertEqual(Insights.revisionDays(for: far, now: now, calendar: cal).count, 3)
        // Exam Wed 12 Nov: only 11 Nov is still ahead.
        let near = item("e", day: 12, type: .exam)
        XCTAssertEqual(Insights.revisionDays(for: near, now: now, calendar: cal).count, 1)
    }

    func testCountdownText() {
        XCTAssertEqual(Insights.countdownText(days: 0), "today")
        XCTAssertEqual(Insights.countdownText(days: 1), "tomorrow")
        XCTAssertEqual(Insights.countdownText(days: 5), "in 5 days")
    }

    func testQuickAddParsesWeekdayAndType() {
        let r = QuickAdd.parse("maths exam on Friday", now: now, calendar: cal)
        XCTAssertEqual(r.title, "Maths exam")
        XCTAssertEqual(r.type, .exam)
        XCTAssertEqual(r.date, cal.date(from: DateComponents(year: 2025, month: 11, day: 14)))
    }

    func testQuickAddTomorrowAndNextWeek() {
        let t = QuickAdd.parse("Read chapter 4 tomorrow", now: now, calendar: cal)
        XCTAssertEqual(t.title, "Read chapter 4")
        XCTAssertEqual(t.date, cal.date(from: DateComponents(year: 2025, month: 11, day: 11)))
        let w = QuickAdd.parse("History essay next week", now: now, calendar: cal)
        XCTAssertEqual(w.date, cal.date(from: DateComponents(year: 2025, month: 11, day: 17)))
        XCTAssertEqual(w.type, .assignment)
    }

    func testQuickAddSameWeekdayMeansNextWeek() {
        let r = QuickAdd.parse("quiz monday", now: now, calendar: cal)
        XCTAssertEqual(r.date, cal.date(from: DateComponents(year: 2025, month: 11, day: 17)))
        XCTAssertEqual(r.type, .quiz)
    }

    func testQuickAddWithoutDateKeepsTitle() {
        let r = QuickAdd.parse("Science project", now: now, calendar: cal)
        XCTAssertEqual(r.title, "Science project")
        XCTAssertNil(r.date)
    }
}

final class StudyRemindersTests: XCTestCase {
    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    // Monday 10 Nov 2025, 09:00
    private var now: Date { cal.date(from: DateComponents(year: 2025, month: 11, day: 10, hour: 9))! }

    private func item(_ title: String, day: Int, type: AssessmentType) -> Assessment {
        Assessment(title: title, type: type, subjectID: Subject.maths.id,
                   dueDate: cal.date(from: DateComponents(year: 2025, month: 11, day: day, hour: 12))!)
    }

    func testRevisionPlanForExamNextWeek() {
        let plan = StudyReminders.revisionPlan(items: [item("e", day: 17, type: .exam)],
                                               subjectName: { _ in "Maths" }, hour: 16,
                                               now: now, calendar: cal)
        XCTAssertEqual(plan.count, 3)
        XCTAssertEqual(Set(plan.map { $0.id }).count, 3)
        XCTAssertTrue(plan.allSatisfy { $0.fireDate > now })
        XCTAssertTrue(plan.last!.body.contains("tomorrow"))
    }

    func testRevisionPlanIgnoresFarExamsAndNonExams() {
        let items = [item("far", day: 30, type: .exam), item("task", day: 12, type: .assignment)]
        XCTAssertTrue(StudyReminders.revisionPlan(items: items, subjectName: { _ in "Maths" },
                                                  hour: 16, now: now, calendar: cal).isEmpty)
    }

    func testWeeklySummaryCountsNextMondayToSunday() {
        // Sunday 16 Nov at 18:00, covering Mon 17 to Sun 23 Nov.
        let items = [item("a", day: 17, type: .assignment), item("b", day: 21, type: .quiz),
                     item("c", day: 24, type: .exam), item("d", day: 14, type: .exam)]
        let summary = StudyReminders.weeklySummary(items: items, now: now, calendar: cal)
        XCTAssertEqual(summary?.fireDate, cal.date(from: DateComponents(year: 2025, month: 11, day: 16, hour: 18)))
        XCTAssertTrue(summary?.body.contains("2 things") ?? false)
    }

    func testWeeklySummaryIsNilWhenNothingDue() {
        XCTAssertNil(StudyReminders.weeklySummary(items: [], now: now, calendar: cal))
    }
}
