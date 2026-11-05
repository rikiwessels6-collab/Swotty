import SwiftUI

// MARK: - The store (all data, saved automatically)
final class StudyStore: ObservableObject {
    @Published var items: [Assessment] = [] {
        didSet { save(items, key: itemsKey) }
    }
    @Published var subjects: [Subject] = Subject.defaults {
        didSet { save(subjects, key: subjectsKey) }
    }

    @Published var lessons: [Lesson] = [] {
        didSet { save(lessons, key: lessonsKey) }
    }

    private let itemsKey = "studyPlanner.items"
    private let subjectsKey = "studyPlanner.subjects"
    private let lessonsKey = "studyPlanner.lessons"

    init() {
        if let saved: [Assessment] = load(key: itemsKey) {
            items = saved
        }
        if let saved: [Lesson] = load(key: lessonsKey) {
            lessons = saved
        }
        if let saved: [Subject] = load(key: subjectsKey), !saved.isEmpty {
            subjects = saved
        }
        // "Other" must always exist; deleted subjects move there.
        if !subjects.contains(where: { $0.id == Subject.otherID }) {
            subjects.append(Subject.fallback)
        }
        upgradeSubjectsIfNeeded()
    }

    // Runs once to bring older saved subjects up to date
    // with the library's names. Anything renamed by the user is left alone.
    private func upgradeSubjectsIfNeeded() {
        let versionKey = "studyPlanner.subjectsVersion"
        guard UserDefaults.standard.integer(forKey: versionKey) < 2 else { return }

        rename("hass", from: "HASS", to: "Humanities")
        rename("health", from: "Health & PE", to: "HPE")
        for subject in [Subject.religion, Subject.pde] where !hasSubject(subject.id) {
            addSubject(subject)
        }
        UserDefaults.standard.set(2, forKey: versionKey)
    }

    private func rename(_ id: String, from oldName: String, to newName: String) {
        if let i = subjects.firstIndex(where: { $0.id == id && $0.name == oldName }) {
            subjects[i].name = newName
        }
    }

    // ---- Looking things up ----
    func subject(for id: String) -> Subject {
        subjects.first { $0.id == id } ?? Subject.fallback
    }

    func subject(for item: Assessment) -> Subject {
        subject(for: item.subjectID)
    }

    private func index(of id: UUID) -> Int? {
        items.firstIndex { $0.id == id }
    }

    // ---- Assessments ----
    func add(_ item: Assessment) {
        items.append(item)
        refreshExtras(for: item.id)
    }

    func update(_ item: Assessment) {
        guard let i = index(of: item.id) else { return }
        items[i] = item
        refreshExtras(for: item.id)
    }

    func delete(_ item: Assessment) {
        ReminderScheduler.cancel(item)
        CalendarSync.shared.remove(item)
        items.removeAll { $0.id == item.id }
    }

    func toggleCompleted(_ item: Assessment) {
        guard let i = index(of: item.id) else { return }
        items[i].isCompleted.toggle()
        refreshExtras(for: item.id)
    }

    func toggleStep(_ stepID: UUID, in item: Assessment) {
        guard let i = index(of: item.id),
              let s = items[i].steps.firstIndex(where: { $0.id == stepID }) else { return }
        items[i].steps[s].isDone.toggle()
        refreshExtras(for: item.id)
    }

    func addStudyMinutes(_ minutes: Int, to itemID: UUID) {
        guard let i = index(of: itemID) else { return }
        items[i].studyMinutes += minutes
    }

    func clearCompleted() {
        items.filter { $0.isCompleted }.forEach { delete($0) }
    }

    // Updates the reminder and the calendar event for one item.
    private func refreshExtras(for id: UUID) {
        guard let i = index(of: id) else { return }
        let item = items[i]
        ReminderScheduler.schedule(item, subject: subject(for: item))
        syncToCalendar(item)
    }

    func rescheduleAllReminders() {
        items.forEach { ReminderScheduler.schedule($0, subject: subject(for: $0)) }
    }

