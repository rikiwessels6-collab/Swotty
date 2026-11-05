import XCTest
@testable import Swotty

final class ClassNoteTests: XCTestCase {
    func testDateIsNormalisedToStartOfDay() {
        let afternoon = Calendar.current.date(bySettingHour: 15, minute: 30, second: 0, of: Date())!
        let note = ClassNote(date: afternoon, subjectID: "maths", text: "x")
        XCTAssertEqual(note.date, Calendar.current.startOfDay(for: afternoon))
    }

    func testPendingReview() {
        var note = ClassNote(date: Date(), subjectID: "maths", text: "x")
        XCTAssertFalse(note.isPendingReview)          // not flagged
        note.needsReview = true
        XCTAssertTrue(note.isPendingReview)           // flagged, not done
        note.isReviewed = true
        XCTAssertFalse(note.isPendingReview)          // ticked off
    }

    func testDecodesWithMissingFields() throws {
        let json = #"{"text":"Revise fractions"}"#.data(using: .utf8)!
        let note = try JSONDecoder().decode(ClassNote.self, from: json)
        XCTAssertEqual(note.text, "Revise fractions")
        XCTAssertEqual(note.subjectID, Subject.otherID)
        XCTAssertNil(note.lessonID)
        XCTAssertFalse(note.needsReview)
        XCTAssertFalse(note.isReviewed)
    }

    func testBackupRoundTripKeepsNotes() throws {
        let lessonID = UUID()
        let note = ClassNote(date: Date(timeIntervalSince1970: 1_800_000_000),
                             subjectID: "science", lessonID: lessonID,
                             text: "Cells quiz prep", needsReview: true)
        let backup = BackupFile(notes: [note])
        let decoded = try BackupFile.decode(from: backup.encoded())
        XCTAssertEqual(decoded.notes.count, 1)
        XCTAssertEqual(decoded.notes[0].text, "Cells quiz prep")
        XCTAssertEqual(decoded.notes[0].lessonID, lessonID)
        XCTAssertTrue(decoded.notes[0].needsReview)
    }

    // A backup made by version 1.6 has no "notes" key and must still restore.
    func testOldBackupWithoutNotesStillLoads() throws {
        let json = #"{"version":1,"subjects":[],"items":[],"lessons":[]}"#.data(using: .utf8)!
        let backup = try BackupFile.decode(from: json)
        XCTAssertTrue(backup.notes.isEmpty)
    }
}
