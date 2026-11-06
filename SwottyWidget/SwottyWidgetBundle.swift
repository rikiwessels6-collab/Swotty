import WidgetKit
import SwiftUI

@main
struct SwottyWidgetBundle: WidgetBundle {
    var body: some Widget {
        TimetableWidget()
    }
}

struct TimetableWidget: Widget {
    let kind = "SwottyTimetableWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TimetableProvider()) { entry in
            TimetableWidgetView(entry: entry)
        }
        .configurationDisplayName("Swotty Timetable")
        .description("See your class now or next, today's timetable, and what's due.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}
