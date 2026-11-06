import WidgetKit
import SwiftUI

// MARK: - Look (navy and gold, matching the app)
private enum WidgetPalette {
    static let navy = Color(red: 0x0A / 255, green: 0x15 / 255, blue: 0x24 / 255)
    static let navyLight = Color(red: 0x1B / 255, green: 0x30 / 255, blue: 0x50 / 255)
    static let gold = Color(red: 0xE3 / 255, green: 0xB2 / 255, blue: 0x5A / 255)
    static let emerald = Color(red: 0x2D / 255, green: 0xC4 / 255, blue: 0x8D / 255)
}

private extension View {
    // iOS 17 needs containerBackground; earlier versions use a plain background.
    @ViewBuilder
    func widgetBackground<Background: View>(_ background: Background) -> some View {
        if #available(iOS 17.0, *) {
            self.containerBackground(for: .widget) { background }
        } else {
            self.background(background)
        }
    }
}

private func serif(_ style: Font.TextStyle) -> Font {
    .system(style, design: .serif).weight(.semibold)
}

// MARK: - Entry point
struct TimetableWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TimetableEntry

    private var background: some View {
        LinearGradient(colors: [WidgetPalette.navyLight, WidgetPalette.navy],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        switch family {
        case .accessoryRectangular:
            AccessoryRectangularView(entry: entry)
                .widgetBackground(Color.clear)
        case .accessoryInline:
            AccessoryInlineView(entry: entry)
                .widgetBackground(Color.clear)
        case .systemMedium:
            MediumView(entry: entry)
                .widgetBackground(background)
        default:
            SmallView(entry: entry)
                .widgetBackground(background)
        }
    }
}

// MARK: - Shared pieces
private struct MessageView: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(WidgetPalette.gold)
            Text(title)
                .font(serif(.subheadline))
                .foregroundStyle(.white)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(4)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private func stateMessage(for entry: TimetableEntry) -> MessageView? {
    switch entry.state {
    case .needsAccess:
        return MessageView(icon: "calendar.badge.exclamationmark",
                           title: "Allow Calendar",
                           detail: "Open Swotty and turn on Settings → Calendar Sync.")
    case .notSynced:
        return MessageView(icon: "calendar.badge.plus",
                           title: "Add your timetable",
                           detail: "In Swotty: Settings → Calendar Sync → Add timetable to Calendar.")
    case .ready:
        return nil
    }
}

private func isNow(_ item: WidgetClass, at date: Date) -> Bool {
    item.start <= date && item.end > date
}

// MARK: - Small
private struct SmallView: View {
    let entry: TimetableEntry

    var body: some View {
        if let message = stateMessage(for: entry) {
            message
        } else if let current = entry.classes.first,
                  Calendar.current.isDate(current.start, inSameDayAs: entry.date) || isNow(current, at: entry.date) {
            VStack(alignment: .leading, spacing: 4) {
                Text(isNow(current, at: entry.date) ? "NOW" : "NEXT")
                    .font(.caption2.bold())
                    .foregroundStyle(WidgetPalette.gold)
                Text(current.title)
                    .font(serif(.title3))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text(current.timeRange)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                if !current.room.isEmpty {
                    Label(current.room, systemImage: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if entry.classes.count > 1,
                   Calendar.current.isDate(entry.classes[1].start, inSameDayAs: entry.date) {
                    let after = entry.classes[1]
                    Text("Then \(after.title) \(after.start.formatted(date: .omitted, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(WidgetPalette.emerald)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title2)
                    .foregroundStyle(WidgetPalette.emerald)
                Text("Classes done")
                    .font(serif(.headline))
                    .foregroundStyle(.white)
                if let next = entry.classes.first {
                    Text("Tomorrow: \(next.title) \(next.start.formatted(date: .omitted, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(3)
                }
                Spacer(minLength: 0)
                if let due = entry.due.first {
                    Label(due.title, systemImage: "flag.fill")
                        .font(.caption2)
                        .foregroundStyle(WidgetPalette.gold)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Medium
private struct MediumView: View {
    let entry: TimetableEntry

    private var todaysClasses: [WidgetClass] {
        entry.classes.filter { Calendar.current.isDate($0.start, inSameDayAs: entry.date) }
    }

    var body: some View {
        if let message = stateMessage(for: entry) {
            message
        } else {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.date.formatted(.dateTime.weekday(.wide)).uppercased())
                        .font(.caption2.bold())
                        .foregroundStyle(WidgetPalette.gold)
                    if todaysClasses.isEmpty {
                        Text("No more classes today")
                            .font(serif(.subheadline))
                            .foregroundStyle(.white)
                    } else {
                        ForEach(todaysClasses.prefix(3)) { item in
                            HStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(isNow(item, at: entry.date) ? WidgetPalette.gold : WidgetPalette.emerald)
                                    .frame(width: 3, height: 30)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(item.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                    Text([item.start.formatted(date: .omitted, time: .shortened), item.room]
                                        .filter { !$0.isEmpty }.joined(separator: " · "))
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.7))
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 6) {
                    Text("DUE SOON")
                        .font(.caption2.bold())
                        .foregroundStyle(WidgetPalette.gold)
                    if entry.due.isEmpty {
                        Text("Nothing due")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    } else {
                        ForEach(entry.due.prefix(3)) { item in
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                                Text(item.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - Lock screen
private struct AccessoryRectangularView: View {
    let entry: TimetableEntry

    var body: some View {
        if entry.state != .ready {
            Text("Add your timetable to Calendar in Swotty")
                .font(.caption)
        } else if let current = entry.classes.first {
            VStack(alignment: .leading, spacing: 1) {
                Text(isNow(current, at: entry.date) ? "Now" : "Next")
                    .font(.caption2.bold())
                Text(current.title)
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
    let entry: TimetableEntry

    var body: some View {
        if entry.state != .ready {
            Text("Swotty: add timetable")
        } else if let current = entry.classes.first {
            Text("\(current.title) \(current.start.formatted(date: .omitted, time: .shortened))")
        } else {
            Text("No classes")
        }
    }
}
