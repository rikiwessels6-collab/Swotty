import SwiftUI

// MARK: - Managing subjects
struct SubjectsListView: View {
    @EnvironmentObject private var store: StudyStore
    @State private var editingSubject: Subject? = nil
    @State private var showingAddSheet = false

    var body: some View {
        List {
            Section {
                NavigationLink {
                    SubjectLibraryView()
                } label: {
                    Label("Browse subject library", systemImage: "books.vertical.fill")
                }
            } footer: {
                Text("Quickly add or remove subjects like Italian, Drama or Digital Technologies.")
            }

            Section {
                ForEach(store.subjects) { subject in
                    HStack {
                        Image(systemName: subject.icon)
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(subject.color)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        Text(subject.name)
                        Spacer()
                        Text("\(store.count(for: subject))")
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { editingSubject = subject }
                }
                .onDelete { offsets in
                    let toDelete = offsets.map { store.subjects[$0] }
                    toDelete.forEach { store.deleteSubject($0) }
                }
                .onMove { source, destination in
                    store.moveSubjects(from: source, to: destination)
                }
            } footer: {
                Text("Tap a subject to edit it. Deleting a subject moves its assessments to Other. Other can't be deleted.")
            }
        }
        .navigationTitle("Subjects")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                EditButton()
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add subject")
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            SubjectEditor(existing: nil)
                .environmentObject(store)
        }
        .sheet(item: $editingSubject) { subject in
            SubjectEditor(existing: subject)
                .environmentObject(store)
        }
    }
}

struct SubjectEditor: View {
    @EnvironmentObject private var store: StudyStore
    @Environment(\.dismiss) private var dismiss

    let existing: Subject?
    @State private var draft: Subject

    init(existing: Subject?) {
        self.existing = existing
        _draft = State(initialValue: existing
                       ?? Subject(id: UUID().uuidString, name: "", colour: .blue, icon: "star.fill"))
    }

    private var trimmedName: String {
        draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private let grid = [GridItem(.adaptive(minimum: 44), spacing: 12)]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        Image(systemName: draft.icon)
                            .font(.largeTitle)
                            .foregroundStyle(.white)
                            .frame(width: 72, height: 72)
                            .background(draft.color)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                        Spacer()
                    }
                    TextField("Subject name", text: $draft.name)
                        .multilineTextAlignment(.center)
                        .font(.title3)
                }

                Section("Colour") {
                    LazyVGrid(columns: grid, spacing: 12) {
                        ForEach(SubjectColour.allCases) { colour in
                            Circle()
                                .fill(colour.color)
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: draft.colour == colour ? 3 : 0)
                                        .padding(-4)
                                )
                                .onTapGesture { draft.colour = colour }
                                .accessibilityLabel(colour.rawValue)
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section("Icon") {
                    LazyVGrid(columns: grid, spacing: 12) {
                        ForEach(subjectIcons, id: \.self) { icon in
                            Image(systemName: icon)
                                .font(.title3)
                                .frame(width: 44, height: 44)
                                .background(draft.icon == icon ? draft.color.opacity(0.25) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .onTapGesture { draft.icon = icon }
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle(existing == nil ? "New Subject" : "Edit Subject")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        draft.name = trimmedName
                        if existing == nil {
                            store.addSubject(draft)
                        } else {
                            store.updateSubject(draft)
                        }
                        dismiss()
                    }
                    .bold()
                    .disabled(trimmedName.isEmpty)
                }
            }
        }
    }
}

// MARK: - Subject library
// Switch subjects on or off. Turning one off moves its
// assessments to Other, so nothing is lost.
struct SubjectLibraryView: View {
    @EnvironmentObject private var store: StudyStore

    var body: some View {
        List {
            ForEach(Subject.library) { group in
                Section(group.name) {
                    ForEach(group.subjects) { subject in
                        Toggle(isOn: binding(for: subject)) {
                            HStack(spacing: 12) {
                                Image(systemName: subject.icon)
                                    .foregroundStyle(.white)
                                    .frame(width: 32, height: 32)
                                    .background(subject.color)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(subject.name)
                                    let count = store.count(for: subject)
                                    if count > 0 {
                                        Text(count == 1 ? "1 assessment" : "\(count) assessments")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .disabled(subject.id == Subject.otherID)
                    }
                }
            }

            Section {
                EmptyView()
            } footer: {
                Text("Senior (Year 11–12) subjects aren't listed here. Add them with + on the Subjects screen.")
            }
        }
        .navigationTitle("Subject Library")
    }

    private func binding(for subject: Subject) -> Binding<Bool> {
        Binding(
            get: { store.hasSubject(subject.id) },
            set: { isOn in
                withAnimation {
                    if isOn {
                        store.addSubject(subject)
                    } else if let saved = store.subjects.first(where: { $0.id == subject.id }) {
                        store.deleteSubject(saved)
                    }
                }
            }
        )
    }
}
