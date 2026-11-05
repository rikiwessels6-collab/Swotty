import SwiftUI

// The Schedule tab switches between the day view (classes and notes),
// the weekly timetable, and the month calendar of due dates.
// The raw values are saved in the user's settings, so keep them stable.
enum ScheduleMode: String, CaseIterable, Identifiable {
    case day = "Day"
    case timetable = "Timetable"
    case month = "Month"

    var id: String { rawValue }

    // What the segmented control shows.
    var title: String {
        self == .timetable ? "Week" : rawValue
    }
}

struct ScheduleView: View {
    @AppStorage("scheduleMode") private var mode: ScheduleMode = .day

    var body: some View {
        switch mode {
        case .day:
            DayView(mode: $mode)
        case .timetable:
            TimetableView(mode: $mode)
        case .month:
            MonthCalendarView(mode: $mode)
        }
    }
}

// The Day / Week / Month switch shown in the navigation bar.
struct ScheduleModePicker: View {
    @Binding var mode: ScheduleMode

    var body: some View {
        Picker("View", selection: $mode) {
            ForEach(ScheduleMode.allCases) { option in
                Text(option.title).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 260)
    }
}
