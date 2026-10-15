import Foundation
import SwiftData

/// Launch arguments understood by the app. UI tests pass these so every test run
/// starts from a clean, predictable state without touching real data.
enum LaunchArgument {
    /// Use an in-memory store and clear saved preferences.
    static let uiTesting = "-ui-testing"
    /// Skip onboarding (implies the disclaimer has been acknowledged).
    static let skipOnboarding = "-skip-onboarding"
    /// Load the deterministic sample data at launch.
    static let seedSampleData = "-seed-sample-data"
}

/// Keys for small preferences kept in `UserDefaults` via `@AppStorage`.
enum SettingsKey {
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let appearance = "appearance"
    static let calmMotion = "calmMotion"
    static let hapticsEnabled = "hapticsEnabled"
    static let journalInsightsEnabled = "journalInsightsEnabled"
    static let dailyReminderEnabled = "dailyReminderEnabled"
    static let dailyReminderMinutes = "dailyReminderMinutes"
    static let focusTimerState = "focusTimerState"
    static let focusIntention = "focusIntention"
}

enum AppearancePreference: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

/// Builds the long-lived objects the app needs before the first view appears.
@MainActor
final class AppBootstrap {
    let container: ModelContainer
    let navigation = AppNavigation()
    /// Shown as a banner if the on-disk store could not be opened.
    let storeWarning: String?

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        let isUITesting = arguments.contains(LaunchArgument.uiTesting)
        let defaults = UserDefaults.standard

        if isUITesting, let domain = Bundle.main.bundleIdentifier {
            defaults.removePersistentDomain(forName: domain)
        }
        if arguments.contains(LaunchArgument.skipOnboarding) {
            defaults.set(true, forKey: SettingsKey.hasCompletedOnboarding)
        }

        var warning: String?
        do {
            container = try PersistenceController.makeContainer(inMemory: isUITesting)
        } catch {
            // Last resort: keep the app usable for this session rather than crashing.
            warning = "Your saved data could not be opened, so changes this session won't be kept. (\(error.localizedDescription))"
            do {
                container = try PersistenceController.makeContainer(inMemory: true)
            } catch {
                fatalError("Unable to create even an in-memory store: \(error)")
            }
        }
        storeWarning = warning

        if arguments.contains(LaunchArgument.seedSampleData) {
            try? DemoDataService.loadSampleData(into: container.mainContext)
        }
    }
}
