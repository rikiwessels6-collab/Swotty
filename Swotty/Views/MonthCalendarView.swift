import SwiftUI

// MARK: - Calendar tab
struct MonthCalendarView: View {
    @EnvironmentObject private var store: StudyStore

    @State private var month = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
    @State private var selectedDay = Calendar.current.startOfDay(for: Date())
    @State private var editingItem: Assessment? = nil
    @State private var showingAddSheet = false
    @AppStorage("accentColour") private var accent: SubjectColour = .indigo

    private let calendar = Calendar.current
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

    // "M T W T F S S", starting on the device's first weekday.
    private var weekdayLetters: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    private func items(on day: Date) -> [Assessment] {
        store.items
            .filter { calendar.isDate($0.dueDate, inSameDayAs: day) }
            .sorted { !$0.isCompleted && $1.isCompleted }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    monthCard
                    dayList
                }
                .padding()
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Calendar")
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
    }

    private var monthCard: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    changeMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel("Previous month")
                Spacer()
                Text(month.formatted(.dateTime.month(.wide).year()))
                    .font(.title3)
                    .bold()
                Spacer()
                Button {
                    changeMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
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
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func dayCell(_ day: Date) -> some View {
        let dayItems = items(on: day)
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDay)
        let isToday = calendar.isDateInToday(day)

        return Button {
            selectedDay = day
        } label: {
            VStack(spacing: 4) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.callout)
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundStyle(isSelected ? Color.white : (isToday ? accent.color : Color.primary))
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
            Text(selectedDay.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.headline)
                .padding(.horizontal, 4)

            if dayItems.isEmpty {
                Text("Nothing due. Tap + to add something on this day.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ForEach(dayItems) { item in
                    AssessmentRow(item: item, subject: store.subject(for: item)) {
                        withAnimation { store.toggleCompleted(item) }
                    }
                    .padding(.horizontal)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
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
