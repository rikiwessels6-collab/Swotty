import SwiftUI

// MARK: - Appearance
struct AppearanceSettingsView: View {
    @AppStorage("appearance") private var appearance: AppearanceMode = .dark
    @AppStorage("accentColour") private var accent: SubjectColour = .gold

    var body: some View {
        Form {
            Section {
                Picker("Theme", selection: $appearance) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Theme")
            } footer: {
                Text("System matches your device's own light or dark setting.")
            }
            .listRowBackground(Theme.surface)

            Section {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 12)], spacing: 12) {
                    ForEach(SubjectColour.allCases) { colour in
                        Circle()
                            .fill(colour.color)
                            .frame(width: 34, height: 34)
                            .overlay(
                                Circle()
                                    .stroke(Color.primary, lineWidth: accent == colour ? 3 : 0)
                                    .padding(-4)
                            )
                            .onTapGesture { accent = colour }
                            .accessibilityLabel(colour.rawValue.capitalized)
                    }
                }
                .padding(.vertical, 6)
            } header: {
                Text("Accent colour")
            } footer: {
                Text("Used for buttons, switches and highlights. Gold is the default.")
            }
            .listRowBackground(Theme.surface)
        }
        .themedList()
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Timetable & days
struct ScheduleSettingsView: View {
    @EnvironmentObject private var store: StudyStore
    @AppStorage(ScheduleSettings.showWeekendKey) private var showWeekend = false
    @AppStorage(ScheduleSettings.weekStartKey) private var weekStart = 2
    @AppStorage(ScheduleSettings.roundedTimesKey) private var roundedTimes = true
    @AppStorage(ScheduleSettings.weeksKey) private var timetableWeeks = 1
    @AppStorage(ScheduleSettings.weekAAnchorKey) private var weekAAnchor: Double = 0

    // Which week today falls in, for the "This week is" picker.
    private var currentWeekType: Int {
        ScheduleSettings.weekType(for: Date(), anchor: weekAAnchor, weekStart: weekStart)
    }

