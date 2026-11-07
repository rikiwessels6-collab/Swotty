import SwiftUI

// MARK: - Reusable pieces
struct AssessmentRow: View {
    let item: Assessment
    let subject: Subject
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(item.isCompleted ? Color.green : subject.color)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(item.isCompleted ? "Mark as not done" : "Mark as done")

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .strikethrough(item.isCompleted)
                    .foregroundStyle(item.isCompleted ? .secondary : .primary)

                HStack(spacing: 6) {
                    SubjectTag(subject: subject)
                    Text(item.type.rawValue)
                    if !item.steps.isEmpty {
                        Text("•")
                        Text("\(item.stepsDone)/\(item.steps.count) steps")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if !item.steps.isEmpty && !item.isCompleted {
                    ProgressView(value: Double(item.stepsDone), total: Double(item.steps.count))
                        .tint(subject.color)
                        .frame(maxWidth: 160)
                }

                if !item.notes.isEmpty {
                    Text(item.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(item.accessibilitySummary(subjectName: subject.name))

            Spacer()

            Group {
            if item.isCompleted {
                if item.hasResult {
                    ResultBadge(item: item)
                }
            } else {
                VStack(alignment: .trailing, spacing: 4) {
                    CountdownBadge(days: item.daysRemaining)
                    HStack(spacing: 4) {
                        if item.reminderDaysBefore != nil {
                            Image(systemName: "bell.fill")
                        }
                        if item.calendarEventID != nil {
                            Image(systemName: "calendar")
                        }
                        Text(item.dueDate.formatted(.dateTime.day().month(.abbreviated)))
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
            }
            .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
    }
}

struct CountdownBadge: View {
    let days: Int

    private var text: String {
        if days < 0 { return "\(-days)d late" }
        if days == 0 { return "Today" }
        if days == 1 { return "Tomorrow" }
        return "\(days) days"
    }

    private var color: Color {
        if days <= 0 { return .red }
        if days <= 3 { return .orange }
        return .blue
    }

    var body: some View {
        Text(text)
            .font(.caption)
            .bold()
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

// Shows a mark like "85%" and/or a grade like "A".
struct ResultBadge: View {
    let item: Assessment

    private var text: String {
        var parts: [String] = []
        if let pct = item.percentage { parts.append("\(Int(pct.rounded()))%") }
        if let grade = item.grade { parts.append(grade.rawValue) }
        return parts.joined(separator: " · ")
    }

    private var color: Color {
        guard let pct = item.percentage else { return .purple }
        if pct >= 85 { return .green }
        if pct >= 70 { return .blue }
        if pct >= 50 { return .orange }
        return .red
    }

    var body: some View {
        Text(text)
            .font(.subheadline)
            .bold()
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

struct StatTile: View {
    let value: String
    let label: String
    let color: Color
    var icon: String? = nil

    var body: some View {
        VStack(spacing: 2) {
            if let icon {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(color)
            }
            Text(value)
                .font(.title)
                .bold()
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// A small coloured pill showing the subject.
struct SubjectTag: View {
    let subject: Subject

    var body: some View {
        Label(subject.name, systemImage: subject.icon)
            .font(.caption)
            .bold()
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(subject.color.opacity(0.15))
            .foregroundStyle(subject.color)
            .clipShape(Capsule())
    }
}

// The big coloured card at the top of the Planner.
struct NextUpCard: View {
    let item: Assessment
    let subject: Subject

    private var countdown: (big: String, small: String) {
        let days = item.daysRemaining
        if days < 0 { return ("\(-days)", days == -1 ? "day late" : "days late") }
        if days == 0 { return ("Today", "due") }
        if days == 1 { return ("1", "day left") }
        return ("\(days)", "days left")
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Next up")
                    .font(.subheadline)
                    .bold()
                    .opacity(0.85)
                Text(item.title)
                    .font(.title2)
                    .bold()
                    .lineLimit(2)
                Label("\(subject.name) · \(item.type.rawValue)", systemImage: subject.icon)
                    .font(.subheadline)
                if !item.steps.isEmpty {
                    ProgressView(value: Double(item.stepsDone), total: Double(item.steps.count))
                        .tint(.white)
                        .frame(maxWidth: 180)
                }
            }

            Spacer(minLength: 8)

            VStack(spacing: 0) {
                Text(countdown.big)
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(countdown.small)
                    .font(.caption)
                    .bold()
            }
            .frame(minWidth: 80)
        }
        .foregroundStyle(.white)
        .padding(20)
        .background(
            LinearGradient(colors: [subject.color, subject.color.opacity(0.65)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .overlay(Color.black.opacity(0.12))
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: subject.color.opacity(0.35), radius: 10, y: 5)
    }
}

struct FilterChip: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.caption)
                .bold()
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isSelected ? color : Theme.surface)
                .foregroundStyle(isSelected ? (color.prefersDarkText ? Theme.onAccent : Color.white) : Color.primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(BrandButtonStyle())
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }
}
