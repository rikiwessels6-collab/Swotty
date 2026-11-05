import SwiftUI

// MARK: - The store (all data, saved automatically)
final class StudyStore: ObservableObject {
    @Published var items: [Assessment] = [] {
        didSet { save(items, key: itemsKey) }
    }
    @Published var subjects: [Subject] = Subject.defaults {
        didSet { save(subjects, key: subjectsKey) }
    }

    private let itemsKey = "studyPlanner.items"
    private let subjectsKey = "studyPlanner.subjects"

    init() {
        if let saved: [Assessment] = load(key: itemsKey) {
            items = saved
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
        let marks = items
            .filter { subjectID == nil || $0.subjectID == subjectID }
            .compactMap { $0.percentage }
        guard !marks.isEmpty else { return nil }
        return marks.reduce(0, +) / Double(marks.count)
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
