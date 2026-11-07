import SwiftUI

// MARK: - First-launch setup
// A short guided setup shown once to people with no data yet.
// Existing users never see it.
struct OnboardingView: View {
    @EnvironmentObject private var store: StudyStore

    @AppStorage("studentName") private var studentName = ""
    @AppStorage(ScheduleSettings.showWeekendKey) private var showWeekend = false
    @AppStorage(ScheduleSettings.weekStartKey) private var weekStart = 2
    @AppStorage(ScheduleSettings.roundedTimesKey) private var roundedTimes = true
    @AppStorage(ScheduleSettings.weeksKey) private var timetableWeeks = 1
    @AppStorage(ScheduleSettings.weekAAnchorKey) private var weekAAnchor: Double = 0

    @State private var step = 0
    private let lastStep = 3

    let onFinish: () -> Void

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $step) {
                    welcomePage.tag(0)
                    weekPage.tag(1)
                    timesPage.tag(2)
                    readyPage.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .never))

                buttons
            }
        }
    }

    // ---- Pages ----
    private var welcomePage: some View {
        page {
            Image(systemName: "graduationcap.fill")
                .font(.system(size: 34))
                .foregroundStyle(Theme.onAccent)
                .frame(width: 76, height: 76)
                .background(Circle().fill(Theme.gold))
                .padding(.bottom, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome to")
                    .font(.display(.title2, weight: .regular))
                    .foregroundStyle(.secondary)
                Text("Swotty")
                    .font(.display(.largeTitle, weight: .bold))
            }

            VStack(alignment: .leading, spacing: 18) {
                featureRow(icon: "checklist", tint: Theme.gold,
                           title: "Plan assessments",
                           detail: "Exams, assignments and quizzes with steps and countdowns.")
                featureRow(icon: "calendar", tint: Color(hex: 0x4C7DDB),
                           title: "Your school week",
                           detail: "A timetable for every class, by day, 3 days, week or month.")
                featureRow(icon: "note.text", tint: Theme.emerald,
                           title: "Notes to review",
                           detail: "Jot what to revisit after each class and tick it off later.")
                featureRow(icon: "bell.badge.fill", tint: Color(hex: 0xD1495B),
                           title: "Gentle reminders",
                           detail: "Nudges before classes and when something is due.")
            }
            .padding(.top, 8)
        }
    }

    private var weekPage: some View {
        page {
            heading("Your school week", subtitle: "Tell us how your week works. You can change this any time.")

            card {
                VStack(alignment: .leading, spacing: 8) {
                    Text("What should we call you?")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField("Your name (optional)", text: $studentName)
                        .textContentType(.givenName)
                        .font(.display(.title3))
                }
            }

            card {
                Toggle(isOn: $showWeekend) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show the weekend")
                        Text("Include Saturday and Sunday")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            card {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Week starts on")
                    Picker("Week starts on", selection: Binding(
                        get: { weekStart },
                        set: { ScheduleSettings.setWeekStart($0) }
                    )) {
                        ForEach(ScheduleSettings.weekStartChoices, id: \.day) { choice in
                            Text(choice.name).tag(choice.day)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

            card {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Timetable repeats")
                    Picker("Timetable repeats", selection: Binding(
                        get: { timetableWeeks },
                        set: { ScheduleSettings.setTimetableWeeks($0) }
                    )) {
                        Text("Every week").tag(1)
                        Text("Week A & B").tag(2)
                    }
                    .pickerStyle(.segmented)

                    if timetableWeeks == 2 {
                        Text("This week is")
                            .padding(.top, 4)
                        Picker("This week is", selection: Binding(
                            get: { ScheduleSettings.weekType(for: Date(), anchor: weekAAnchor, weekStart: weekStart) },
                            set: { ScheduleSettings.setCurrentWeekType($0) }
                        )) {
                            Text("Week A").tag(1)
                            Text("Week B").tag(2)
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
        }
    }

    private var timesPage: some View {
        page {
            heading("Class times", subtitle: "Pick how precise your timetable should be.")

            card {
                Toggle(isOn: $roundedTimes) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Round class times")
                        Text("9:10 am, 9:15 am, 9:20 am")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Text("With this on, a class that starts at 9:12 is saved as 9:10. Turn it off for exact times.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var readyPage: some View {
        page {
            heading("You're all set", subtitle: "Start with sample data to explore how everything works, or begin with a blank slate.")

            card {
                VStack(alignment: .leading, spacing: 12) {
                    summaryRow(icon: "calendar", text: showWeekend ? "Seven-day week" : "Monday to Friday")
                    summaryRow(icon: "arrow.right.circle", text: "Week starts on \(weekStartName)")
                    summaryRow(icon: "arrow.2.squarepath", text: timetableWeeks == 2 ? "Week A & Week B timetable" : "Same timetable every week")
                    summaryRow(icon: "clock", text: roundedTimes ? "Times rounded to 5 minutes" : "Exact class times")
                }
            }

            Text("Demo data can be removed any time in Settings → Manage Data.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // ---- Buttons ----
    private var buttons: some View {
        VStack(spacing: 12) {
            if step < lastStep {
                Button {
                    withAnimation { step += 1 }
                } label: {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(BrandButtonStyle())
            } else {
                Button {
                    store.loadDemoData()
                    onFinish()
                } label: {
                    Text("Start with demo data")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(BrandButtonStyle())

                Button {
                    onFinish()
                } label: {
                    Text("Start fresh")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SoftButtonStyle())
            }

            Button("Back") {
                withAnimation { step -= 1 }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .opacity(step > 0 ? 1 : 0)
            .disabled(step == 0)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }

    // ---- Building blocks ----
    private var weekStartName: String {
        ScheduleSettings.weekStartChoices.first { $0.day == weekStart }?.name ?? "Monday"
    }

    private func page<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                content()
            }
            .padding(.horizontal, 24)
            .padding(.top, 48)
            .padding(.bottom, 40)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private func heading(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.display(.largeTitle, weight: .bold))
            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1))
    }

    private func featureRow(icon: String, tint: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(tint.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func summaryRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Theme.gold)
                .frame(width: 24)
            Text(text)
        }
    }
}
