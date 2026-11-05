import SwiftUI

// MARK: - Add / edit screen
// Used for adding (existing is nil) and editing.
struct AssessmentEditor: View {
    @EnvironmentObject private var store: StudyStore
    @Environment(\.dismiss) private var dismiss

    let existing: Assessment?

    @State private var draft: Assessment
    @State private var remindMe: Bool
    @State private var daysBefore: Int
    @State private var newStepText = ""
    @State private var confirmingDelete = false

    init(existing: Assessment?, defaultSubjectID: String = Subject.otherID, defaultDate: Date? = nil) {
        self.existing = existing
        let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        let start = existing ?? Assessment(title: "", type: .exam,
                                           subjectID: defaultSubjectID,
                                           dueDate: defaultDate ?? nextWeek)
        _draft = State(initialValue: start)
        _remindMe = State(initialValue: start.reminderDaysBefore != nil)
        _daysBefore = State(initialValue: start.reminderDaysBefore ?? 1)
    }

    private var trimmedTitle: String {
        draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private let suggestedSteps = ["Research", "Plan", "Write draft", "Check and edit", "Hand in"]

    var body: some View {
        NavigationStack {
            Form {
                detailsSection
                dueSection
                stepsSection
                resultSection

                Section("Notes") {
                    TextField("Topics to revise, page numbers…", text: $draft.notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                if existing != nil {
                    Section {
                        Button("Delete Assessment", role: .destructive) {
                            confirmingDelete = true
                        }
                    }
                }
            }
            .navigationTitle(existing == nil ? "New Assessment" : "Edit Assessment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .bold()
                        .disabled(trimmedTitle.isEmpty)
                }
            }
            .confirmationDialog("Delete this assessment?", isPresented: $confirmingDelete,
                                titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let existing { store.delete(existing) }
                    dismiss()
                }
            }
        }
    }

    // ---- Sections of the form ----
    private var detailsSection: some View {
        Section("Details") {
            TextField("Title, e.g. Algebra test", text: $draft.title)

            Picker("Subject", selection: $draft.subjectID) {
                ForEach(store.subjects) { subject in
                    Label(subject.name, systemImage: subject.icon)
                        .tag(subject.id)
                }
            }

            Picker("Type", selection: $draft.type) {
                ForEach(AssessmentType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)

            if existing != nil {
                Toggle("Completed", isOn: $draft.isCompleted)
            }
        }
    }

    private var dueSection: some View {
        Section {
            DatePicker("Due date", selection: $draft.dueDate, displayedComponents: .date)
            Toggle("Remind me", isOn: $remindMe.animation())
            if remindMe {
                Stepper(daysBefore == 1 ? "1 day before" : "\(daysBefore) days before",
                        value: $daysBefore, in: 1...14)
            }
        } header: {
            Text("Due date and reminder")
        } footer: {
            if remindMe {
                Text("Reminder at \(ReminderScheduler.label(forHour: ReminderScheduler.reminderHour)). Change the time in Settings.")
            }
        }
    }

    private var stepsSection: some View {
        Section {
            ForEach($draft.steps) { $step in
                HStack {
                    Button {
                        step.isDone.toggle()
                    } label: {
                        Image(systemName: step.isDone ? "checkmark.square.fill" : "square")
                            .foregroundStyle(step.isDone ? Color.green : Color.secondary)
                    }
                    .buttonStyle(.borderless)

                    TextField("Step", text: $step.text)
                        .strikethrough(step.isDone)
                }
            }
            .onDelete { offsets in
                draft.steps.remove(atOffsets: offsets)
            }

            HStack {
                TextField("Add a step", text: $newStepText)
                    .onSubmit(addStep)
                Button(action: addStep) {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.borderless)
                .disabled(newStepText.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if draft.steps.isEmpty && draft.type == .assignment {
                Button("Add suggested steps") {
                    draft.steps = suggestedSteps.map { ChecklistStep(text: $0) }
                }
            }
        } header: {
            Text("Steps")
        } footer: {
            Text("Break big tasks into small steps. Swipe a step left to delete it.")
        }
    }

    private var resultSection: some View {
        Section {
            HStack {
                Text("Mark")
                Spacer()
                TextField("Score", value: $draft.score, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 70)
                Text("out of")
                    .foregroundStyle(.secondary)
                TextField("Total", value: $draft.outOf, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 70)
            }

            Picker("Grade", selection: $draft.grade) {
                Text("None").tag(Grade?.none)
                ForEach(Grade.allCases) { grade in
                    Text(grade.rawValue).tag(Grade?.some(grade))
                }
            }

            if let pct = draft.percentage {
                LabeledContent("Percentage", value: "\(formatNumber(pct))%")
            }

            if draft.studyMinutes > 0 {
                LabeledContent("Time studied", value: formatMinutes(draft.studyMinutes))
            }
        } header: {
            Text("Result")
        } footer: {
            Text("Add your mark or grade once it's been marked.")
        }
    }

    // ---- Actions ----
    private func addStep() {
        let text = newStepText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        draft.steps.append(ChecklistStep(text: text))
        newStepText = ""
    }

    private func save() {
        draft.title = trimmedTitle
        draft.reminderDaysBefore = remindMe ? daysBefore : nil
        draft.steps.removeAll { $0.text.trimmingCharacters(in: .whitespaces).isEmpty }

        if existing == nil {
            store.add(draft)
        } else {
            store.update(draft)
        }
        dismiss()
    }
}
