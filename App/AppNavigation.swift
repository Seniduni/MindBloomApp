import SwiftUI

enum AppTab: Hashable {
    case today, journal, habits, insights, settings
}

/// Destinations pushed onto the Today tab's `NavigationStack`.
enum TodayRoute: Hashable {
    case moodCheckIn
    case moodHistory
    case breathing
    case focus
}

/// Shared navigation state, so any screen can switch tab or push a route
/// (e.g. the Today dashboard's "Journal" shortcut switches tabs).
@Observable
final class AppNavigation {
    var selectedTab: AppTab = .today
    var todayPath: [TodayRoute] = []

    func open(_ route: TodayRoute) {
        selectedTab = .today
        todayPath.append(route)
    }
}
