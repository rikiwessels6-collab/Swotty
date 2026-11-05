import SwiftUI

// MARK: - Focus timer tab
// Study in focused blocks (25 minutes by default) with short
// breaks. Finished focus time is added to the chosen task.
struct FocusTimerView: View {
    @EnvironmentObject private var store: StudyStore

    @AppStorage("focusMinutes") private var focusMinutes = 25
    @AppStorage("breakMinutes") private var breakMinutes = 5

    @State private var isBreak = false
    @State private var endDate: Date? = nil                 // set while running
    @State private var pausedRemaining: TimeInterval? = nil // set while paused
    @State private var now = Date()
    @State private var linkedItemID: UUID? = nil
    @State private var sessionsDone = 0

    // Ticks twice a second to update the clock.
    private let ticker = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    private var isRunning: Bool { endDate != nil }
    private var isIdle: Bool { endDate == nil && pausedRemaining == nil }

    private var phaseLength: TimeInterval {
        Double(isBreak ? breakMinutes : focusMinutes) * 60
    }

    private var remaining: TimeInterval {
        if let endDate { return max(0, endDate.timeIntervalSince(now)) }
        if let pausedRemaining { return pausedRemaining }
        return phaseLength
    }

    private var progress: Double {
        guard phaseLength > 0 else { return 0 }
        return 1 - remaining / phaseLength
    }

    private var phaseColor: Color { isBreak ? .green : .indigo }

    private var upcomingItems: [Assessment] {
        store.items.filter { !$0.isCompleted }.sorted { $0.dueDate < $1.dueDate }
    }

    private var timeText: String {
        let total = Int(remaining.rounded(.up))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    timerCard
                    linkCard
                    lengthsCard
                }
                .padding()
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Focus")
            .onReceive(ticker) { time in
                now = time
                if let endDate, time >= endDate {
                    finishPhase(countTime: true)
                }
            }
        }
    }

    private var timerCard: some View {
        VStack(spacing: 20) {
            Text(isBreak ? "Break time" : "Focus time")
                .font(.title2)
                .bold()
                .foregroundStyle(phaseColor)

            ZStack {
                Circle()
                    .stroke(phaseColor.opacity(0.15), lineWidth: 18)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(phaseColor, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.5), value: progress)
                Text(timeText)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .frame(width: 260, height: 260)

            HStack(spacing: 16) {
                Button(isRunning ? "Pause" : (isIdle ? "Start" : "Resume")) {
                    if isRunning {
                        pause()
                    } else {
                        start()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(phaseColor)
                .controlSize(.large)

                Button("Reset") { reset() }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(isIdle)

                Button(isBreak ? "Skip break" : "Skip") { finishPhase(countTime: false) }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
            }

            if sessionsDone > 0 {
                Text("Focus sessions completed: \(sessionsDone)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .card()
    }

    private var linkCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Studying for")
                .font(.headline)

            Picker("Studying for", selection: $linkedItemID) {
                Text("Nothing in particular").tag(UUID?.none)
                ForEach(upcomingItems) { item in
                    Text("\(store.subject(for: item).name): \(item.title)")
                        .tag(UUID?.some(item.id))
                }
            }
            .pickerStyle(.menu)

            if let id = linkedItemID, let item = store.items.first(where: { $0.id == id }) {
                Text("Studied so far: \(formatMinutes(item.studyMinutes))")
                    .font(.subheadline)
            }

            Text("Finished focus sessions add study time to this task.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .card()
    }

    private var lengthsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Timer lengths")
                .font(.headline)
            Stepper("Focus: \(focusMinutes) min", value: $focusMinutes, in: 5...90, step: 5)
            Stepper("Break: \(breakMinutes) min", value: $breakMinutes, in: 1...30)
            if !isIdle {
                Text("Reset the timer to change these.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .disabled(!isIdle)
        .card()
    }

    // ---- Timer controls ----
    private func start() {
        let length = pausedRemaining ?? phaseLength
        now = Date()
        endDate = now.addingTimeInterval(length)
        pausedRemaining = nil
        ReminderScheduler.scheduleTimerEnd(after: length, isFocus: !isBreak)
    }

    private func pause() {
        pausedRemaining = remaining
        endDate = nil
        ReminderScheduler.cancelTimer()
    }

    private func reset() {
        endDate = nil
        pausedRemaining = nil
        ReminderScheduler.cancelTimer()
    }

    private func finishPhase(countTime: Bool) {
        if countTime && !isBreak {
            sessionsDone += 1
            if let id = linkedItemID {
                store.addStudyMinutes(focusMinutes, to: id)
            }
        }
        reset()
        withAnimation { isBreak.toggle() }
    }
}
