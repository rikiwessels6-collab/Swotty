import SwiftUI

// MARK: - 3-day and week views
// A calm agenda: each day as a section with its classes, due dates and
// how many notes were taken. Tap anything to open that day.
struct AgendaView: View {
    enum Span {
        case threeDays
        case week
    }

    @EnvironmentObject private var store: StudyStore
    let span: Span
    @Binding var focusDate: Date
    let onOpenDay: () -> Void
    let onEditTimetable: () -> Void

    @AppStorage(ScheduleSettings.showWeekendKey) private var showWeekend = false
    @AppStorage(ScheduleSettings.weekStartKey) private var weekStart = 2
    @AppStorage(ScheduleSettings.subjectFilterKey) private var subjectFilter = ""
    @AppStorage(ScheduleSettings.weeksKey) private var timetableWeeks = 1
    @AppStorage(ScheduleSettings.weekAAnchorKey) private var weekAAnchor: Double = 0

    // Week A or B for a date (nil when the timetable is the same every week).
    private func weekType(for date: Date) -> Int? {
        timetableWeeks == 2
            ? ScheduleSettings.weekType(for: date, anchor: weekAAnchor, weekStart: weekStart)
            : nil
    }

    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = weekStart
        return calendar
    }

    private var visibleDays: [Int] {
        ScheduleSettings.orderedDays(weekStart: weekStart, showWeekend: showWeekend)
    }

    private func matches(_ subjectID: String) -> Bool {
        subjectFilter.isEmpty || subjectID == subjectFilter
    }

    // The dates on screen.
    private var dates: [Date] {
        switch span {
        case .threeDays:
            var result: [Date] = []
            var date = calendar.startOfDay(for: focusDate)
            var attempts = 0
            while result.count < 3 && attempts < 14 {
                if visibleDays.contains(calendar.component(.weekday, from: date)) {
                    result.append(date)
                }
                date = calendar.date(byAdding: .day, value: 1, to: date) ?? date.addingTimeInterval(86_400)
                attempts += 1
            }
            return result
        case .week:
            let start = calendar.dateInterval(of: .weekOfYear, for: focusDate)?.start
                ?? calendar.startOfDay(for: focusDate)
            return (0..<7)
                .compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
                .filter { visibleDays.contains(calendar.component(.weekday, from: $0)) }
        }
    }

    private var rangeLabel: String {
        guard let first = dates.first, let last = dates.last else { return "" }
        if calendar.isDate(first, inSameDayAs: last) {
            return first.formatted(.dateTime.day().month(.wide))
        }
        let start = first.formatted(.dateTime.day().month(.abbreviated))
        let end = last.formatted(.dateTime.day().month(.abbreviated))
        return "\(start) – \(end)"
    }

    var body: some View {
        List {
            navigationHeader

            ForEach(dates, id: \.self) { date in
                daySection(date)
            }
        }
        .listStyle(.insetGrouped)
        .themedList()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    onEditTimetable()
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .accessibilityLabel("Edit weekly timetable")
            }
        }
    }

    // ---- Header: previous / next ----
    private var navigationHeader: some View {
        Section {
            HStack {
                Button {
                    shift(forward: false)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Previous")

                Spacer()

                VStack(spacing: 2) {
                    Text(rangeLabel)
                        .font(.display(.title3))
                    if span == .week, let first = dates.first, let type = weekType(for: first) {
                        WeekBadge(type: type)
                    }
                    if !subjectFilter.isEmpty {
                        Text("\(store.subject(for: subjectFilter).name) only")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button {
                    shift(forward: true)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Next")
            }

            Button("Back to today") {
                withAnimation { focusDate = Calendar.current.startOfDay(for: Date()) }
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity)
        }
        .listRowBackground(Theme.surface)
    }

    // ---- One day ----
    private func daySection(_ date: Date) -> some View {
        let weekday = calendar.component(.weekday, from: date)
        let lessons = store.lessons(on: weekday, week: weekType(for: date)).filter { matches($0.subjectID) }
        let due = store.items.filter {
            calendar.isDate($0.dueDate, inSameDayAs: date) && matches($0.subjectID)
        }
        let notes = store.notes(on: date)
        let isToday = calendar.isDateInToday(date)

        return Section {
            if lessons.isEmpty && due.isEmpty {
                Text("Nothing scheduled")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(lessons) { lesson in
                lessonRow(lesson, notes: notes.filter { $0.lessonID == lesson.id })
                    .contentShape(Rectangle())
                    .onTapGesture { open(date) }
            }

            ForEach(due) { item in
                dueRow(item)
                    .contentShape(Rectangle())
                    .onTapGesture { open(date) }
            }
        } header: {
            Button {
                open(date)
            } label: {
                HStack(spacing: 8) {
                    Text(date.formatted(.dateTime.weekday(.wide)))
                        .font(.display(.headline))
                    Text(date.formatted(.dateTime.day().month(.abbreviated)))
                        .foregroundStyle(.secondary)
                    if let type = weekType(for: date) {
                        WeekBadge(type: type)
                    }
                    if isToday {
                        Text("Today")
                            .font(.caption2)
                            .bold()
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Theme.gold))
                            .foregroundStyle(Theme.onAccent)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .textCase(nil)
            }
            .buttonStyle(.plain)
        }
        .listRowBackground(Theme.surface)
    }

    private func lessonRow(_ lesson: Lesson, notes: [ClassNote]) -> some View {
        let subject = store.subject(for: lesson.subjectID)
        let pending = notes.filter { $0.isPendingReview }.count

        return HStack(spacing: 12) {
            Capsule()
                .fill(subject.color)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 3) {
                Text(subject.name)
                    .font(.headline)
                if !lesson.details.isEmpty {
                    Text(lesson.details)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if !notes.isEmpty {
                Label("\(notes.count)", systemImage: "note.text")
                    .font(.caption)
                    .bold()
                    .foregroundStyle(pending > 0 ? Color.orange : Color.secondary)
            }

            Text(Lesson.label(forMinutes: lesson.startMinutes))
                .font(.subheadline)
                .bold()
                .frame(minWidth: 64, alignment: .trailing)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 2)
    }

    private func dueRow(_ item: Assessment) -> some View {
        let subject = store.subject(for: item)
        return HStack(spacing: 12) {
            Image(systemName: "flag.fill")
                .foregroundStyle(subject.color)
                .frame(width: 4)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.subheadline)
                    .strikethrough(item.isCompleted)
                Text("\(subject.name) · \(item.type.rawValue) due")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // ---- Actions ----
    private func open(_ date: Date) {
        focusDate = calendar.startOfDay(for: date)
        onOpenDay()
    }

    private func shift(forward: Bool) {
        let step: Int
        switch span {
        case .threeDays: step = 3
        case .week: step = 7
        }
        let amount = forward ? step : -step
        if let moved = calendar.date(byAdding: .day, value: amount, to: focusDate) {
            withAnimation { focusDate = calendar.startOfDay(for: moved) }
        }
    }
}