    var body: some View {
        Form {
            Section {
                Picker("Timetable repeats", selection: Binding(
                    get: { timetableWeeks },
                    set: { ScheduleSettings.setTimetableWeeks($0) }
                )) {
                    Text("Every week").tag(1)
                    Text("Week A & Week B").tag(2)
                }
                if timetableWeeks == 2 {
                    Picker("This week is", selection: Binding(
                        get: { currentWeekType },
                        set: { ScheduleSettings.setCurrentWeekType($0) }
                    )) {
                        Text("Week A").tag(1)
                        Text("Week B").tag(2)
                    }
                    .pickerStyle(.segmented)
                }
            } header: {
                Text("Weeks")
            } footer: {
                if timetableWeeks == 2 {
                    Text("Weeks alternate every calendar week. If your school skips the rotation over a holiday, change \"This week is\" to match. Lessons can run in Week A, Week B or every week.")
                } else {
                    Text("Choose Week A & Week B if your timetable is different every second week.")
                }
            }
            .listRowBackground(Theme.surface)

            Section {
                Toggle("Show the weekend", isOn: $showWeekend)
                Picker("Week starts on", selection: Binding(
                    get: { weekStart },
                    set: { ScheduleSettings.setWeekStart($0) }
                )) {
                    ForEach(ScheduleSettings.weekStartChoices, id: \.day) { choice in
                        Text(choice.name).tag(choice.day)
                    }
                }
            } header: {
                Text("Days")
            } footer: {
                Text("Choose which days appear in the Schedule and the weekly timetable.")
            }
            .listRowBackground(Theme.surface)

            Section {
                Toggle("Round class times", isOn: $roundedTimes)
            } footer: {
                Text("Class times snap to the nearest 5 minutes, e.g. 9:10 am, 9:15 am, 9:20 am.")
            }
            .listRowBackground(Theme.surface)

            Section {
                NavigationLink {
                    PeriodsSettingsView()
                } label: {
                    HStack {
                        Label("Class periods", systemImage: "list.number")
                        Spacer()
                        Text(store.periods.isEmpty ? "Off" : "\(store.periods.count) periods")
                            .foregroundStyle(.secondary)
                    }
                }
                NavigationLink {
                    TimetableEditorView()
                } label: {
                    Label("Edit weekly timetable", systemImage: "square.and.pencil")
                }
            }
            .listRowBackground(Theme.surface)
        }
        .themedList()
        .navigationTitle("Timetable & Days")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Reminders
struct ReminderSettingsView: View {
    @EnvironmentObject private var store: StudyStore

    @AppStorage("reminderHour") private var reminderHour = 16
    @AppStorage("classRemindersEnabled") private var classRemindersOn = false
    @AppStorage("classReminderMinutes") private var classReminderMinutes = 10
    @AppStorage("reviewRemindersEnabled") private var reviewRemindersOn = false
    @AppStorage(StudyReminders.revisionKey) private var revisionRemindersOn = false
    @AppStorage(StudyReminders.summaryKey) private var weeklySummaryOn = false

    var body: some View {
        Form {
            Section {
                // A custom Binding so existing reminders move
                // to the new time straight away.
                Picker("Reminder time", selection: Binding(
                    get: { reminderHour },
                    set: { newHour in
                        reminderHour = newHour
                        store.rescheduleAllReminders()
                    }
                )) {
                    ForEach(6...21, id: \.self) { hour in
                        Text(ReminderScheduler.label(forHour: hour)).tag(hour)
                    }
                }
            } header: {
                Text("Assessments")
            } footer: {
                Text("Reminders for exams, assignments and quizzes arrive at this time.")
            }
            .listRowBackground(Theme.surface)

            Section {
                Toggle("Before each class", isOn: Binding(
                    get: { classRemindersOn },
                    set: { newValue in
                        classRemindersOn = newValue
                        store.refreshClassReminders()
                    }
                ))
                if classRemindersOn {
                    Picker("How early", selection: Binding(
                        get: { classReminderMinutes },
                        set: { newValue in
                            classReminderMinutes = newValue
                            store.refreshClassReminders()
                        }
                    )) {
                        ForEach([5, 10, 15, 30], id: \.self) { minutes in
                            Text("\(minutes) minutes").tag(minutes)
                        }
                    }
                }
                Toggle("Notes to review", isOn: Binding(
                    get: { reviewRemindersOn },
                    set: { newValue in
                        reviewRemindersOn = newValue
                        store.refreshClassReminders()
                    }
                ))
            } header: {
                Text("Classes")
            } footer: {
                Text("Class reminders repeat every week using your timetable. The notes reminder arrives at your reminder time while you have notes waiting to be reviewed.")
            }
            .listRowBackground(Theme.surface)

            Section {
                Toggle("Revision reminders", isOn: Binding(
                    get: { revisionRemindersOn },
                    set: { newValue in
                        revisionRemindersOn = newValue
                        store.refreshClassReminders()
                    }
                ))
                Toggle("Sunday week-ahead summary", isOn: Binding(
                    get: { weeklySummaryOn },
                    set: { newValue in
                        weeklySummaryOn = newValue
                        store.refreshClassReminders()
                    }
                ))
            } header: {
                Text("Study")
            } footer: {
                Text("Revision reminders arrive at your reminder time a week, three days and one day before each exam. The summary arrives on Sunday at 6:00 pm and lists what is due in the coming week.")
            }
            .listRowBackground(Theme.surface)
        }
        .themedList()
        .navigationTitle("Reminders")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Calendar sync
struct CalendarSettingsView: View {
    @EnvironmentObject private var store: StudyStore

    @State private var calendarSyncOn = CalendarSync.shared.isEnabled
    @State private var showingAccessDenied = false
    @State private var confirmingSyncOff = false
    @State private var timetableOn = CalendarSync.shared.timetableEnabled
    @State private var timetableUntil = CalendarSync.shared.timetableUntil
    @State private var confirmingTimetableOff = false

    var body: some View {
        Form {
            Section {
                Toggle("Sync to Calendar", isOn: Binding(
                    get: { calendarSyncOn },
                    set: { turnOn in
                        if turnOn {
                            enableCalendarSync()
                        } else {
                            confirmingSyncOff = true
                        }
                    }
                ))
                if calendarSyncOn {
                    Button("Sync Now") {
                        store.syncAllToCalendar()
                    }
                }
            } footer: {
                Text("Adds each assessment as an all-day event in a \"\(appName)\" calendar in the Calendar app. Changes here update the calendar automatically.")
            }
            .listRowBackground(Theme.surface)

            Section {
                Toggle("Add timetable to Calendar", isOn: Binding(
                    get: { timetableOn },
                    set: { turnOn in
                        if turnOn {
                            enableTimetableSync()
                        } else {
                            confirmingTimetableOff = true
                        }
                    }
                ))
                if timetableOn {
                    DatePicker("Repeat until", selection: Binding(
                        get: { timetableUntil },
                        set: { newDate in
                            timetableUntil = newDate
                            CalendarSync.shared.setTimetableUntil(newDate)
                            CalendarSync.shared.scheduleTimetableSync()
                        }
                    ), in: Date()..., displayedComponents: .date)
                    Button("Sync Now") {
                        CalendarSync.shared.updateTimetableSource(lessons: store.lessons, subjects: store.subjects)
                        CalendarSync.shared.syncTimetableNow()
                    }
                }
            } header: {
                Text("Timetable")
            } footer: {
                Text("Adds every class as a repeating event in a \"\(CalendarSync.timetableCalendarTitle)\" calendar, so your whole timetable shows in the Calendar app. Week A and Week B lessons repeat every second week. It stays up to date as you change lessons, and the Swotty widget uses it too. Pick the last day of term for \"Repeat until\".")
            }
            .listRowBackground(Theme.surface)
        }
        .themedList()
        .navigationTitle("Calendar Sync")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            calendarSyncOn = CalendarSync.shared.isEnabled
            timetableOn = CalendarSync.shared.timetableEnabled
            timetableUntil = CalendarSync.shared.timetableUntil
        }
        .alert("Calendar access is off", isPresented: $showingAccessDenied) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("To sync, open the Settings app, choose Privacy & Security > Calendars, and allow full access for this app.")
        }
        .confirmationDialog("Stop syncing to Calendar?", isPresented: $confirmingSyncOff,
                            titleVisibility: .visible) {
            Button("Stop and Remove Events", role: .destructive) {
                store.removeAllFromCalendar()
                CalendarSync.shared.setEnabled(false)
                calendarSyncOn = false
            }
            Button("Stop but Keep Events") {
                CalendarSync.shared.setEnabled(false)
                calendarSyncOn = false
            }
        }
        .confirmationDialog("Stop adding the timetable to Calendar?", isPresented: $confirmingTimetableOff,
                            titleVisibility: .visible) {
            Button("Stop and Remove Timetable Events", role: .destructive) {
                CalendarSync.shared.setTimetableEnabled(false)
                CalendarSync.shared.removeTimetableEvents(deleteCalendar: true)
                timetableOn = false
            }
            Button("Stop but Keep Events") {
                CalendarSync.shared.setTimetableEnabled(false)
                timetableOn = false
            }
        }
    }

    private func enableTimetableSync() {
        CalendarSync.shared.requestAccess { granted in
            if granted {
                CalendarSync.shared.setTimetableEnabled(true)
                CalendarSync.shared.setTimetableUntil(timetableUntil)
                CalendarSync.shared.updateTimetableSource(lessons: store.lessons, subjects: store.subjects)
                timetableOn = true
                CalendarSync.shared.syncTimetableNow()
            } else {
                timetableOn = false
                showingAccessDenied = true
            }
        }
    }

    private func enableCalendarSync() {
        CalendarSync.shared.requestAccess { granted in
            if granted {
                CalendarSync.shared.setEnabled(true)
                calendarSyncOn = true
                store.syncAllToCalendar()
            } else {
                calendarSyncOn = false
                showingAccessDenied = true
            }
        }
    }
}

// MARK: - Backup
struct BackupSettingsView: View {
    var body: some View {
        Form {
            BackupSection()
        }
        .themedList()
        .navigationTitle("Backup & Restore")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Manage data
struct DataSettingsView: View {
    @EnvironmentObject private var store: StudyStore

    @State private var confirmingClear = false
    @State private var confirmingRemoveDemo = false

    private var completedCount: Int {
        store.items.filter { $0.isCompleted }.count
    }

    var body: some View {
        Form {
            if store.hasDemoData {
                Section {
                    Button("Remove Demo Data", role: .destructive) {
                        confirmingRemoveDemo = true
                    }
                } footer: {
                    Text("Removes the sample assessments, lessons and notes added when you started with demo data. Your own entries are kept.")
                }
                .listRowBackground(Theme.surface)
            }

            Section {
                Button("Clear Completed (\(completedCount))", role: .destructive) {
                    confirmingClear = true
                }
                .disabled(completedCount == 0)
            } footer: {
                Text("Permanently removes ticked-off assessments and their results.")
            }
            .listRowBackground(Theme.surface)
        }
        .themedList()
        .navigationTitle("Manage Data")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Remove the demo data?",
                            isPresented: $confirmingRemoveDemo,
                            titleVisibility: .visible) {
            Button("Remove Demo Data", role: .destructive) {
                withAnimation { store.removeDemoData() }
            }
        }
        .confirmationDialog("Clear \(completedCount) completed assessments?",
                            isPresented: $confirmingClear,
                            titleVisibility: .visible) {
            Button("Clear Completed", role: .destructive) {
                withAnimation { store.clearCompleted() }
            }
        }
    }
}

// MARK: - About
struct AboutView: View {
    var body: some View {
        Form {
            Section {
                LabeledContent("App", value: appName)
                LabeledContent("Version", value: appVersion)
            } footer: {
                Text("Your assessments, results, notes and settings are stored only on this device. Use Backup & Restore to keep a copy.")
            }
            .listRowBackground(Theme.surface)
        }
        .themedList()
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Class periods
// Set up the school day's bell times once (Period 1, 2, 3 …). Lessons placed in a
// period take its times, and follow along if the times change.
struct PeriodsSettingsView: View {
    @EnvironmentObject private var store: StudyStore

    @State private var firstStart = Lesson.date(forMinutes: 8 * 60)
    @State private var length = 45
    @State private var gap = 5
    @State private var count = 6
    @State private var confirmingCreate = false

    var body: some View {
        Form {
            Section {
                DatePicker("First period starts", selection: $firstStart, displayedComponents: .hourAndMinute)
                Stepper("Lesson length: \(length) min", value: $length, in: 20...120, step: 5)
                Stepper("Break between: \(gap) min", value: $gap, in: 0...60, step: 5)
                Stepper("Number of periods: \(count)", value: $count, in: 1...12)
                Button(store.periods.isEmpty ? "Create periods" : "Replace with these periods") {
                    if store.periods.isEmpty {
                        createPeriods()
                    } else {
                        confirmingCreate = true
                    }
                }
            } header: {
                Text("Quick set-up")
            } footer: {
                Text("Creates evenly spaced periods, for example 8:00–8:45, 8:50–9:35 and so on. You can adjust each one below.")
            }
            .listRowBackground(Theme.surface)

            Section {
                if store.periods.isEmpty {
                    Text("No periods yet")
                        .foregroundStyle(.secondary)
                }
                ForEach(store.periods) { period in
                    HStack(spacing: 8) {
                        Text("Period \(period.number)")
                            .font(.headline)
                        Spacer()
                        DatePicker("Start", selection: timeBinding(for: period, start: true),
                                   displayedComponents: .hourAndMinute)
                            .labelsHidden()
                        Text("–")
                        DatePicker("End", selection: timeBinding(for: period, start: false),
                                   displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                }
                .onDelete { offsets in
                    let remove = Set(offsets.map { store.periods[$0].id })
                    store.setPeriods(store.periods.filter { !remove.contains($0.id) })
                }

                Button {
                    addPeriod()
                } label: {
                    Label("Add a period", systemImage: "plus.circle.fill")
                }
            } header: {
                Text("Periods")
            } footer: {
                Text("When you add a lesson, pick its period and its times follow. If the school changes its bell times, change them here and every lesson updates. Swipe a period to delete it; lessons in it keep their times.")
            }
            .listRowBackground(Theme.surface)
        }
        .themedList()
        .navigationTitle("Class Periods")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Replace the current periods?", isPresented: $confirmingCreate,
                            titleVisibility: .visible) {
            Button("Replace", role: .destructive) { createPeriods() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Lessons keep their times, but ones in a period that no longer exists are set to a custom time.")
        }
    }

    private func createPeriods() {
        store.setPeriods(ClassPeriod.generate(firstStart: Lesson.minutes(from: firstStart),
                                              length: length, gap: gap, count: count))
    }

    private func addPeriod() {
        let nextNumber = (store.periods.map { $0.number }.max() ?? 0) + 1
        let start = (store.periods.map { $0.endMinutes }.max() ?? Lesson.minutes(from: firstStart)) + gap
        let end = min(start + length, 24 * 60 - 1)
        store.setPeriods(store.periods + [ClassPeriod(number: nextNumber, startMinutes: min(start, end - 1), endMinutes: end)])
    }

    // Reads and writes one period's start or end time through the store.
    private func timeBinding(for period: ClassPeriod, start: Bool) -> Binding<Date> {
        Binding(
            get: {
                let current = store.periods.first { $0.id == period.id } ?? period
                return Lesson.date(forMinutes: start ? current.startMinutes : current.endMinutes)
            },
            set: { newDate in
                var all = store.periods
                guard let index = all.firstIndex(where: { $0.id == period.id }) else { return }
                let minutes = Lesson.minutes(from: newDate)
                if start {
                    all[index].startMinutes = minutes
                } else {
                    all[index].endMinutes = minutes
                }
                store.setPeriods(all)
            }
        )
    }
}
