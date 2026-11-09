import XCTest
@testable import Swotty

final class GradesAndBackupTests: XCTestCase {
    private func marked(_ score: Double, outOf: Double, weight: Double = 1) -> Assessment {
        var a = Assessment(title: "t", type: .exam, subjectID: Subject.maths.id, dueDate: Date())
        a.score = score
        a.outOf = outOf
        a.weight = weight
        return a
    }

    func testWeightedAverage() {
        // 100% at weight 1 and 50% at weight 3 → (100 + 150) / 4 = 62.5
        let items = [marked(10, outOf: 10), marked(5, outOf: 10, weight: 3)]
        XCTAssertEqual(items.weightedAveragePercentage ?? 0, 62.5, accuracy: 0.001)
    }

    func testAverageIgnoresUnmarkedItems() {
        let unmarked = Assessment(title: "t", type: .quiz, subjectID: "x", dueDate: Date())
        XCTAssertNil([unmarked].weightedAveragePercentage)
        XCTAssertEqual([unmarked, marked(8, outOf: 10)].weightedAveragePercentage ?? 0, 80, accuracy: 0.001)
    }

    func testOldDataGetsDefaultWeight() throws {
        let json = #"{"title":"Old","subject":"english","score":9,"outOf":10}"#.data(using: .utf8)!
        let item = try JSONDecoder().decode(Assessment.self, from: json)
        XCTAssertEqual(item.weight, 1)
        let bad = #"{"title":"Old","weight":0}"#.data(using: .utf8)!
        XCTAssertEqual(try JSONDecoder().decode(Assessment.self, from: bad).weight, 1)
    }

    func testBackupRoundTrip() throws {
        var item = marked(17, outOf: 20, weight: 2)
        item.title = "Algebra"
        item.dueDate = Date(timeIntervalSince1970: 1_800_000_000)
        let lesson = Lesson(subjectID: "maths", weekday: 3, startMinutes: 540, endMinutes: 585, room: "R1")
        let backup = BackupFile(studentName: "Sam", subjects: Subject.defaults, items: [item], lessons: [lesson])

        let decoded = try BackupFile.decode(from: backup.encoded())
        XCTAssertEqual(decoded.studentName, "Sam")
        XCTAssertEqual(decoded.items.count, 1)
        XCTAssertEqual(decoded.items[0].title, "Algebra")
        XCTAssertEqual(decoded.items[0].weight, 2)
        XCTAssertEqual(decoded.items[0].dueDate.timeIntervalSince1970, 1_800_000_000, accuracy: 1)
        XCTAssertEqual(decoded.lessons.first?.room, "R1")
        XCTAssertEqual(decoded.subjects.count, Subject.defaults.count)
    }

    func testBackupRejectsGarbageAndNewerVersions() throws {
        XCTAssertThrowsError(try BackupFile.decode(from: Data("hello".utf8)))

        var newer = BackupFile()
        newer.version = BackupFile.currentVersion + 1
        XCTAssertThrowsError(try BackupFile.decode(from: newer.encoded())) { error in
            XCTAssertEqual(error as? BackupError, BackupError.newerVersion)
        }
    }
}

final class GradeTargetTests: XCTestCase {
    private func result(_ score: Double, weight: Double = 1) -> Assessment {
        var a = Assessment(title: "r", type: .exam, subjectID: Subject.maths.id, dueDate: Date())
        a.score = score
        a.outOf = 100
        a.weight = weight
        return a
    }

    func testNeededScoreWithNoResultsIsTheTarget() {
        XCTAssertEqual(GradeTarget.scoreNeeded(items: [], target: 80), 80, accuracy: 0.001)
    }

    func testNeededScoreToLiftAverage() {
        // One 70, target 80, equal weight: next must be 90.
        XCTAssertEqual(GradeTarget.scoreNeeded(items: [result(70)], target: 80), 90, accuracy: 0.001)
    }

    func testNeededScoreRespectsWeights() {
        // 60 at weight 3, target 70, next weight 1: (70*4 - 180)/1 = 100.
        XCTAssertEqual(GradeTarget.scoreNeeded(items: [result(60, weight: 3)], target: 70), 100, accuracy: 0.001)
    }

    func testAdviceWording() {
        XCTAssertEqual(GradeTarget.advice(items: [result(70)], target: 80), "Aim for 90% next to reach 80%")
        XCTAssertTrue(GradeTarget.advice(items: [result(50)], target: 90).contains("out of reach"))
        XCTAssertTrue(GradeTarget.advice(items: [result(95)], target: 80).hasPrefix("On track for 80%"))
    }

    func testOldSubjectsWithoutTargetStillDecode() throws {
        let json = #"{"id":"maths","name":"Maths","colour":"red","icon":"function"}"#.data(using: .utf8)!
        let subject = try JSONDecoder().decode(Subject.self, from: json)
        XCTAssertNil(subject.targetPercentage)
    }
}
