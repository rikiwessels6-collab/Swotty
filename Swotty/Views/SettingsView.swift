import SwiftUI

// MARK: - Settings tab
struct SettingsView: View {
    @EnvironmentObject private var store: StudyStore

    // @AppStorage saves these automatically.
    @AppStorage("appearance") private var appearance: AppearanceMode = .system
    @AppStorage("reminderHour") private var reminderHour = 16
    @AppStorage("studentName") private var studentName = ""
    @AppStorage("accentColour") private var accent: SubjectColour = .indigo

    @State private var calendarSyncOn = CalendarSync.shared.isEnabled
    @State private var showingAccessDenied = false
    @State private var confirmingSyncOff = false
    @State private var confirmingClear = false
    @State private var confirmingRemoveDemo = false

    private var completedCount: Int {
        store.items.filter { $0.isCompleted }.count
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Your name", text: $studentName)
                        .textContentType(.givenName)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("App colour")
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 40), spacing: 10)], spacing: 10) {
                            ForEach(SubjectColour.allCases) { colour in
                                Circle()
                                    .fill(colour.color)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary, lineWidth: accent == colour ? 3 : 0)
                                            .padding(-4)
                                    )
                                    .onTapGesture { accent = colour }
                                    .accessibilityLabel(colour.rawValue)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Personalise")
                } footer: {
                    Text("Your name appears in the greeting on the Planner.")
                }

                Section {
                    Picker("Theme", selection: $appearance) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("System matches your device's own light or dark setting.")
                }

                Section {
                    NavigationLink {
                        SubjectsListView()
                    } label: {
                        LabeledContent("Subjects", value: "\(store.subjects.count)")
                    }
                }

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
                    Text("Reminders")
                }

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
                } header: {
                    Text("Calendar")
                } footer: {
                    Text("Adds each assessment as an all-day event in a \"\(appName)\" calendar in the Calendar app. Changes here update the calendar automatically.")
                }

                if store.hasDemoData {
                    Section {
                        Button("Remove Demo Data", role: .destructive) {
                            confirmingRemoveDemo = true
                        }
                    } footer: {
                        Text("Removes the sample assessments and lessons added when you started with demo data. Your own entries are kept.")
                    }
                }

                Section {
                    Button("Clear Completed (\(completedCount))", role: .destructive) {
                        confirmingClear = true
                    }
                    .disabled(completedCount == 0)
                } footer: {
                    Text("Permanently removes ticked-off assessments and their results.")
                }

                Section {
                    LabeledContent("App", value: appName)
                    LabeledContent("Version", value: appVersion)
                } header: {
                    Text("About")
                } footer: {
                    Text("Your assessments, results and settings are stored only on this device.")
                }
            }
            .navigationTitle("Settings")
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
