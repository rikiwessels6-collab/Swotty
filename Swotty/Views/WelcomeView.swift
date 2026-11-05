import SwiftUI
import UserNotifications
import UIKit

// MARK: - First-launch welcome
// Shown once to people with no data yet. They can look around
// with sample data, or start with a blank slate.
struct WelcomeView: View {
    @EnvironmentObject private var store: StudyStore
    @AppStorage("studentName") private var studentName = ""

    let onFinish: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)
                    .padding(.top, 40)

                Text("Welcome to Swotty")
                    .font(.largeTitle)
                    .bold()

                Text("Plan exams and assignments, keep your weekly timetable and stay on top of your study.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                TextField("What should we call you? (optional)", text: $studentName)
                    .textContentType(.givenName)
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(spacing: 10) {
                    Button {
                        store.loadDemoData()
                        onFinish()
                    } label: {
                        Text("Start with demo data")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button {
                        onFinish()
                    } label: {
                        Text("Start fresh")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Text("Demo data shows how everything works. You can remove it any time in Settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
            }
            .padding(24)
            .frame(maxWidth: 500)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Notifications nudge
// A dismissible card on the Planner asking to turn reminders on.
struct NotificationNudgeCard: View {
    let status: UNAuthorizationStatus
    let onEnable: () -> Void
    let onDismiss: () -> Void

    private var isDenied: Bool { status == .denied }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "bell.badge.fill")
                .font(.title)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 6) {
                Text("Turn on reminders")
                    .font(.headline)
                Text(isDenied
                     ? "Notifications are off for Swotty. Turn them on in Settings so you don't miss a due date."
                     : "Get a reminder before each assessment is due so nothing slips by. Change the time in Settings.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button(isDenied ? "Open Settings" : "Enable") {
                    onEnable()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .padding(.top, 2)
            }

            Spacer(minLength: 0)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Dismiss")
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.vertical, 4)
    }
}
