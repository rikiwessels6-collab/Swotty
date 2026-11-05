import SwiftUI

// MARK: - Today card (top of the Planner)
// The next class, and a shortcut to notes waiting for review.
struct TodayCard: View {
    @EnvironmentObject private var store: StudyStore
    let onShowReview: () -> Void

    @State private var now = Date()
    private let ticker = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    // The class on now, or the next one still to come today.
    private var upcoming: Lesson? {
        let weekday = Calendar.current.component(.weekday, from: now)
        let minutes = Lesson.minutes(from: now)
        return store.lessons(on: weekday).first { $0.endMinutes > minutes }
    }

    private var pendingCount: Int { store.pendingReviewNotes.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let lesson = upcoming {
                let subject = store.subject(for: lesson.subjectID)
                HStack(spacing: 12) {
                    Image(systemName: subject.icon)
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(subject.color)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(lesson.isOnNow(at: now) ? "Class now" : "Next class")
                            .font(.caption)
                            .bold()
                            .foregroundStyle(.secondary)
                        Text(subject.name)
                            .font(.headline)
                        Text([lesson.timeRange, lesson.details]
                            .filter { !$0.isEmpty }
                            .joined(separator: " · "))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }
            }

            if pendingCount > 0 {
                Button(action: onShowReview) {
                    Label(pendingCount == 1 ? "1 note to review" : "\(pendingCount) notes to review",
                          systemImage: "checklist")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.vertical, 4)
        .onReceive(ticker) { now = $0 }
    }
}
