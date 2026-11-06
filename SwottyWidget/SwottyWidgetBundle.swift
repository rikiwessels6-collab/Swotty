import WidgetKit
import SwiftUI

@main
struct SwottyWidgetBundle: WidgetBundle {
    var body: some Widget {
        DayTimetableWidget()
        TasksWidget()
    }
}
