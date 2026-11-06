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
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("appearance") private var appearance: AppearanceMode = .dark
    @AppStorage("accentColour") private var accent: SubjectColour = .gold

    init() {
        Theme.configureAppearance()
        Self.migrateTheme()
    }

    // The navy & gold redesign makes gold the default accent. Anyone still on the
    // old default (indigo) is moved across once; a colour they chose is kept.
    private static func migrateTheme() {
        let defaults = UserDefaults.standard
        guard defaults.integer(forKey: "themeVersion") < 2 else { return }
        if defaults.string(forKey: "accentColour") == "indigo" {
            defaults.set("gold", forKey: "accentColour")
        }
        defaults.set(2, forKey: "themeVersion")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .preferredColorScheme(appearance.colorScheme)
                .tint(accent.color)            // buttons, toggles, tab bar
                .onChange(of: scenePhase) { phase in
                    // Week A / Week B reminders are planned a fortnight ahead,
                    // so top them up whenever the app comes back to the front.
                    if phase == .active {
                        store.refreshClassReminders()
                    }
                }
        }
    }
}
