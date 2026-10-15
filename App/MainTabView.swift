import SwiftUI

/// Five top-level areas. `.sidebarAdaptable` shows a tab bar on iPhone and
/// a sidebar-capable layout on iPad.
struct MainTabView: View {
    @Environment(AppNavigation.self) private var navigation

    var body: some View {
        @Bindable var navigation = navigation
        TabView(selection: $navigation.selectedTab) {
            Tab("Today", systemImage: "sun.horizon", value: AppTab.today) {
                NavigationStack(path: $navigation.todayPath) {
                    TodayView()
                        .navigationDestination(for: TodayRoute.self) { route in
                            switch route {
                            case .moodCheckIn: MoodCheckInView()
                            case .moodHistory: MoodHistoryView()
                            case .breathing: BreathingView()
                            case .focus: FocusTimerView()
                            }
                        }
                }
            }

            Tab("Journal", systemImage: "book.pages", value: AppTab.journal) {
                JournalListView()
            }

            Tab("Habits", systemImage: "checklist", value: AppTab.habits) {
                HabitsView()
            }

            Tab("Insights", systemImage: "chart.line.uptrend.xyaxis", value: AppTab.insights) {
                InsightsView()
            }

            Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                SettingsView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}