    // ---- Calendar ----
    func syncToCalendar(_ item: Assessment) {
        guard CalendarSync.shared.isEnabled else { return }
        let eventID = CalendarSync.shared.save(item, subject: subject(for: item))
        if let i = index(of: item.id), items[i].calendarEventID != eventID {
            items[i].calendarEventID = eventID
        }
    }

    func syncAllToCalendar() {
        items.forEach { syncToCalendar($0) }
    }

    func removeAllFromCalendar() {
        for i in items.indices {
            CalendarSync.shared.remove(items[i])
            items[i].calendarEventID = nil
        }
    }

    // ---- Subjects ----
    func hasSubject(_ id: String) -> Bool {
        subjects.contains { $0.id == id }
    }

    // New subjects go just above "Other".
    func addSubject(_ subject: Subject) {
        guard !hasSubject(subject.id) else { return }
        if let otherIndex = subjects.firstIndex(where: { $0.id == Subject.otherID }) {
            subjects.insert(subject, at: otherIndex)
        } else {
            subjects.append(subject)
        }
    }

    func updateSubject(_ subject: Subject) {
        guard let i = subjects.firstIndex(where: { $0.id == subject.id }) else { return }
        subjects[i] = subject
        // Names may have changed, so refresh reminders and events.
        items.filter { $0.subjectID == subject.id }.forEach { refreshExtras(for: $0.id) }
    }

    func deleteSubject(_ subject: Subject) {
        guard subject.id != Subject.otherID else { return }
        for i in items.indices where items[i].subjectID == subject.id {
            items[i].subjectID = Subject.otherID
        }
        for i in lessons.indices where lessons[i].subjectID == subject.id {
            lessons[i].subjectID = Subject.otherID
        }
        subjects.removeAll { $0.id == subject.id }
    }

    func moveSubjects(from source: IndexSet, to destination: Int) {
        subjects.move(fromOffsets: source, toOffset: destination)
    }

    func count(for subject: Subject) -> Int {
        items.filter { $0.subjectID == subject.id }.count
    }

    // ---- Results ----
    func averagePercentage(subjectID: String? = nil) -> Double? {
        items
            .filter { subjectID == nil || $0.subjectID == subjectID }
            .weightedAveragePercentage
    }

    // ---- Backup ----
    func makeBackup() -> BackupFile {
        BackupFile(version: BackupFile.currentVersion,
                   exportedAt: Date(),
                   studentName: UserDefaults.standard.string(forKey: "studentName") ?? "",
                   subjects: subjects,
                   items: items,
                   lessons: lessons)
    }

    // Replaces everything with the backup's contents.
    func restore(from backup: BackupFile) {
        // Clear out the current reminders and calendar events first.
        items.forEach { ReminderScheduler.cancel($0) }
        removeAllFromCalendar()

        var restoredSubjects = backup.subjects.isEmpty ? Subject.defaults : backup.subjects
        if !restoredSubjects.contains(where: { $0.id == Subject.otherID }) {
            restoredSubjects.append(Subject.fallback)
        }
        subjects = restoredSubjects
        lessons = backup.lessons
        items = backup.items.map { item in
            var item = item
            item.calendarEventID = nil   // events are recreated below if sync is on
            return item
        }
        if !backup.studentName.isEmpty {
            UserDefaults.standard.set(backup.studentName, forKey: "studentName")
        }

        rescheduleAllReminders()
        syncAllToCalendar()
    }

    // ---- Timetable ----
    // Lessons for one weekday (2 = Monday … 6 = Friday), earliest first.
    func lessons(on weekday: Int) -> [Lesson] {
        lessons
            .filter { $0.weekday == weekday }
            .sorted { $0.startMinutes < $1.startMinutes }
    }

    func addLesson(_ lesson: Lesson) {
        lessons.append(lesson)
    }

    func updateLesson(_ lesson: Lesson) {
        guard let i = lessons.firstIndex(where: { $0.id == lesson.id }) else { return }
        lessons[i] = lesson
    }

