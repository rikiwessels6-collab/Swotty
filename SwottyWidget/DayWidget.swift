import WidgetKit
import SwiftUI

// MARK: - Day timetable widget
// The day's classes with coloured dots and period numbers. Once the last class
// is over it shows the next day that has classes.
struct DayEntry: TimelineEntry {
    let date: Date
    let ready: Bool
    let dayDate: Date          // the day being shown
    let isToday: Bool
    let classes: [DayClass]    // that day's classes, earliest first
    let weekType: Int?         // 1 = Week A, 2 = Week B, nil = same every week
}

struct DayProvider: TimelineProvider {
    func placeholder(in context: Context) -> DayEntry {
        sample()
    }

    func getSnapshot(in context: Context, completion: @escaping (DayEntry) -> Void) {
        if context.isPreview {
            completion(sample())
        } else {
            completion(entry(at: Date(), content: WidgetLoader.load(now: Date())))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DayEntry>) -> Void) {
        let now = Date()
        let content = WidgetLoader.load(now: now)
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)

        // A new entry at each class start and end today and tomorrow, and at
        // midnight, so the widget moves on by itself.
        var moments: Set<Date> = [now]
        for offset in 0...1 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startOfToday) else { continue }
            for item in content.classes(on: day) {
                if item.start > now { moments.insert(item.start) }
                if item.end > now { moments.insert(item.end) }
            }
        }
        if let midnight = calendar.date(byAdding: .day, value: 1, to: startOfToday) {
            moments.insert(midnight)
        }

        let entries = Array(moments.sorted().prefix(20)).map { entry(at: $0, content: content) }
        let refresh = calendar.date(byAdding: .hour, value: 3, to: now) ?? now.addingTimeInterval(10_800)
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }

    // What to show at a given moment.
    private func entry(at moment: Date, content: WidgetContent) -> DayEntry {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: moment)
        var day = today
        var classes = content.classes(on: day)

        // Today is over (or empty): show the next day that has classes.
        if classes.allSatisfy({ $0.end <= moment }) {
            for offset in 1...7 {
                guard let next = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
                let list = content.classes(on: next)
                if !list.isEmpty {
                    day = next
                    classes = list
                    break
                }
            }
        }
        return DayEntry(date: moment, ready: content.ready, dayDate: day,
                        isToday: calendar.isDate(day, inSameDayAs: moment),
                        classes: classes, weekType: content.weekType(for: day))
    }

    private func sample() -> DayEntry {
        let now = Date()
        func make(_ index: Int, _ title: String, _ color: UInt32, _ minutes: Int, _ room: String) -> DayClass {
            DayClass(id: "\(index)", title: title, colorHex: color,
                     start: now.addingTimeInterval(Double(minutes) * 60),
                     end: now.addingTimeInterval(Double(minutes + 45) * 60),
                     room: room, teacher: "", period: index)
        }
        return DayEntry(date: now, ready: true, dayDate: now, isToday: true,
                        classes: [make(1, "Maths", 0xD1495B, -50, "R1.02"),
                                  make(2, "English", 0x9A5FC0, 5, "R2.04"),
                                  make(3, "Science", 0x2FA77B, 60, "Lab 3"),
                                  make(5, "History", 0xE08E45, 130, "R1.10")],
                        weekType: nil)
    }
}

struct DayTimetableWidget: Widget {
    let kind = "SwottyDayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DayProvider()) { entry in
            DayWidgetView(entry: entry)
        }
        .configurationDisplayName("Day Timetable")
        .description("Today's classes with their periods, and what's next.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge,
                            .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Views
struct DayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DayEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            AccessoryRectangularView(entry: entry)
                .widgetBackground(Color.clear)
        case .accessoryInline:
            AccessoryInlineView(entry: entry)
                .widgetBackground(Color.clear)
        case .systemMedium:
            DayListView(entry: entry, maxRows: 4, showTimes: true, showTeacher: false)
                .widgetBackground(WidgetBackground())
        case .systemLarge:
            DayListView(entry: entry, maxRows: 8, showTimes: true, showTeacher: true)
                .widgetBackground(WidgetBackground())
        default:
            DayListView(entry: entry, maxRows: 4, showTimes: false, showTeacher: false)
                .widgetBackground(WidgetBackground())
        }
    }
}

private func isNow(_ item: DayClass, at date: Date) -> Bool {
    item.start <= date && item.end > date
}

private struct DayListView: View {
    let entry: DayEntry
    let maxRows: Int
    let showTimes: Bool
    let showTeacher: Bool

    private var title: String {
        entry.dayDate.formatted(.dateTime.weekday(.wide))
    }

    // Keep the class on now and what's next in view when there are too many to show.
    private var visible: [DayClass] {
        let classes = entry.classes
        guard classes.count > maxRows else { return classes }
        let firstUpcoming = classes.firstIndex { $0.end > entry.date } ?? 0
        let start = max(0, min(firstUpcoming, classes.count - maxRows))
        return Array(classes[start..<(start + maxRows)])
    }

    var body: some View {
        if !entry.ready {
            SetupMessage()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    TitlePill(text: title)
                    if let type = entry.weekType {
                        WeekPill(type: type)
                    }
                    Spacer(minLength: 0)
                    if !entry.isToday {
                        Text("Next up")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                if entry.classes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.title3)
                            .foregroundStyle(WidgetPalette.emerald)
                        Text("No classes")
                            .font(serif(.subheadline))
                            .foregroundStyle(.white)
                    }
                } else {
                    VStack(alignment: .leading, spacing: showTeacher ? 9 : 6) {
                        ForEach(visible) { item in
                            row(item)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func row(_ item: DayClass) -> some View {
        let finished = item.end <= entry.date
        let current = isNow(item, at: entry.date)
        return HStack(spacing: 8) {
            Circle()
                .fill(Color(hex: item.colorHex))
                .frame(width: 9, height: 9)
            if item.period > 0 {
                Text("\(item.period)")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(minWidth: 10)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.system(.subheadline).weight(.semibold))
                    .foregroundStyle(current ? WidgetPalette.gold : Color.white)
                    .lineLimit(1)
                if showTimes && (!item.room.isEmpty || showTeacher) {
                    Text([item.room, showTeacher ? item.teacher : ""].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if showTimes {
                Text(item.startText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(current ? WidgetPalette.gold : Color.white.opacity(0.75))
            }
        }
        .opacity(finished ? 0.4 : 1)
    }
}

// MARK: - Lock Screen
private struct AccessoryRectangularView: View {
    let entry: DayEntry

    private var upcoming: DayClass? {
        entry.classes.first { $0.end > entry.date }
    }

    var body: some View {
        if !entry.ready {
            Text("Open Swotty to set up")
                .font(.caption)
        } else if let current = upcoming {
            VStack(alignment: .leading, spacing: 1) {
                Text(isNow(current, at: entry.date) ? "Now" : "Next")
                    .font(.caption2.bold())
                Text(current.period > 0 ? "\(current.period)  \(current.title)" : current.title)
                    .font(.headline)
                    .lineLimit(1)
                Text([current.timeRange, current.room].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption2)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text("No classes")
                .font(.headline)
        }
    }
}

private struct AccessoryInlineView: View {
    let entry: DayEntry

    var body: some View {
        if !entry.ready {
            Text("Swotty: open to set up")
        } else if let current = entry.classes.first(where: { $0.end > entry.date }) {
            Text("\(current.title) \(current.startText)")
        } else {
            Text("No classes")
        }
    }
}
