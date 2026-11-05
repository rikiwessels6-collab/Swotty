import SwiftUI
import UserNotifications
import UIKit

// MARK: - Planner tab
struct PlannerView: View {
    @EnvironmentObject private var store: StudyStore

    @State private var subjectFilter: String? = nil   // nil means "All"
    @State private var showingAddSheet = false
    @State private var editingItem: Assessment? = nil
    @State private var showCompleted = false

    @AppStorage("studentName") private var studentName = ""
    @AppStorage("accentColour") private var accent: SubjectColour = .indigo
    @AppStorage("dismissedNotificationNudge") private var nudgeDismissed = false

    // Starts as "authorized" so the card never flashes before we know.
    @State private var notificationStatus: UNAuthorizationStatus = .authorized

    private var showNotificationNudge: Bool {
        !nudgeDismissed && (notificationStatus == .notDetermined || notificationStatus == .denied)
    }

    private func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationStatus = settings.authorizationStatus
    }

    private func enableNotifications() {
        if notificationStatus == .denied {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
            return
        }
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                DispatchQueue.main.async {
                    if granted { store.rescheduleAllReminders() }
                    Task { await refreshNotificationStatus() }
                }
            }
    }

    private var visible: [Assessment] {
        store.items.filter { subjectFilter == nil || $0.subjectID == subjectFilter }
    }

    private var overdue: [Assessment] {
        visible.filter { !$0.isCompleted && $0.daysRemaining < 0 }
            .sorted { $0.dueDate < $1.dueDate }
    }

    private var nextSevenDays: [Assessment] {
        visible.filter { !$0.isCompleted && (0...7).contains($0.daysRemaining) }
            .sorted { $0.dueDate < $1.dueDate }
    }

    private var later: [Assessment] {
        visible.filter { !$0.isCompleted && $0.daysRemaining > 7 }
            .sorted { $0.dueDate < $1.dueDate }
    }

    private var completed: [Assessment] {
        visible.filter { $0.isCompleted }
            .sorted { $0.dueDate > $1.dueDate }
    }

    // The most urgent unfinished task.
    private var nextUp: Assessment? {
        (overdue + nextSevenDays + later).first
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let part = hour < 12 ? "Good morning" : (hour < 17 ? "Good afternoon" : "Good evening")
        let name = studentName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? part : "\(part), \(name)"
    }

    private var summary: String {
        if !overdue.isEmpty {
            return overdue.count == 1 ? "1 task is overdue. Let's catch up." : "\(overdue.count) tasks are overdue. Let's catch up."
        }
        if !nextSevenDays.isEmpty {
            return nextSevenDays.count == 1 ? "1 thing due in the next week." : "\(nextSevenDays.count) things due in the next week."
        }
        if !later.isEmpty { return "Nothing due this week. Nice and calm." }
        if !completed.isEmpty { return "All caught up. Great work! 🎉" }
        return "Add your first assessment to get started."
    }

    var body: some View {
        NavigationStack {
            List {
                if showNotificationNudge {
                    Section {
                        NotificationNudgeCard(status: notificationStatus,
                                              onEnable: enableNotifications,
                                              onDismiss: { withAnimation { nudgeDismissed = true } })
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                Section {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(greeting)
                                .font(.title2)
                                .bold()
                            Text(summary)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 4)

                        if let nextUp {
                            NextUpCard(item: nextUp, subject: store.subject(for: nextUp))
                                .onTapGesture { editingItem = nextUp }
                        }

                        HStack(spacing: 10) {
                            StatTile(value: "\(nextSevenDays.count)", label: "This week",
                                     color: .orange, icon: "calendar")
                            StatTile(value: "\(overdue.count)", label: "Overdue",
                                     color: .red, icon: "exclamationmark.circle.fill")
                            StatTile(value: "\(completed.count)", label: "Done",
                                     color: .green, icon: "checkmark.seal.fill")
                        }
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                Section {
                    subjectFilterBar
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                if visible.isEmpty {
                    Section {
                        EmptyStateView(icon: "books.vertical.fill",
                                       title: "No assessments yet",
                                       message: "Tap + to add an exam, assignment or quiz.")
                    }
                }

                taskSection("Overdue", items: overdue)
                taskSection("Next 7 days", items: nextSevenDays)
                taskSection("Later", items: later)

                if !completed.isEmpty {
                    Section {
                        if showCompleted {
                            ForEach(completed) { item in
                                row(for: item)
                            }
                        }
                    } header: {
                        HStack {
                            Text("Completed (\(completed.count))")
                            Spacer()
                            Button(showCompleted ? "Hide" : "Show") {
                                withAnimation { showCompleted.toggle() }
                            }
                            .font(.caption)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .task { await refreshNotificationStatus() }
            .navigationTitle("Planner")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                    .accessibilityLabel("Add assessment")
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AssessmentEditor(existing: nil,
                                 defaultSubjectID: subjectFilter ?? store.subjects.first?.id ?? Subject.otherID)
                    .environmentObject(store)
            }
            .sheet(item: $editingItem) { item in
                AssessmentEditor(existing: item)
                    .environmentObject(store)
            }
        }
    }

    @ViewBuilder
    private func taskSection(_ title: String, items: [Assessment]) -> some View {
        if !items.isEmpty {
            Section(title) {
                ForEach(items) { item in
                    row(for: item)
                }
            }
        }
    }

    // Tap to edit, swipe right to tick off, swipe left to delete.
    private func row(for item: Assessment) -> some View {
        AssessmentRow(item: item, subject: store.subject(for: item)) {
            withAnimation { store.toggleCompleted(item) }
        }
        .contentShape(Rectangle())
        .onTapGesture { editingItem = item }
        .swipeActions(edge: .leading) {
            Button {
                withAnimation { store.toggleCompleted(item) }
            } label: {
                Label(item.isCompleted ? "Undo" : "Done",
                      systemImage: item.isCompleted ? "arrow.uturn.backward" : "checkmark")
            }
            .tint(.green)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                withAnimation { store.delete(item) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var subjectFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "All", icon: "square.grid.2x2.fill", color: accent.color,
                           isSelected: subjectFilter == nil) {
                    subjectFilter = nil
                }
                ForEach(store.subjects) { subject in
                    FilterChip(title: subject.name, icon: subject.icon, color: subject.color,
                               isSelected: subjectFilter == subject.id) {
                        subjectFilter = subject.id
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}
