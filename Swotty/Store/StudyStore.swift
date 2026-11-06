import SwiftUI

// MARK: - The store (all data, saved automatically)
final class StudyStore: ObservableObject {
    @Published var items: [Assessment] = [] {
        didSet {
            save(items, key: itemsKey)
            refreshWidget()
        }
    }
    @Published var subjects: [Subject] = Subject.defaults {
        didSet {
            save(subjects, key: subjectsKey)
            refreshWidget()
        }
    }

    @Published var lessons: [Lesson] = [] {
        didSet {
            save(lessons, key: lessonsKey)
            ClassReminders.rescheduleLessons(lessons, subjects: subjects)
            CalendarSync.shared.scheduleTimetableSync(lessons: lessons, subjects: subjects)
            refreshWidget()
        }
    }

    // The school day's bell schedule (Period 1, 2, 3 …). Empty = not using periods.
    @Published var periods: [ClassPeriod] = [] {
        didSet { save(periods, key: periodsKey) }
    }

    @Published var notes: [ClassNote] = [] {
        didSet {
            save(notes, key: notesKey)
            ClassReminders.rescheduleReview(pendingCount: pendingReviewNotes.count)
        }
    }

    private let itemsKey = "studyPlanner.items"
    private let subjectsKey = "studyPlanner.subjects"
    private let lessonsKey = "studyPlanner.lessons"
    private let notesKey = "studyPlanner.notes"
    private let periodsKey = "studyPlanner.periods"
    private var settingsObserver: NSObjectProtocol?

