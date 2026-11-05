import SwiftUI

// The app's name. Change it here and it updates the
// Settings screen, the Calendar app and calendar events.
// (The name under the icon is set in project.yml / App Settings.)
let appName = "Swotty"
let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"

// MARK: - App launcher
@main
struct SwottyApp: App {
    @StateObject private var store = StudyStore()
    @AppStorage("appearance") private var appearance: AppearanceMode = .system
    @AppStorage("accentColour") private var accent: SubjectColour = .indigo

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .preferredColorScheme(appearance.colorScheme)
                .tint(accent.color)            // buttons, toggles, tab bar
                .fontDesign(.rounded)          // softer, friendlier text
        }
    }
}
