import SwiftUI

// MARK: - Schedule tab
// One place for everything about days and classes. The mode decides how much
// is shown at once; the options sheet (top left) switches mode, filters by
// subject and sets which days appear.
// The raw values are saved in the user's settings, so keep them stable.
enum ScheduleMode: String, CaseIterable, Identifiable {
    case day = "Day"
    case threeDays = "3 Days"
    case week = "Week"
    case month = "Month"

    var id: String { rawValue }
    var title: String { rawValue }
}

struct ScheduleView: View {
    @EnvironmentObject private var store: StudyStore
    @AppStorage("scheduleMode") private var mode: ScheduleMode = .day

    @State private var focusDate = Calendar.current.startOfDay(for: Date())
    @State private var showingOptions = false
    @State private var showingEditor = false
    @State private var openEditorAfterOptions = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(mode.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            showingOptions = true
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                        }
                        .accessibilityLabel("View options")
                    }
                }
                .sheet(isPresented: $showingOptions, onDismiss: {
                    if openEditorAfterOptions {
                        openEditorAfterOptions = false
                        showingEditor = true
                    }
                }) {
                    ScheduleOptionsSheet(mode: $mode, onEditTimetable: {
                        openEditorAfterOptions = true
                        showingOptions = false
                    })
                    .environmentObject(store)
                }
                .sheet(isPresented: $showingEditor) {
                    TimetableEditorSheet()
                        .environmentObject(store)
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .day:
            DayView(day: $focusDate, onEditTimetable: { showingEditor = true })
        case .threeDays:
            AgendaView(span: .threeDays, focusDate: $focusDate,
                       onOpenDay: { mode = .day },
                       onEditTimetable: { showingEditor = true })
        case .week:
            AgendaView(span: .week, focusDate: $focusDate,
                       onOpenDay: { mode = .day },
                       onEditTimetable: { showingEditor = true })
        case .month:
            MonthCalendarView(selectedDay: $focusDate, onOpenDay: { mode = .day })
        }
    }
}

// MARK: - View options
struct ScheduleOptionsSheet: View {
    @EnvironmentObject private var store: StudyStore
    @Environment(\.dismiss) private var dismiss

    @Binding var mode: ScheduleMode
    let onEditTimetable: () -> Void

    @AppStorage(ScheduleSettings.showWeekendKey) private var showWeekend = false
    @AppStorage(ScheduleSettings.weekStartKey) private var weekStart = 2
    @AppStorage(ScheduleSettings.subjectFilterKey) private var subjectFilter = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("View") {
                    Picker("View", selection: $mode) {
                        ForEach(ScheduleMode.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(Theme.surface)

                Section {
                    Picker("Subject", selection: $subjectFilter) {
                        Text("All subjects").tag("")
                        ForEach(store.subjects) { subject in
                            Label(subject.name, systemImage: subject.icon)
                                .tag(subject.id)
                        }
                    }
                } header: {
                    Text("Filter")
                } footer: {
                    Text("Show only one subject's classes, notes and due dates.")
                }
                .listRowBackground(Theme.surface)

                Section("Days") {
                    Toggle("Show the weekend", isOn: $showWeekend)
                    Picker("Week starts on", selection: $weekStart) {
                        ForEach(ScheduleSettings.weekStartChoices, id: \.day) { choice in
                            Text(choice.name).tag(choice.day)
                        }
                    }
                }
                .listRowBackground(Theme.surface)

                Section {
                    Button {
                        onEditTimetable()
                    } label: {
                        Label("Edit weekly timetable", systemImage: "square.and.pencil")
                    }
                }
                .listRowBackground(Theme.surface)
            }
            .themedList()
            .navigationTitle("View Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .bold()
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
