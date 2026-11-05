import SwiftUI

// What the note editor sheet is opened for.
struct NoteTarget: Identifiable {
    let id = UUID()
    var existing: ClassNote? = nil
    var lessonID: UUID? = nil
    var subjectID: String
}

// MARK: - Day view
// One day at a time: the classes from the weekly timetable, the notes
// taken in each class, and anything due that day.
// (The navigation stack and title come from ScheduleView.)
struct DayView: View {
    @EnvironmentObject private var store: StudyStore
    @Binding var day: Date
    let onEditTimetable: () -> Void

    @AppStorage(ScheduleSettings.showWeekendKey) private var showWeekend = false
    @AppStorage(ScheduleSettings.weekStartKey) private var weekStart = 2
    @AppStorage(ScheduleSettings.subjectFilterKey) private var subjectFilter = ""

    @State private var noteTarget: NoteTarget? = nil
    @State private var editingItem: Assessment? = nil
    @State private var showingDatePicker = false
    @State private var showingReview = false
    @State private var now = Date()

    private let ticker = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    private var calendar: Calendar { Calendar.current }

    private var weekday: Int { calendar.component(.weekday, from: day) }
    private var visibleDays: [Int] {
        ScheduleSettings.orderedDays(weekStart: weekStart, showWeekend: showWeekend)
    }
    private var isDayOff: Bool { !visibleDays.contains(weekday) }

    private func matchesFilter(_ subjectID: String) -> Bool {
        subjectFilter.isEmpty || subjectID == subjectFilter
    }

    private var lessons: [Lesson] {
        store.lessons(on: weekday).filter { matchesFilter($0.subjectID) }
    }

    private var dayNotes: [ClassNote] {
        store.notes(on: day).filter { matchesFilter($0.subjectID) }
    }

    private func notes(for lesson: Lesson) -> [ClassNote] {
        dayNotes.filter { $0.lessonID == lesson.id }
    }

    // Notes for this day that aren't tied to one of today's lessons.
    private var otherNotes: [ClassNote] {
        let lessonIDs = Set(lessons.map { $0.id })
        return dayNotes.filter { note in
            guard let lessonID = note.lessonID else { return true }
            return !lessonIDs.contains(lessonID)
        }
    }

    private var dueToday: [Assessment] {
        store.items
            .filter { calendar.isDate($0.dueDate, inSameDayAs: day) && matchesFilter($0.subjectID) }
            .sorted { !$0.isCompleted && $1.isCompleted }
    }

    var body: some View {
        List {
            dateHeader

            if !subjectFilter.isEmpty {
                filterBanner
            }

            if !dueToday.isEmpty {
                Section("Due this day") {
                    ForEach(dueToday) { item in
                        AssessmentRow(item: item, subject: store.subject(for: item)) {
                            withAnimation { store.toggleCompleted(item) }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { editingItem = item }
                    }
                }
                .listRowBackground(Theme.surface)
            }

            if lessons.isEmpty {
                emptyDay
            } else {
                ForEach(lessons) { lesson in
                    lessonSection(lesson)
                }
            }

            otherNotesSection
        }
        .listStyle(.insetGrouped)
        .themedList()
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showingReview = true
                } label: {
                    Image(systemName: "checklist")
                        .overlay(alignment: .topTrailing) {
                            if !store.pendingReviewNotes.isEmpty {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 9, height: 9)
                                    .offset(x: 4, y: -4)
                            }
                        }
                }
                .accessibilityLabel("Notes to review")

