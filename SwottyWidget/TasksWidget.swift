import WidgetKit
import SwiftUI

// MARK: - Tasks widget
// What's due: overdue, today, tomorrow and the days after, each with the
// subject as a coloured chip.
struct TasksEntry: TimelineEntry {
    let date: Date
    let ready: Bool
    let overdue: [TaskItem]
    let today: [TaskItem]
    let tomorrow: [TaskItem]
    let later: [TaskItem]
}

struct TasksProvider: TimelineProvider {
    func placeholder(in context: Context) -> TasksEntry {
        sample()
    }

    func getSnapshot(in context: Context, completion: @escaping (TasksEntry) -> Void) {
        if context.isPreview {
            completion(sample())
        } else {
            completion(entry(at: Date(), content: WidgetLoader.load(now: Date())))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TasksEntry>) -> Void) {
        let now = Date()
        let content = WidgetLoader.load(now: now)
        let calendar = Calendar.current

        // Re-sort at midnight (today becomes yesterday), and top up every few hours.
        var moments: [Date] = [now]
        if let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) {
            moments.append(midnight)
        }
        let entries = moments.map { entry(at: $0, content: content) }
        let refresh = calendar.date(byAdding: .hour, value: 3, to: now) ?? now.addingTimeInterval(10_800)
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }

    private func entry(at moment: Date, content: WidgetContent) -> TasksEntry {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: moment)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let dayAfter = calendar.date(byAdding: .day, value: 2, to: today) ?? tomorrow

        let tasks = content.tasks.sorted { $0.due < $1.due }
        return TasksEntry(
            date: moment,
            ready: content.ready,
            overdue: tasks.filter { $0.due < today },
            today: tasks.filter { calendar.isDate($0.due, inSameDayAs: today) },
            tomorrow: tasks.filter { calendar.isDate($0.due, inSameDayAs: tomorrow) },
            later: tasks.filter { $0.due >= dayAfter })
    }

    private func sample() -> TasksEntry {
        let now = Date()
        func task(_ id: String, _ title: String, _ subject: String, _ color: UInt32, _ days: Int) -> TaskItem {
            TaskItem(id: id, title: title, subjectName: subject, colorHex: color, typeName: "Exam",
                     due: Calendar.current.date(byAdding: .day, value: days, to: now) ?? now)
        }
        return TasksEntry(date: now, ready: true, overdue: [],
                          today: [task("1", "Algebra test", "Maths", 0xD1495B, 0),
                                  task("2", "Cells quiz", "Science", 0x2FA77B, 0)],
                          tomorrow: [task("3", "Persuasive essay", "English", 0x9A5FC0, 1)],
                          later: [])
    }
}

struct TasksWidget: Widget {
    let kind = "SwottyTasksWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TasksProvider()) { entry in
            TasksWidgetView(entry: entry)
        }
        .configurationDisplayName("Tasks")
        .description("Exams, assignments and quizzes due today and tomorrow.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

// MARK: - Views
private enum TaskLine: Identifiable {
    case header(String, Bool)     // title, is the "overdue" header
    case task(TaskItem)

    var id: String {
        switch self {
        case .header(let title, _): return "header-\(title)"
        case .task(let item): return item.id
        }
    }
}

struct TasksWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TasksEntry

    private var maxLines: Int { family == .systemLarge ? 9 : 4 }

    private var lines: [TaskLine] {
        var result: [TaskLine] = []
        func add(_ title: String, _ items: [TaskItem], overdue: Bool = false) {
            guard !items.isEmpty else { return }
            result.append(.header(title, overdue))
            items.forEach { result.append(.task($0)) }
        }
        add("Overdue", entry.overdue, overdue: true)
        add("Today", entry.today)
        add("Tomorrow", entry.tomorrow)
        add("Coming up", entry.later)

        var trimmed = Array(result.prefix(maxLines))
        // Don't end on a lonely header.
        if let last = trimmed.last, case .header = last { trimmed.removeLast() }
        return trimmed
    }

    var body: some View {
        Group {
            if !entry.ready {
                SetupMessage()
            } else if lines.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    TitlePill(text: "Due")
                    Spacer(minLength: 0)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title2)
                        .foregroundStyle(WidgetPalette.emerald)
                    Text("Nothing due")
                        .font(serif(.headline))
                        .foregroundStyle(.white)
                    Text("Enjoy the breathing space.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    TitlePill(text: "Due")
                    ForEach(lines) { line in
                        switch line {
                        case .header(let title, let overdue):
                            Text(title.uppercased())
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(overdue ? WidgetPalette.alert : WidgetPalette.gold)
                                .padding(.top, 2)
                        case .task(let item):
                            taskRow(item)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .widgetBackground(WidgetBackground())
    }

    private func taskRow(_ item: TaskItem) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                if !item.subjectName.isEmpty {
                    Text(item.subjectName)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.prefersDarkText(item.colorHex) ? WidgetPalette.navy : Color.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color(hex: item.colorHex)))
                }
                Text(item.title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Circle()
                .strokeBorder(Color(hex: item.colorHex), lineWidth: 2)
                .frame(width: 18, height: 18)
        }
    }
}
