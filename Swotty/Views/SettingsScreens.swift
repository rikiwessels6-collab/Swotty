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
    @AppStorage(ScheduleSettings.showWeekendKey) private var showWeekend = false
    @AppStorage(ScheduleSettings.weekStartKey) private var weekStart = 2
    @AppStorage(ScheduleSettings.roundedTimesKey) private var roundedTimes = true

    var body: some View {
        Form {
            Section {
                Toggle("Show the weekend", isOn: $showWeekend)
                Picker("Week starts on", selection: $weekStart) {
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
        }
        .themedList()
        .navigationTitle("Calendar Sync")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            calendarSyncOn = CalendarSync.shared.isEnabled
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
