import SwiftUI

// MARK: - Month view
// A month of due dates. Tap a day to see what's due, or open it in the Day view.
// (The navigation stack and title come from ScheduleView.)
struct MonthCalendarView: View {
    @EnvironmentObject private var store: StudyStore
    @Binding var selectedDay: Date
    let onOpenDay: () -> Void

    @AppStorage(ScheduleSettings.weekStartKey) private var weekStart = 2
    @AppStorage(ScheduleSettings.subjectFilterKey) private var subjectFilter = ""
    @AppStorage("accentColour") private var accent: SubjectColour = .gold

    @State private var month = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
    @State private var editingItem: Assessment? = nil
    @State private var showingAddSheet = false

    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = weekStart
        return calendar
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    // Empty slots before day 1, then each day of the month.
    private var days: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let weekday = calendar.component(.weekday, from: month)
        let blanks = (weekday - calendar.firstWeekday + 7) % 7
        let monthDays: [Date?] = range.map { day in
            calendar.date(byAdding: .day, value: day - 1, to: month)
        }
        return Array(repeating: nil, count: blanks) + monthDays
    }

    // "M T W T F S S", starting on the chosen first weekday.
    private var weekdayLetters: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    private func items(on day: Date) -> [Assessment] {
        store.items
            .filter { calendar.isDate($0.dueDate, inSameDayAs: day)
                && (subjectFilter.isEmpty || $0.subjectID == subjectFilter) }
            .sorted { !$0.isCompleted && $1.isCompleted }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                monthCard
                dayList
            }
            .padding()
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .themedScreen()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                .accessibilityLabel("Add assessment on selected day")
            }
        }
        .onAppear {
            month = calendar.dateInterval(of: .month, for: selectedDay)?.start ?? month
        }
        .sheet(isPresented: $showingAddSheet) {
            AssessmentEditor(existing: nil,
                             defaultSubjectID: store.subjects.first?.id ?? Subject.otherID,
                             defaultDate: selectedDay)
                .environmentObject(store)
        }
        .sheet(item: $editingItem) { item in
            AssessmentEditor(existing: item)
                .environmentObject(store)
        }
    }

    private var monthCard: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    changeMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 40, height: 40)
                }
                .accessibilityLabel("Previous month")
                Spacer()
                Text(month.formatted(.dateTime.month(.wide).year()))
                    .font(.display(.title3))
                Spacer()
                Button {
                    changeMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 40, height: 40)
                }
                .accessibilityLabel("Next month")
            }
            .padding(.horizontal, 4)

            Button("Today") {
                withAnimation {
                    month = calendar.dateInterval(of: .month, for: Date())?.start ?? Date()
                    selectedDay = calendar.startOfDay(for: Date())
                }
            }
            .font(.caption)

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(weekdayLetters.enumerated()), id: \.offset) { _, letter in
                    Text(letter)
                        .font(.caption)
                        .bold()
                        .foregroundStyle(.secondary)
                }

                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayCell(day)
                    } else {
                        Color.clear.frame(height: 48)
                    }
                }
            }
        }
        .card()
    }

    private func dayCell(_ day: Date) -> some View {
        let dayItems = items(on: day)
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDay)
        let isToday = calendar.isDateInToday(day)

        return Button {
            selectedDay = calendar.startOfDay(for: day)
        } label: {
            VStack(spacing: 4) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.callout)
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundStyle(isSelected ? Theme.onAccent : (isToday ? accent.color : Color.primary))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(isSelected ? accent.color : Color.clear))

                // Up to three coloured dots, one per assessment.
                HStack(spacing: 3) {
                    ForEach(dayItems.prefix(3)) { item in
                        Circle()
                            .fill(store.subject(for: item).color.opacity(item.isCompleted ? 0.3 : 1))
                            .frame(width: 6, height: 6)
                    }
                }
                .frame(height: 6)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var dayList: some View {
        let dayItems = items(on: selectedDay)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(selectedDay.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.display(.headline))
                Spacer()
                Button("Open day") { onOpenDay() }
                    .font(.subheadline)
            }
            .padding(.horizontal, 4)

            if dayItems.isEmpty {
                Text("Nothing due. Tap + to add something on this day.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                ForEach(dayItems) { item in
                    AssessmentRow(item: item, subject: store.subject(for: item)) {
                        withAnimation { store.toggleCompleted(item) }
                    }
                    .padding(.horizontal)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .contentShape(Rectangle())
                    .onTapGesture { editingItem = item }
                }
            }
        }
    }

    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: month) {
            withAnimation { month = newMonth }
        }
    }
}
