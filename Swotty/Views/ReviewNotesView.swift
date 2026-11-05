import SwiftUI

// MARK: - Notes to review
// Every note flagged "needs review", grouped by subject, newest first.
// Tick a note off once you've gone over it.
struct ReviewNotesView: View {
    @EnvironmentObject private var store: StudyStore
    @Environment(\.dismiss) private var dismiss

    @State private var showReviewed = false
    @State private var noteTarget: NoteTarget? = nil

    private var pending: [ClassNote] { store.pendingReviewNotes }
    private var reviewed: [ClassNote] { store.reviewedNotes }

    var body: some View {
        NavigationStack {
            List {
                if pending.isEmpty {
                    Section {
                        EmptyStateView(icon: "checkmark.seal.fill",
                                       title: "Nothing to review",
                                       message: reviewed.isEmpty
                                       ? "Add a note to a class and mark it \"needs review\"."
                                       : "You're all caught up. Nice work!")
                    }
                } else {
                    ForEach(store.subjects) { subject in
                        let items = pending.filter { $0.subjectID == subject.id }
                        if !items.isEmpty {
                            Section {
                                ForEach(items) { note in
                                    noteRow(note)
                                }
                            } header: {
                                SubjectTag(subject: subject)
                            }
                        }
                    }
                }

                if !reviewed.isEmpty {
                    Section {
                        if showReviewed {
                            ForEach(reviewed) { note in
                                noteRow(note)
                            }
                        }
                    } header: {
                        HStack {
                            Text("Reviewed (\(reviewed.count))")
                            Spacer()
                            Button(showReviewed ? "Hide" : "Show") {
                                withAnimation { showReviewed.toggle() }
                            }
                            .font(.caption)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Notes to Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .bold()
                }
            }
            .sheet(item: $noteTarget) { target in
                NoteEditor(target: target, day: target.existing?.date ?? Date())
                    .environmentObject(store)
            }
        }
    }

    private func noteRow(_ note: ClassNote) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                withAnimation { store.toggleReviewed(note) }
            } label: {
                Image(systemName: note.isReviewed ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(note.isReviewed ? Color.green : Color.orange)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(note.isReviewed ? "Mark as not reviewed" : "Mark as reviewed")

            VStack(alignment: .leading, spacing: 4) {
                Text(note.text)
                    .lineLimit(4)
                    .foregroundStyle(note.isReviewed ? .secondary : .primary)
                    .strikethrough(note.isReviewed)
                Text(note.date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            noteTarget = NoteTarget(existing: note, lessonID: note.lessonID, subjectID: note.subjectID)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                withAnimation { store.deleteNote(note) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
