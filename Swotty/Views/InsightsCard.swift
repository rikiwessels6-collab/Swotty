import SwiftUI

// MARK: - Heads-up card on the Planner
// Next exam countdown with a revision plan, and busy-week warnings.
struct InsightsCard: View {
    @EnvironmentObject private var store: StudyStore

    static func hasContent(_ items: [Assessment]) -> Bool {
        Insights.nextExam(items) != nil || !Insights.busyWeeks(items).isEmpty
    }

    private func dayText(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let exam = Insights.nextExam(store.items) {
                let subject = store.subject(for: exam)
                let days = exam.daysRemaining
                VStack(alignment: .leading, spacing: 6) {
                    Label("\(subject.name) \(exam.type.rawValue.lowercased()) \(Insights.countdownText(days: days))",
                          systemImage: "hourglass")
                        .font(.headline)
                        .foregroundStyle(Theme.gold)
                    let plan = Insights.revisionDays(for: exam)
                    if !plan.isEmpty {
                        Text("Suggested revision")
                            .font(.caption).bold()
                            .foregroundStyle(.secondary)
                        ForEach(plan, id: \.self) { date in
                            Label(dayText(date), systemImage: "book.closed")
                                .font(.subheadline)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
            }

            ForEach(Insights.busyWeeks(store.items), id: \.start) { week in
                Label("Busy week: \(week.count) things due in the week of \(dayText(week.start))",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                    .accessibilityElement(children: .combine)
            }
        }
        .premiumCard()
    }
}
