import XCTest
@testable import Swotty

final class AssessmentTests: XCTestCase {
    private func make(due: Date = Date()) -> Assessment {
        Assessment(title: "Test", type: .exam, subjectID: Subject.maths.id, dueDate: due)
    }

    func testPercentage() {
        var a = make()
        XCTAssertNil(a.percentage)
        a.score = 17
        a.outOf = 20
        XCTAssertEqual(a.percentage ?? 0, 85, accuracy: 0.001)
        a.outOf = 0
        XCTAssertNil(a.percentage)
    }

    func testDaysRemaining() {
        let cal = Calendar.current
        XCTAssertEqual(make(due: Date()).daysRemaining, 0)
        XCTAssertEqual(make(due: cal.date(byAdding: .day, value: 3, to: Date())!).daysRemaining, 3)
        XCTAssertEqual(make(due: cal.date(byAdding: .day, value: -2, to: Date())!).daysRemaining, -2)
    }

    func testStepsDone() {
        var a = make()
        a.steps = [ChecklistStep(text: "a", isDone: true), ChecklistStep(text: "b")]
        XCTAssertEqual(a.stepsDone, 1)
    }

    // Older saved data (using the legacy "subject" key, with fields missing)
    // must still load.
    func testDecodesLegacyData() throws {
        let json = #"{"title":"Old task","subject":"hass"}"#.data(using: .utf8)!
        let a = try JSONDecoder().decode(Assessment.self, from: json)
        XCTAssertEqual(a.title, "Old task")
        XCTAssertEqual(a.subjectID, "hass")
        XCTAssertEqual(a.type, .assignment)
        XCTAssertFalse(a.isCompleted)
        XCTAssertTrue(a.steps.isEmpty)
    }

    func testRoundTripKeepsLegacyKey() throws {
        let data = try JSONEncoder().encode(make())
        let text = String(data: data, encoding: .utf8)!
        XCTAssertTrue(text.contains("\"subject\""))
    }

    func testFormatting() {
        XCTAssertEqual(formatNumber(17), "17")
        XCTAssertEqual(formatNumber(17.5), "17.5")
        XCTAssertEqual(formatMinutes(45), "45 min")
        XCTAssertEqual(formatMinutes(120), "2 h")
        XCTAssertEqual(formatMinutes(95), "1 h 35 min")
    }

    func testAccessibilitySummary() {
        var a = make(due: Calendar.current.date(byAdding: .day, value: 1, to: Date())!)
        a.steps = [ChecklistStep(text: "a", isDone: true), ChecklistStep(text: "b")]
        XCTAssertEqual(a.accessibilitySummary(subjectName: "Maths"),
                       "Maths exam: Test, due tomorrow, 1 of 2 steps done")
        a.isCompleted = true
        a.score = 17
        a.outOf = 20
        XCTAssertTrue(a.accessibilitySummary(subjectName: "Maths").contains("completed"))
        XCTAssertTrue(a.accessibilitySummary(subjectName: "Maths").contains("scored 85 percent"))
    }

    func testDuplicateIsFreshAndUnfinished() {
        var a = make()
        a.isCompleted = true
        a.score = 5
        a.outOf = 10
        a.steps = [ChecklistStep(text: "a", isDone: true)]
        let copy = a.duplicated()
        XCTAssertNotEqual(copy.id, a.id)
        XCTAssertEqual(copy.title, "Test (copy)")
        XCTAssertFalse(copy.isCompleted)
        XCTAssertNil(copy.score)
        XCTAssertFalse(copy.steps[0].isDone)
        XCTAssertNotEqual(copy.steps[0].id, a.steps[0].id)
    }

    func testSearchMatchesTitleNotesAndSubject() {
        var a = make()
        a.title = "Algebra test"
        a.notes = "Chapter 4"
        XCTAssertTrue(a.matches(search: "", subjectName: "Maths"))
        XCTAssertTrue(a.matches(search: "algebra", subjectName: "Maths"))
        XCTAssertTrue(a.matches(search: "chapter", subjectName: "Maths"))
        XCTAssertTrue(a.matches(search: "math", subjectName: "Maths"))
        XCTAssertFalse(a.matches(search: "history", subjectName: "Maths"))
    }
}
