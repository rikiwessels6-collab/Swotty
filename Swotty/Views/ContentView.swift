import SwiftUI

// MARK: - Tabs
struct ContentView: View {
    var body: some View {
        TabView {
            PlannerView()
                .tabItem { Label("Planner", systemImage: "checklist") }
            MonthCalendarView()
                .tabItem { Label("Calendar", systemImage: "calendar") }
            FocusTimerView()
                .tabItem { Label("Focus", systemImage: "timer") }
            ResultsView()
                .tabItem { Label("Results", systemImage: "chart.bar.fill") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
    }
}
