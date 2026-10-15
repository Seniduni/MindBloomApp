import SwiftUI

/// Chooses onboarding or the main app, and applies app-wide preferences
/// (appearance, motion, accent colour).
struct RootView: View {
    var storeWarning: String? = nil

    @AppStorage(SettingsKey.hasCompletedOnboarding) private var hasCompletedOnboarding = false
    @AppStorage(SettingsKey.appearance) private var appearance = AppearancePreference.system.rawValue
    @AppStorage(SettingsKey.calmMotion) private var calmMotion = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    private var colorScheme: ColorScheme? {
        switch AppearancePreference(rawValue: appearance) ?? .system {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                MainTabView()
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .safeAreaInset(edge: .top) {
            if let storeWarning {
                Text(storeWarning)
                    .font(.footnote)
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .background(Theme.sun.opacity(0.25))
            }
        }
        .tint(Theme.teal)
        .preferredColorScheme(colorScheme)
        .environment(\.bloomReduceMotion, systemReduceMotion || calmMotion)
        .animation(systemReduceMotion || calmMotion ? nil : .easeInOut(duration: 0.4), value: hasCompletedOnboarding)
    }
}
