import Foundation
import UserNotifications

/// Local notifications only (no server). Used for an optional daily check-in
/// reminder and a "focus session finished" alert when the app is in the background.
enum ReminderService {
    static let dailyIdentifier = "mindbloom.daily-checkin"
    static let focusIdentifier = "mindbloom.focus-finished"

    /// Asks for permission the first time; afterwards returns the stored decision.
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        default:
            return false
        }
    }

    static func isAuthorized() async -> Bool {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        return status == .authorized || status == .provisional || status == .ephemeral
    }

    static func scheduleDailyCheckIn(hour: Int, minute: Int) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [dailyIdentifier])
        let content = UNMutableNotificationContent()
        content.title = "A gentle check-in"
        content.body = "How are you feeling right now? It only takes a moment."
        content.sound = .default
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        try? await center.add(UNNotificationRequest(identifier: dailyIdentifier, content: content, trigger: trigger))
    }

    static func cancelDailyCheckIn() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [dailyIdentifier])
    }

    /// Only scheduled if the student has already allowed notifications.
    static func scheduleFocusFinished(at date: Date) async {
        guard await isAuthorized() else { return }
        let interval = date.timeIntervalSinceNow
        guard interval > 1 else { return }
        let content = UNMutableNotificationContent()
        content.title = "Focus session complete"
        content.body = "Nice work. Take a short break before the next one."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        try? await UNUserNotificationCenter.current()
            .add(UNNotificationRequest(identifier: focusIdentifier, content: content, trigger: trigger))
    }

    static func cancelFocusFinished() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [focusIdentifier])
    }
}
