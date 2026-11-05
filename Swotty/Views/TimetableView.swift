import SwiftUI

// MARK: - Weekly timetable editor
// Where the repeating weekly lessons are added and changed.
// Presented as a sheet from the Schedule tab (TimetableEditorSheet),
// or pushed from Settings.
struct TimetableEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TimetableEditorView()
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                            .bold()
                    }
                }
        }
    }
}

struct TimetableEditorView: View {
    @EnvironmentObject private var store: StudyStore

    @AppStorage(ScheduleSettings.showWeekendKey) private var showWeekend = false
    @AppStorage(ScheduleSettings.weekStartKey) private var weekStart = 2

    @State private var weekday = Calendar.current.component(.weekday, from: Date())
    @State private var editingLesson: Lesson? = nil
    @State private var showingAddSheet = false
    @State private var now = Date()

    // Keeps the "Now" badge fresh.
    private let ticker = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private var days: [Int] {
        ScheduleSettings.orderedDays(weekStart: weekStart, showWeekend: showWeekend)
    }

    private func dayName(_ weekday: Int) -> String {
        Calendar.current.shortWeekdaySymbols[weekday - 1]
    }

    private var lessons: [Lesson] {
        store.lessons(on: weekday)
    }

    var body: some View {
        List {
            Section {
                Picker("Day", selection: $weekday) {
                    ForEach(days, id: \.self) { day in
                        Text(dayName(day)).tag(day)
                    }
                }
                .pickerStyle(.segmented)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            if lessons.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        EmptyStateView(icon: "calendar.badge.plus",
                                       title: "No lessons on \(dayName(weekday))",
                                       message: "Add your lessons to build your weekly timetable.")
                        Button("Add a lesson") { showingAddSheet = true }
                            .buttonStyle(BrandButtonStyle())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 12)
                }
                .listRowBackground(Theme.surface)
            } else {
                Section {
                    ForEach(lessons) { lesson in
                        lessonRow(lesson)
                            .contentShape(Rectangle())
                            .onTapGesture { editingLesson = lesson }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    withAnimation { store.deleteLesson(lesson) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                } footer: {
                    Text("Tap a lesson to edit it. Swipe left to delete.")
                }
                .listRowBackground(Theme.surface)
            }
        }
        .listStyle(.insetGrouped)
        .themedList()
        .navigationTitle("Weekly Timetable")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                .accessibilityLabel("Add lesson")
            }
        }
        .onAppear {
            if !days.contains(weekday), let first = days.first {
                weekday = first
            }
        }
        .onReceive(ticker) { now = $0 }
        .sheet(isPresented: $showingAddSheet) {
            LessonEditor(existing: nil,
                         days: days,
                         defaultWeekday: weekday,
                         defaultSubjectID: store.subjects.first?.id ?? Subject.otherID)
                .environmentObject(store)
        }
        .sheet(item: $editingLesson) { lesson in
            LessonEditor(existing: lesson,
                         days: days,
                         defaultWeekday: lesson.weekday,
                         defaultSubjectID: lesson.subjectID)
                .environmentObject(store)
        }
    }

    private func lessonRow(_ lesson: Lesson) -> some View {
        let subject = store.subject(for: lesson.subjectID)
        let isNow = lesson.isOnNow(at: now)

        return HStack(spacing: 12) {
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
        .padding(.vertical, 6)
    }
}

// MARK: - Add / edit a lesson
struct LessonEditor: View {
    @EnvironmentObject private var store: StudyStore
    @Environment(\.dismiss) private var dismiss

    @AppStorage(ScheduleSettings.roundedTimesKey) private var roundedTimes = true

    let existing: Lesson?
    let days: [Int]

    @State private var subjectID: String
    @State private var weekday: Int
    @State private var start: Date
    @State private var end: Date
    @State private var room: String
    @State private var teacher: String
    @State private var repeatDays: Set<Int>
    @State private var confirmingDelete = false

    init(existing: Lesson?, days: [Int], defaultWeekday: Int, defaultSubjectID: String) {
        self.existing = existing
        self.days = days
        _repeatDays = State(initialValue: [existing?.weekday ?? defaultWeekday])
        _subjectID = State(initialValue: existing?.subjectID ?? defaultSubjectID)
        _weekday = State(initialValue: existing?.weekday ?? defaultWeekday)
        _start = State(initialValue: Lesson.date(forMinutes: existing?.startMinutes ?? 540))
        _end = State(initialValue: Lesson.date(forMinutes: existing?.endMinutes ?? 585))
        _room = State(initialValue: existing?.room ?? "")
        _teacher = State(initialValue: existing?.teacher ?? "")
    }

