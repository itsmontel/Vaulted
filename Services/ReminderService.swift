import UserNotifications
import Foundation

// MARK: - ReminderService
/// Schedules and cancels local notifications for card reminders.
final class ReminderService {
    static let shared = ReminderService()

    private let center = UNUserNotificationCenter.current()

    private init() {}

    /// Requests notification authorization if not already granted.
    func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized: return true
        case .denied: return false
        case .notDetermined, .provisional, .ephemeral:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        @unknown default: return false
        }
    }

    /// Schedules a reminder for a card at the given date.
    /// - Parameters:
    ///   - cardId: Stable identifier (e.g. uuid string) for the card
    ///   - title: Card title for the notification body
    ///   - date: When to fire the reminder
    func scheduleReminder(cardId: String, title: String, date: Date) async {
        let granted = await requestAuthorizationIfNeeded()
        guard granted else { return }

        let content = UNMutableNotificationContent()
        content.title = "Reminder"
        content.body = title.isEmpty ? "You have a note to follow up on" : title
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: notificationId(for: cardId), content: content, trigger: trigger)
        try? await center.add(request)
    }

    /// Cancels any scheduled reminder for the card.
    func cancelReminder(cardId: String) {
        center.removePendingNotificationRequests(withIdentifiers: [notificationId(for: cardId)])
    }

    private func notificationId(for cardId: String) -> String {
        "vaulted.reminder.\(cardId)"
    }
}
