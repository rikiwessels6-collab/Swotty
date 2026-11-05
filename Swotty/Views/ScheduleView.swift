import SwiftUI

// The Schedule tab switches between the weekly timetable
// and the month calendar of due dates.
enum ScheduleMode: String, CaseIterable, Identifiable {
    case timetable = "Timetable"
    case month = "Month"

    var id: String { rawValue }
}

struct ScheduleView: View {
    @AppStorage("scheduleMode") private var mode: ScheduleMode = .timetable

    var body: some View {
        switch mode {
        case .timetable:
            TimetableView(mode: $mode)
        case .month:
            MonthCalendarView(mode: $mode)
        }
    }
}

// The Timetable / Month switch shown in the navigation bar.
struct ScheduleModePicker: View {
    @Binding var mode: ScheduleMode

    var body: some View {
        Picker("View", selection: $mode) {
            ForEach(ScheduleMode.allCases) { option in
                Text(option.rawValue).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 220)
    }
}