    private var timesAreValid: Bool {
        Lesson.minutes(from: end) > Lesson.minutes(from: start)
    }

    // An existing lesson on a hidden weekend day stays selectable.
    private var dayChoices: [Int] {
        days.contains(weekday) ? days : days + [weekday]
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Lesson") {
                    Picker("Subject", selection: $subjectID) {
                        ForEach(store.subjects) { subject in
                            Label(subject.name, systemImage: subject.icon)
                                .tag(subject.id)
                        }
                    }
                    if existing == nil {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Days")
                            HStack(spacing: 8) {
                                ForEach(days, id: \.self) { day in
                                    dayChip(day)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    } else {
                        Picker("Day", selection: $weekday) {
                            ForEach(dayChoices, id: \.self) { day in
                                Text(Calendar.current.weekdaySymbols[day - 1]).tag(day)
                            }
                        }
                    }
                }
                .listRowBackground(Theme.surface)

                Section {
                    DatePicker("Starts", selection: $start, displayedComponents: .hourAndMinute)
                    DatePicker("Ends", selection: $end, displayedComponents: .hourAndMinute)
                } header: {
                    Text("Time")
                } footer: {
                    if !timesAreValid {
                        Text("The end time must be after the start time.")
                            .foregroundStyle(.red)
                    } else if roundedTimes {
                        Text("Times are rounded to the nearest 5 minutes. Change this in Settings.")
                    }
                }
                .listRowBackground(Theme.surface)

                Section("Details (optional)") {
                    TextField("Room, e.g. R1.02", text: $room)
                    TextField("Teacher", text: $teacher)
                        .textContentType(.name)
                }
                .listRowBackground(Theme.surface)

                if existing != nil {
                    Section {
                        Button("Delete Lesson", role: .destructive) {
                            confirmingDelete = true
                        }
                    }
                    .listRowBackground(Theme.surface)
                }
            }
            .themedList()
            .navigationTitle(existing == nil ? "New Lesson" : "Edit Lesson")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .bold()
                        .disabled(!timesAreValid || (existing == nil && repeatDays.isEmpty))
                }
            }
            .confirmationDialog("Delete this lesson?", isPresented: $confirmingDelete,
                                titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let existing { store.deleteLesson(existing) }
                    dismiss()
                }
            }
        }
    }

    // One tappable day in the "Days" row (new lessons only).
    private func dayChip(_ day: Int) -> some View {
        let isOn = repeatDays.contains(day)
        return Button {
            if isOn {
                repeatDays.remove(day)
            } else {
                repeatDays.insert(day)
            }
        } label: {
            Text(Calendar.current.shortWeekdaySymbols[day - 1])
                .font(.subheadline)
                .bold()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isOn ? AnyShapeStyle(TintShapeStyle()) : AnyShapeStyle(Theme.surfaceRaised))
                .foregroundStyle(isOn ? Theme.onAccent : Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Calendar.current.weekdaySymbols[day - 1])
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func save() {
        var startMinutes = Lesson.minutes(from: start)
        var endMinutes = Lesson.minutes(from: end)
        if roundedTimes {
            startMinutes = ScheduleSettings.rounded(startMinutes)
            endMinutes = ScheduleSettings.rounded(endMinutes)
            if endMinutes <= startMinutes { endMinutes = startMinutes + 5 }
        }
        let roomText = room.trimmingCharacters(in: .whitespaces)
        let teacherText = teacher.trimmingCharacters(in: .whitespaces)

        if var lesson = existing {
            lesson.subjectID = subjectID
            lesson.weekday = weekday
            lesson.startMinutes = startMinutes
            lesson.endMinutes = endMinutes
            lesson.room = roomText
            lesson.teacher = teacherText
            store.updateLesson(lesson)
        } else {
            // A new lesson can repeat on several days at once.
            for day in repeatDays.sorted() {
                store.addLesson(Lesson(subjectID: subjectID, weekday: day,
                                       startMinutes: startMinutes, endMinutes: endMinutes,
                                       room: roomText, teacher: teacherText))
            }
        }
        dismiss()
    }
}