    func deleteLesson(_ lesson: Lesson) {
        lessons.removeAll { $0.id == lesson.id }
    }

    // ---- Demo data ----
    var hasDemoData: Bool {
        items.contains { $0.isDemo } || lessons.contains { $0.isDemo }
    }

    // Adds sample assessments and a week of lessons so a new
    // user can see how everything works. Reminders and Calendar
    // sync are skipped on purpose, so demo items never leak out.
    func loadDemoData() {
        let calendar = Calendar.current
        func day(_ offset: Int) -> Date {
            calendar.date(byAdding: .day, value: offset, to: Date()) ?? Date()
        }
        func id(_ subject: Subject) -> String {
            hasSubject(subject.id) ? subject.id : Subject.otherID
        }

        var algebra = Assessment(title: "Algebra test", type: .exam,
                                 subjectID: id(.maths), dueDate: day(3))
        algebra.reminderDaysBefore = 1
        algebra.notes = "Chapters 4–5: equations and graphs."

        var essay = Assessment(title: "Persuasive essay", type: .assignment,
                               subjectID: id(.english), dueDate: day(6))
        essay.steps = [
            ChecklistStep(text: "Research", isDone: true),
            ChecklistStep(text: "Plan", isDone: true),
            ChecklistStep(text: "Write draft"),
            ChecklistStep(text: "Check and edit"),
            ChecklistStep(text: "Hand in")
        ]

        let quiz = Assessment(title: "Cells quiz", type: .quiz,
                              subjectID: id(.science), dueDate: day(1))

        var mathsQuiz = Assessment(title: "Fractions quiz", type: .quiz,
                                   subjectID: id(.maths), dueDate: day(-5))
        mathsQuiz.isCompleted = true
        mathsQuiz.score = 17
        mathsQuiz.outOf = 20
        mathsQuiz.grade = .b
        mathsQuiz.studyMinutes = 50

        var report = Assessment(title: "Book report", type: .assignment,
                                subjectID: id(.english), dueDate: day(-12))
        report.isCompleted = true
        report.score = 78
        report.outOf = 100
        report.grade = .b

        let demoItems = [algebra, essay, quiz, mathsQuiz, report].map { item -> Assessment in
            var item = item
            item.isDemo = true
            return item
        }
        items.append(contentsOf: demoItems)

        // Four lessons a day, Monday to Friday.
        let slots = [(510, 560), (565, 615), (640, 690), (695, 745)]
        let week: [[Subject]] = [
            [.maths, .english, .science, .hpe],
            [.english, .humanities, .maths, .pde],
            [.science, .maths, .english, .humanities],
            [.hpe, .science, .maths, .english],
            [.humanities, .english, .science, .maths]
        ]
        let teachers: [String: String] = [
            Subject.maths.id: "Ms Patel", Subject.english.id: "Mr Clarke",
            Subject.science.id: "Dr Evans", Subject.humanities.id: "Mrs Nguyen",
            Subject.hpe.id: "Mr Brown", Subject.pde.id: "Ms Lee"
        ]
        var demoLessons: [Lesson] = []
        for (dayIndex, subjects) in week.enumerated() {
            for (slotIndex, subject) in subjects.enumerated() {
                demoLessons.append(Lesson(subjectID: id(subject),
                                          weekday: dayIndex + 2,
                                          startMinutes: slots[slotIndex].0,
                                          endMinutes: slots[slotIndex].1,
                                          room: "R\(slotIndex + 1).0\(dayIndex + 1)",
                                          teacher: teachers[subject.id] ?? "",
                                          isDemo: true))
            }
        }
        lessons.append(contentsOf: demoLessons)
    }

    func removeDemoData() {
        items.filter { $0.isDemo }.forEach { delete($0) }
        lessons.removeAll { $0.isDemo }
    }

    // ---- Saving helpers ----
    private func save<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load<T: Decodable>(key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