                Button {
                    showingDatePicker = true
                } label: {
                    Image(systemName: "calendar")
                }
                .accessibilityLabel("Pick a date")
            }
        }
        .onReceive(ticker) { now = $0 }
        .sheet(item: $noteTarget) { target in
            NoteEditor(target: target, day: day)
                .environmentObject(store)
        }
        .sheet(item: $editingItem) { item in
            AssessmentEditor(existing: item)
                .environmentObject(store)
        }
        .sheet(isPresented: $showingDatePicker) {
            datePickerSheet
        }
        .sheet(isPresented: $showingReview) {
            ReviewNotesView()
                .environmentObject(store)
        }
    }

    // ---- Header with previous / next day ----
    private var dateHeader: some View {
        Section {
            HStack {
                Button {
                    shift(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Previous day")

                Spacer()

                VStack(spacing: 2) {
                    Text(day.formatted(.dateTime.weekday(.wide)))
                        .font(.display(.title2))
                    Text(day.formatted(.dateTime.day().month(.wide).year()))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    shift(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Next day")
            }

            if !calendar.isDateInToday(day) {
                Button("Back to today") {
                    withAnimation { day = calendar.startOfDay(for: Date()) }
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity)
            }
        }
        .listRowBackground(Theme.surface)
    }

    private var filterBanner: some View {
        Section {
            HStack {
                Label("Showing \(store.subject(for: subjectFilter).name) only",
                      systemImage: "line.3.horizontal.decrease.circle.fill")
                    .font(.subheadline)
                Spacer()
                Button("Clear") { subjectFilter = "" }
                    .font(.subheadline)
                    .buttonStyle(.borderless)
            }
        }
        .listRowBackground(Theme.surface)
    }

    private var emptyDay: some View {
        Section {
            VStack(spacing: 12) {
                EmptyStateView(
                    icon: isDayOff ? "moon.zzz.fill" : "calendar.badge.plus",
                    title: emptyTitle,
                    message: emptyMessage)
                if !isDayOff && subjectFilter.isEmpty {
                    Button("Edit timetable") { onEditTimetable() }
                        .buttonStyle(BrandButtonStyle())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 8)
        }
        .listRowBackground(Theme.surface)
    }

    private var emptyTitle: String {
        if isDayOff { return "A day off" }
        if !subjectFilter.isEmpty { return "No \(store.subject(for: subjectFilter).name) classes" }
        return "No classes on this day"
    }

    private var emptyMessage: String {
        if isDayOff { return "Nothing is scheduled. You can still add a note below." }
        if !subjectFilter.isEmpty { return "Clear the subject filter in View Options to see everything." }
        return "Add your lessons to the weekly timetable to see them here."
    }

    // ---- One class and its notes ----
    private func lessonSection(_ lesson: Lesson) -> some View {
        let subject = store.subject(for: lesson.subjectID)
        let isNow = calendar.isDateInToday(day) && lesson.isOnNow(at: now)

        return Section {
            HStack(spacing: 12) {
                Capsule()
                    .fill(subject.color)
                    .frame(width: 5)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(subject.name)
                            .font(.headline)
                        if isNow {
                            Text("Now")
                                .font(.caption2)
                                .bold()
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(subject.color)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                    }
                    if !lesson.details.isEmpty {
                        Text(lesson.details)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(Lesson.label(forMinutes: lesson.startMinutes))
                        .font(.subheadline)
                        .bold()
                    Text(Lesson.label(forMinutes: lesson.endMinutes))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 4)

            ForEach(notes(for: lesson)) { note in
                noteRow(note)
            }

            Button {
                noteTarget = NoteTarget(lessonID: lesson.id, subjectID: lesson.subjectID)
            } label: {
                Label("Add a note", systemImage: "square.and.pencil")
            }
        }
        .listRowBackground(Theme.surface)
    }

    private var otherNotesSection: some View {
        Section {
            ForEach(otherNotes) { note in
                noteRow(note)
            }
            Button {
                noteTarget = NoteTarget(subjectID: subjectFilter.isEmpty
                                        ? (store.subjects.first?.id ?? Subject.otherID)
                                        : subjectFilter)
            } label: {
                Label("Add a note for this day", systemImage: "square.and.pencil")
            }
        } header: {
            Text(lessons.isEmpty && otherNotes.isEmpty ? "Notes" : "Other notes")
        } footer: {
            Text("Mark a note \"needs review\" and it stays in your Review list until you tick it off.")
        }
        .listRowBackground(Theme.surface)
    }

    // ---- A single note ----
    private func noteRow(_ note: ClassNote) -> some View {
        let subject = store.subject(for: note.subjectID)

        return HStack(alignment: .top, spacing: 12) {
            if note.needsReview {
                Button {
                    withAnimation { store.toggleReviewed(note) }
                } label: {
                    Image(systemName: note.isReviewed ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(note.isReviewed ? Theme.emerald : Color.orange)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(note.isReviewed ? "Mark as not reviewed" : "Mark as reviewed")
            } else {
                Image(systemName: "note.text")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(note.text)
                    .font(.body)
                    .foregroundStyle(note.isReviewed ? .secondary : .primary)
                    .strikethrough(note.isReviewed)
                HStack(spacing: 6) {
                    if note.lessonID == nil || !lessons.contains(where: { $0.id == note.lessonID }) {
                        SubjectTag(subject: subject)
                    }
                    if note.needsReview {
                        Text(note.isReviewed ? "Reviewed" : "To review")
                            .font(.caption)
                            .bold()
                            .foregroundStyle(note.isReviewed ? Theme.emerald : Color.orange)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            noteTarget = NoteTarget(existing: note, lessonID: note.lessonID, subjectID: note.subjectID)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                withAnimation { store.deleteNote(note) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var datePickerSheet: some View {
        NavigationStack {
            DatePicker("Day", selection: Binding(
                get: { day },
                set: { day = calendar.startOfDay(for: $0) }
            ), displayedComponents: .date)
            .datePickerStyle(.graphical)
            .padding()
            .navigationTitle("Pick a day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showingDatePicker = false }
                        .bold()
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // Moves to the previous / next day that is shown (skips a hidden weekend).
    private func shift(by days: Int) {
        var target = day
        for _ in 0..<7 {
            target = calendar.date(byAdding: .day, value: days, to: target) ?? target
            if visibleDays.contains(calendar.component(.weekday, from: target)) { break }
        }
        withAnimation { day = calendar.startOfDay(for: target) }
    }
}

// MARK: - Add / edit a note
struct NoteEditor: View {
    @EnvironmentObject private var store: StudyStore
    @Environment(\.dismiss) private var dismiss

    let existing: ClassNote?
    let day: Date
    let lessonID: UUID?

    @State private var subjectID: String
    @State private var text: String
    @State private var needsReview: Bool
    @State private var confirmingDelete = false

    init(target: NoteTarget, day: Date) {
        existing = target.existing
        self.day = target.existing?.date ?? day
        lessonID = target.existing?.lessonID ?? target.lessonID
        _subjectID = State(initialValue: target.existing?.subjectID ?? target.subjectID)
        _text = State(initialValue: target.existing?.text ?? "")
        _needsReview = State(initialValue: target.existing?.needsReview ?? true)
    }

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Day", value: day.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    if lessonID == nil {
                        Picker("Subject", selection: $subjectID) {
                            ForEach(store.subjects) { subject in
                                Label(subject.name, systemImage: subject.icon)
                                    .tag(subject.id)
                            }
                        }
                    } else {
                        LabeledContent("Class", value: store.subject(for: subjectID).name)
                    }
                }
                .listRowBackground(Theme.surface)

                Section("Notes") {
                    TextField("What did you cover? What do you need to go over?",
                              text: $text, axis: .vertical)
                        .lineLimit(5...12)
                }
                .listRowBackground(Theme.surface)

                Section {
                    Toggle("Needs review", isOn: $needsReview)
                } footer: {
                    Text("Notes that need review appear in your Review list until you tick them off.")
                }
                .listRowBackground(Theme.surface)

                if existing != nil {
                    Section {
                        Button("Delete Note", role: .destructive) {
                            confirmingDelete = true
                        }
                    }
                    .listRowBackground(Theme.surface)
                }
            }
            .themedList()
            .navigationTitle(existing == nil ? "New Note" : "Edit Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .bold()
                        .disabled(trimmedText.isEmpty)
                }
            }
            .confirmationDialog("Delete this note?", isPresented: $confirmingDelete,
                                titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let existing { store.deleteNote(existing) }
                    dismiss()
                }
            }
        }
    }

    private func save() {
        var note = existing ?? ClassNote(date: day, subjectID: subjectID,
                                         lessonID: lessonID, text: trimmedText)
        note.subjectID = subjectID
        note.text = trimmedText
        // Changing the review flag starts the review again.
        if let existing, existing.needsReview != needsReview {
            note.isReviewed = false
        }
        note.needsReview = needsReview

        if existing == nil {
            store.addNote(note)
        } else {
            store.updateNote(note)
        }
        dismiss()
    }
}
