import Foundation
import WidgetKit

// Writes the shared snapshot for the widget and asks it to refresh.
enum WidgetSync {
    private static var pending: DispatchWorkItem?

    // A moment from now, so several quick changes become one update.
    static func schedule(_ snapshot: WidgetSnapshot) {
        pending?.cancel()
        let item = DispatchWorkItem { write(snapshot) }
        pending = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: item)
    }

    // Right away (used when the app is about to go to the background).
    static func flush(_ snapshot: WidgetSnapshot) {
        pending?.cancel()
        write(snapshot)
    }

    private static func write(_ snapshot: WidgetSnapshot) {
        snapshot.write()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
