import SwiftUI

// MARK: - Quick add
// Type "Maths exam Friday", pick a subject, done.
struct QuickAddSheet: View {
    @EnvironmentObject private var store: StudyStore
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var subjectID: String
    @State private var pickedDate: Date? = nil
    @State private var typeOverride: AssessmentType? = nil
    @State private var showDatePicker = false
    @FocusState private var focused: Bool

    init(defaultSubjectID: String) {
        _subjectID = State(initialValue: defaultSubjectID)
    }

    private var parsed: QuickAddResult { QuickAdd.parse(text) }

    private var calendar: Calendar { Calendar.current }

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: Date())) ?? Date()
    }

    private var dueDate: Date { pickedDate ?? parsed.date ?? day(1) }
    private var type: AssessmentType { typeOverride ?? parsed.type }
    private var canAdd: Bool { !parsed.title.trimmingCharacters(in: .whitespaces).isEmpty }

    private var summary: String {
        "\(type.rawValue) due \(dueDate.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. Maths exam Friday", text: $text)
                        .focused($focused)
                        .submitLabel(.done)
                        .onSubmit(add)
                    if canAdd {
                        Text(summary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(Theme.surface)

                Section("Subject") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(store.subjects) { subject in
                                FilterChip(title: subject.name, icon: subject.icon, color: subject.color,
                                           isSelected: subjectID == subject.id) {
                                    subjectID = subject.id
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listRowBackground(Theme.surface)

                Section("Due") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            dateChip("Today", offset: 0)
                            dateChip("Tomorrow", offset: 1)
                            dateChip("Next week", offset: 7)
                            FilterChip(title: "Pick a date", icon: "calendar", color: Theme.gold,
                                       isSelected: showDatePicker) {
                                withAnimation { showDatePicker.toggle() }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    if showDatePicker {
                        DatePicker("Due date",
                                   selection: Binding(get: { dueDate }, set: { pickedDate = $0 }),
                                   displayedComponents: .date)
                    }
                }
                .listRowBackground(Theme.surface)

                Section("Type") {
                    Picker("Type", selection: Binding(get: { type }, set: { typeOverride = $0 })) {
                        ForEach(AssessmentType.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(Theme.surface)
            }
            .themedList()
            .navigationTitle("Quick Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: add)
                        .disabled(!canAdd)
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium, .large])
    }

    private func dateChip(_ title: String, offset: Int) -> some View {
        FilterChip(title: title, icon: "calendar", color: Theme.gold,
                   isSelected: calendar.isDate(dueDate, inSameDayAs: day(offset)) && !showDatePicker) {
            pickedDate = day(offset)
            showDatePicker = false
        }
    }

    private func add() {
        guard canAdd else { return }
        var item = Assessment(title: parsed.title, type: type, subjectID: subjectID, dueDate: dueDate)
        item.reminderDaysBefore = 1
        store.add(item)
        Haptics.success()
        dismiss()
    }
}
