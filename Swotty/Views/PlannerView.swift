import SwiftUI
import UserNotifications
import UIKit

// MARK: - Planner tab
struct PlannerView: View {
    @EnvironmentObject private var store: StudyStore

    @State private var subjectFilter: String? = nil   // nil means "All"
    @State private var showingAddSheet = false
    @State private var showingQuickAdd = false
    @State private var searchText = ""
    @State private var editingItem: Assessment? = nil
    @State private var showCompleted = false

    @AppStorage("studentName") private var studentName = ""
    @AppStorage("accentColour") private var accent: SubjectColour = .indigo
    @AppStorage("dismissedNotificationNudge") private var nudgeDismissed = false

    // Starts as "authorized" so the card never flashes before we know.
    @State private var notificationStatus: UNAuthorizationStatus = .authorized
    @State private var showingReview = false
    @AppStorage(ScheduleSettings.weeksKey) private var timetableWeeks = 1
    @AppStorage(ScheduleSettings.weekAAnchorKey) private var weekAAnchor: Double = 0
    @AppStorage(ScheduleSettings.weekStartKey) private var weekStartSetting = 2

    // Show today's class and review shortcut only when there's something to show.
    private var showTodayCard: Bool {
        let week: Int? = timetableWeeks == 2
            ? ScheduleSettings.weekType(for: Date(), anchor: weekAAnchor, weekStart: weekStartSetting)
            : nil
        let weekday = Calendar.current.component(.weekday, from: Date())
        return !store.lessons(on: weekday, week: week).isEmpty || !store.pendingReviewNotes.isEmpty
    }

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
        store.items.filter {
            (subjectFilter == nil || $0.subjectID == subjectFilter)
                && $0.matches(search: searchText, subjectName: store.subject(for: $0).name)
        }
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

                if showTodayCard {
                    Section {
                        TodayCard(onShowReview: { showingReview = true })
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                Section {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(greeting)
                                    .font(.display(.title2, weight: .bold))
                                Text(summary)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            if !store.items.isEmpty {
                                ProgressRing(progress: Double(store.items.filter { $0.isCompleted }.count)
                                                / Double(store.items.count))
                                    .frame(width: 62, height: 62)
                            }
                        }
                        .premiumCard()

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

                if InsightsCard.hasContent(store.items) {
                    Section {
                        InsightsCard()
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                Section {
                    subjectFilterBar
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                if visible.isEmpty {
                    Section {
                        EmptyStateView(icon: "books.vertical.fill",
                                       title: "No assessments yet",
                                       message: "Add an exam, assignment or quiz and Swotty will count down to it.",
                                       actionTitle: "Quick add",
                                       action: { showingQuickAdd = true })
                    }
                    .listRowBackground(Theme.surface)
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
                    .listRowBackground(Theme.surface)
                }
            }
            .listStyle(.insetGrouped)
            .themedList()
            .searchable(text: $searchText, prompt: "Search assessments")
            .overlay(alignment: .bottomTrailing) {
                Button {
                    Haptics.tap()
                    showingQuickAdd = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Theme.onAccent)
                        .frame(width: 58, height: 58)
                        .background(Theme.goldGradient)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 0.75))
                        .shadow(color: Theme.gold.opacity(0.45), radius: 12, y: 6)
                }
                .padding(20)
                .accessibilityLabel("Quick add")
                .accessibilityHint("Adds a task or assessment from a short sentence")
            }
            .overlay(alignment: .bottom) {
                if let deleted = store.recentlyDeleted {
                    HStack {
                        Text("Deleted \u{201C}\(deleted.title)\u{201D}")
                            .lineLimit(1)
                        Spacer()
                        Button("Undo") { withAnimation { store.undoDelete() } }
                            .bold()
                            .foregroundStyle(Theme.gold)
                    }
                    .padding()
                    .background(Theme.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)
                    .padding(.bottom, 88)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: deleted.id) {
                        try? await Task.sleep(nanoseconds: 6_000_000_000)
                        if store.recentlyDeleted?.id == deleted.id {
                            withAnimation { store.recentlyDeleted = nil }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingQuickAdd) {
                QuickAddSheet(defaultSubjectID: subjectFilter ?? store.subjects.first?.id ?? Subject.otherID)
                    .environmentObject(store)
            }
            .task { await refreshNotificationStatus() }
            .sheet(isPresented: $showingReview) {
                ReviewNotesView()
                    .environmentObject(store)
            }
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
            .listRowBackground(Theme.surface)
        }
    }

    // Tap to edit, swipe right to tick off, swipe left to delete.
    private func row(for item: Assessment) -> some View {
        AssessmentRow(item: item, subject: store.subject(for: item)) {
            withAnimation { store.toggleCompleted(item) }
        }
        .contentShape(Rectangle())
        .onTapGesture { editingItem = item }
        .contextMenu {
            Button {
                store.add(item.duplicated())
                Haptics.tap()
            } label: {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }
        }
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
