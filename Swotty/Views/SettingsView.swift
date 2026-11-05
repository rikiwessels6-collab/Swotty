import SwiftUI

// MARK: - Settings tab
// A short, grouped home screen. Each row opens a focused screen.
struct SettingsView: View {
    @EnvironmentObject private var store: StudyStore
    @AppStorage("studentName") private var studentName = ""
    @AppStorage("classRemindersEnabled") private var classRemindersOn = false
    @AppStorage("reviewRemindersEnabled") private var reviewRemindersOn = false

    private var remindersSummary: String {
        classRemindersOn || reviewRemindersOn ? "On" : "Off"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Theme.onAccent)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(Theme.gold))
                        TextField("Your name", text: $studentName)
                            .textContentType(.givenName)
                            .font(.display(.title3))
                    }
                    .padding(.vertical, 4)
                } footer: {
                    Text("Your name appears in the greeting on the Planner.")
                }
                .listRowBackground(Theme.surface)

                Section("Study") {
                    NavigationLink {
                        SubjectsListView()
                    } label: {
                        SettingsRow(icon: "books.vertical.fill", tint: Theme.emerald,
                                    title: "Subjects", detail: "\(store.subjects.count)")
                    }
                    NavigationLink {
                        ScheduleSettingsView()
                    } label: {
                        SettingsRow(icon: "calendar.badge.clock", tint: Color(hex: 0x4C7DDB),
                                    title: "Timetable & Days")
                    }
                    NavigationLink {
                        ReminderSettingsView()
                    } label: {
                        SettingsRow(icon: "bell.badge.fill", tint: Color(hex: 0xD1495B),
                                    title: "Reminders", detail: remindersSummary)
                    }
                }
                .listRowBackground(Theme.surface)

                Section("Sync & Backup") {
                    NavigationLink {
                        CalendarSettingsView()
                    } label: {
                        SettingsRow(icon: "calendar", tint: Color(hex: 0xE08E45),
                                    title: "Calendar Sync")
                    }
                    NavigationLink {
                        BackupSettingsView()
                    } label: {
                        SettingsRow(icon: "externaldrive.fill.badge.timemachine", tint: Color(hex: 0x6B63D6),
                                    title: "Backup & Restore")
                    }
                }
                .listRowBackground(Theme.surface)

                Section("Look & Feel") {
                    NavigationLink {
                        AppearanceSettingsView()
                    } label: {
                        SettingsRow(icon: "paintpalette.fill", tint: Theme.gold,
                                    title: "Appearance")
                    }
                }
                .listRowBackground(Theme.surface)

                Section("Data") {
                    NavigationLink {
                        DataSettingsView()
                    } label: {
                        SettingsRow(icon: "tray.full.fill", tint: Color(hex: 0x2A9DA8),
                                    title: "Manage Data")
                    }
                }
                .listRowBackground(Theme.surface)

                Section {
                    NavigationLink {
                        AboutView()
                    } label: {
                        SettingsRow(icon: "info.circle.fill", tint: Color(hex: 0x8591A5),
                                    title: "About \(appName)", detail: appVersion)
                    }
                }
                .listRowBackground(Theme.surface)
            }
            .listStyle(.insetGrouped)
            .themedList()
            .navigationTitle("Settings")
        }
    }
}

// A settings row: a coloured icon tile, the title, and an optional detail.
struct SettingsRow: View {
    let icon: String
    let tint: Color
    let title: String
    var detail: String? = nil

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(tint.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(title)
            Spacer()
            if let detail {
                Text(detail)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
