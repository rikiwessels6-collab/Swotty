import SwiftUI

// MARK: - Timetable (weekly lessons, Monday to Friday)
struct TimetableView: View {
    @EnvironmentObject private var store: StudyStore
    @Binding var mode: ScheduleMode

    @State private var weekday = TimetableView.initialWeekday()
    @State private var editingLesson: Lesson? = nil
    @State private var showingAddSheet = false
    @State private var now = Date()

    // Keeps the "Now" badge fresh.
    private let ticker = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private static let schoolDays = [2, 3, 4, 5, 6]

    // Today if it's a school day, otherwise Monday.
    private static func initialWeekday() -> Int {
        let today = Calendar.current.component(.weekday, from: Date())
        return schoolDays.contains(today) ? today : 2
    }

    private func dayName(_ weekday: Int) -> String {
        Calendar.current.shortWeekdaySymbols[weekday - 1]
    }

    private var lessons: [Lesson] {
        store.lessons(on: weekday)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Day", selection: $weekday) {
                        ForEach(Self.schoolDays, id: \.self) { day in
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
                                .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 12)
                    }
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
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Timetable")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    ScheduleModePicker(mode: $mode)
                }
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
            .onReceive(ticker) { now = $0 }
            .sheet(isPresented: $showingAddSheet) {
                LessonEditor(existing: nil,
                             defaultWeekday: weekday,
                             defaultSubjectID: store.subjects.first?.id ?? Subject.otherID)
                    .environmentObject(store)
            }
            .sheet(item: $editingLesson) { lesson in
                LessonEditor(existing: lesson,
                             defaultWeekday: lesson.weekday,
                             defaultSubjectID: lesson.subjectID)
                    .environmentObject(store)
            }
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

    let existing: Lesson?

    @State private var subjectID: String
    @State private var weekday: Int
    @State private var start: Date
    @State private var end: Date
    @State private var room: String
    @State private var teacher: String
    @State private var repeatDays: Set<Int>
    @State private var confirmingDelete = false

    init(existing: Lesson?, defaultWeekday: Int, defaultSubjectID: String) {
        self.existing = existing
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
                                ForEach([2, 3, 4, 5, 6], id: \.self) { day in
                                    dayChip(day)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    } else {
                        Picker("Day", selection: $weekday) {
                            ForEach([2, 3, 4, 5, 6], id: \.self) { day in
                                Text(Calendar.current.weekdaySymbols[day - 1]).tag(day)
                            }
                        }
                    }
                }

                Section {
                    DatePicker("Starts", selection: $start, displayedComponents: .hourAndMinute)
                    DatePicker("Ends", selection: $end, displayedComponents: .hourAndMinute)
                } header: {
                    Text("Time")
                } footer: {
                    if !timesAreValid {
                        Text("The end time must be after the start time.")
                            .foregroundStyle(.red)
                    }
                }

                Section("Details (optional)") {
                    TextField("Room, e.g. R1.02", text: $room)
                    TextField("Teacher", text: $teacher)
                        .textContentType(.name)
                }

                if existing != nil {
                    Section {
                        Button("Delete Lesson", role: .destructive) {
                            confirmingDelete = true
                        }
                    }
                }
            }
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
                .background(isOn ? AnyShapeStyle(TintShapeStyle()) : AnyShapeStyle(Color(.tertiarySystemFill)))
                .foregroundStyle(isOn ? Color.white : Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Calendar.current.weekdaySymbols[day - 1])
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func save() {
        let startMinutes = Lesson.minutes(from: start)
        let endMinutes = Lesson.minutes(from: end)
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
