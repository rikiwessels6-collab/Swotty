import SwiftUI

// MARK: - Tabs
struct ContentView: View {
    @EnvironmentObject private var store: StudyStore
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @State private var showWelcome = false

    var body: some View {
        TabView {
            PlannerView()
                .tabItem { Label("Planner", systemImage: "checklist") }
            ScheduleView()
                .tabItem { Label("Schedule", systemImage: "calendar") }
            FocusTimerView()
                .tabItem { Label("Focus", systemImage: "timer") }
            ResultsView()
                .tabItem { Label("Results", systemImage: "chart.bar.fill") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .onAppear {
            // Existing users already have data, so they never see the welcome.
            if !hasOnboarded {
                if store.items.isEmpty && store.lessons.isEmpty {
                    showWelcome = true
                } else {
                    hasOnboarded = true
                }
            }
        }
        .fullScreenCover(isPresented: $showWelcome) {
            OnboardingView {
                hasOnboarded = true
                showWelcome = false
            }
            .environmentObject(store)
        }
    }
}
