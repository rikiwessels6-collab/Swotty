import SwiftUI
import UserNotifications

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
                .buttonStyle(BrandButtonStyle())
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
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.vertical, 4)
    }
}