    init() {
        if let saved: [Assessment] = load(key: itemsKey) {
            items = saved
        }
        if let saved: [Lesson] = load(key: lessonsKey) {
            lessons = saved
        }
        if let saved: [ClassNote] = load(key: notesKey) {
            notes = saved
        }
        if let saved: [ClassPeriod] = load(key: periodsKey) {
            periods = saved
        }
        if let saved: [Subject] = load(key: subjectsKey), !saved.isEmpty {
            subjects = saved
        }
        // "Other" must always exist; deleted subjects move there.
        if !subjects.contains(where: { $0.id == Subject.otherID }) {
            subjects.append(Subject.fallback)
        }
        upgradeSubjectsIfNeeded()
        refreshClassReminders()
        CalendarSync.shared.updateTimetableSource(lessons: lessons, subjects: subjects)

        // Which week is A (and the week start) change what the widget shows.
        settingsObserver = NotificationCenter.default.addObserver(
            forName: ScheduleSettings.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refreshWidget()
        }
        refreshWidget()
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

    // The last thing deleted, kept briefly so it can be brought back.
    @Published var recentlyDeleted: Assessment? = nil

    func delete(_ item: Assessment, undoable: Bool = true) {
        ReminderScheduler.cancel(item)
        CalendarSync.shared.remove(item)
        items.removeAll { $0.id == item.id }
        recentlyDeleted = undoable ? item : nil
    }

    func undoDelete() {
        guard let item = recentlyDeleted else { return }
        recentlyDeleted = nil
        add(item)
    }

    func toggleCompleted(_ item: Assessment) {
        guard let i = index(of: item.id) else { return }
        items[i].isCompleted.toggle()
        if items[i].isCompleted { Haptics.success() }
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
        items.filter { $0.isCompleted }.forEach { delete($0, undoable: false) }
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
        ClassReminders.rescheduleReview(pendingCount: pendingReviewNotes.count)
    }

    // Re-plans class and review reminders (after a Settings change).
    func refreshClassReminders() {
        ClassReminders.rescheduleLessons(lessons, subjects: subjects)
        ClassReminders.rescheduleReview(pendingCount: pendingReviewNotes.count)
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
        ClassReminders.rescheduleLessons(lessons, subjects: subjects)
        CalendarSync.shared.scheduleTimetableSync(lessons: lessons, subjects: subjects)
    }

    func deleteSubject(_ subject: Subject) {
        guard subject.id != Subject.otherID else { return }
        for i in items.indices where items[i].subjectID == subject.id {
            items[i].subjectID = Subject.otherID
        }
        for i in lessons.indices where lessons[i].subjectID == subject.id {
            lessons[i].subjectID = Subject.otherID
        }
        for i in notes.indices where notes[i].subjectID == subject.id {
            notes[i].subjectID = Subject.otherID
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
                   lessons: lessons,
                   notes: notes,
                   periods: periods)
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
        periods = backup.periods
        lessons = backup.lessons
        notes = backup.notes
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

    // Lessons on a weekday that run in the given week (nil = every week).
    func lessons(on weekday: Int, week: Int?) -> [Lesson] {
        lessons(on: weekday).filter { $0.runs(inWeek: week) }
    }

    // The lessons happening on a particular date, following Week A / Week B.
    func lessons(onDate date: Date) -> [Lesson] {
        let weekday = Calendar.current.component(.weekday, from: date)
        return lessons(on: weekday, week: ScheduleSettings.weekType(on: date))
    }

    // Copies every lesson that runs only in one week into the other week,
    // replacing whatever was only in the other week. "Every week" lessons are untouched.
    func copyWeek(from source: Int, to target: Int) {
        guard source != target, (1...2).contains(source), (1...2).contains(target) else { return }
        let copies = lessons.filter { $0.week == source }.map { lesson -> Lesson in
            var copy = lesson
            copy.id = UUID()
            copy.week = target
            copy.isDemo = false
            return copy
        }
        lessons.removeAll { $0.week == target }
        lessons.append(contentsOf: copies)
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

    // ---- Class notes ----
    // Notes taken on one day (any time that day).
    func notes(on day: Date) -> [ClassNote] {
        notes
            .filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
            .sorted { !$0.isReviewed && $1.isReviewed }
    }

    // Flagged for review and not ticked off yet, newest class first.
    var pendingReviewNotes: [ClassNote] {
        notes.filter { $0.isPendingReview }.sorted { $0.date > $1.date }
    }

    var reviewedNotes: [ClassNote] {
        notes.filter { $0.needsReview && $0.isReviewed }.sorted { $0.date > $1.date }
    }

    func addNote(_ note: ClassNote) {
        notes.append(note)
    }

    func updateNote(_ note: ClassNote) {
        guard let i = notes.firstIndex(where: { $0.id == note.id }) else { return }
        notes[i] = note
    }

    func deleteNote(_ note: ClassNote) {
        notes.removeAll { $0.id == note.id }
    }

    func toggleReviewed(_ note: ClassNote) {
        guard let i = notes.firstIndex(where: { $0.id == note.id }) else { return }
        notes[i].isReviewed.toggle()
    }

    // ---- Class periods ----
    func period(number: Int) -> ClassPeriod? {
        periods.first { $0.number == number }
    }

    // Saves the bell schedule and keeps lessons in step: a lesson in a period
    // takes that period's times, and loses its period if the period was removed.
    func setPeriods(_ newPeriods: [ClassPeriod]) {
        let sorted = newPeriods.sorted { $0.number < $1.number }
        periods = sorted
        var changed = lessons
        var didChange = false
        for index in changed.indices where changed[index].period > 0 {
            if let period = sorted.first(where: { $0.number == changed[index].period }) {
                if changed[index].startMinutes != period.startMinutes || changed[index].endMinutes != period.endMinutes {
                    changed[index].startMinutes = period.startMinutes
                    changed[index].endMinutes = period.endMinutes
                    didChange = true
                }
            } else {
                changed[index].period = 0
                didChange = true
            }
        }
        if didChange { lessons = changed }
    }

    // ---- Widget ----
    func makeWidgetSnapshot() -> WidgetSnapshot {
        let defaults = UserDefaults.standard
        let snapshotLessons = lessons.map { lesson -> SnapshotLesson in
            let info = self.subject(for: lesson.subjectID)
            return SnapshotLesson(id: lesson.id.uuidString,
                                  subjectName: info.name,
                                  colorHex: info.colour.hex,
                                  weekday: lesson.weekday,
                                  startMinutes: lesson.startMinutes,
                                  endMinutes: lesson.endMinutes,
                                  room: lesson.room,
                                  teacher: lesson.teacher,
                                  week: lesson.week,
                                  period: lesson.period)
        }
        let earliest = Calendar.current.date(byAdding: .day, value: -7, to: Calendar.current.startOfDay(for: Date())) ?? Date()
        let snapshotTasks = items
            .filter { !$0.isCompleted && $0.dueDate >= earliest }
            .sorted { $0.dueDate < $1.dueDate }
            .prefix(40)
            .map { item -> SnapshotTask in
                let info = self.subject(for: item.subjectID)
                return SnapshotTask(id: item.id.uuidString, title: item.title,
                                    subjectName: info.name, colorHex: info.colour.hex,
                                    typeName: item.type.rawValue, dueDate: item.dueDate)
            }
        return WidgetSnapshot(generatedAt: Date(),
                              lessons: snapshotLessons,
                              tasks: Array(snapshotTasks),
                              twoWeek: defaults.integer(forKey: ScheduleSettings.weeksKey) == 2,
                              weekAAnchor: defaults.double(forKey: ScheduleSettings.weekAAnchorKey),
                              weekStart: (defaults.object(forKey: ScheduleSettings.weekStartKey) as? Int) ?? 2,
                              showWeekend: defaults.bool(forKey: ScheduleSettings.showWeekendKey))
    }

    // Sends the latest timetable and tasks to the widget (a moment from now,
    // so a burst of edits becomes one update).
    func refreshWidget(immediately: Bool = false) {
        let snapshot = makeWidgetSnapshot()
        if immediately {
            WidgetSync.flush(snapshot)
        } else {
            WidgetSync.schedule(snapshot)
        }
    }

    // ---- Demo data ----
    var hasDemoData: Bool {
        items.contains { $0.isDemo } || lessons.contains { $0.isDemo } || notes.contains { $0.isDemo }
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

        // A couple of class notes on the most recent school day.
        var noteDay = calendar.startOfDay(for: Date())
        while !(2...6).contains(calendar.component(.weekday, from: noteDay)) {
            noteDay = calendar.date(byAdding: .day, value: -1, to: noteDay) ?? noteDay
        }
        let noteWeekday = calendar.component(.weekday, from: noteDay)
        let dayLessons = demoLessons
            .filter { $0.weekday == noteWeekday }
            .sorted { $0.startMinutes < $1.startMinutes }
        let sampleText = [
            "Go over the worked examples from class and redo questions 4–8.",
            "Reread the chapter and write three questions to ask next lesson."
        ]
        var demoNotes: [ClassNote] = []
        for (lesson, text) in zip(dayLessons.prefix(2), sampleText) {
            var note = ClassNote(date: noteDay, subjectID: lesson.subjectID,
                                 lessonID: lesson.id, text: text, needsReview: true)
            note.isDemo = true
            demoNotes.append(note)
        }
        notes.append(contentsOf: demoNotes)
    }

    func removeDemoData() {
        items.filter { $0.isDemo }.forEach { delete($0) }
        lessons.removeAll { $0.isDemo }
        notes.removeAll { $0.isDemo }
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
