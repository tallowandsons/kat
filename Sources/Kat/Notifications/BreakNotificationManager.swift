import Foundation
import UserNotifications

/// Fires a single heads-up notification ~1 minute before each scheduled break, kept in
/// sync by rescheduling whenever `BreakScheduler.nextBreakDate` changes (postpone, skip,
/// pause/resume, or the natural post-break recompute all flow through the same path).
@MainActor
final class BreakNotificationManager {
    private static let identifier = "com.tallowandsons.kat.upcoming-break"
    private static let leadTime: TimeInterval = 60

    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                Log.notifications.error("Authorization error: \(error.localizedDescription, privacy: .public)")
            } else {
                Log.notifications.info("Authorization granted: \(granted, privacy: .public)")
            }
        }
    }

    func scheduleHeadsUp(for nextBreakDate: Date?) {
        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])

        guard let nextBreakDate else { return }
        let interval = nextBreakDate.addingTimeInterval(-Self.leadTime).timeIntervalSinceNow
        guard interval > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Break starting soon"
        content.body = "Your break starts in about a minute."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: Self.identifier, content: content, trigger: trigger)
        center.add(request) { error in
            if let error {
                Log.notifications.error("Failed to schedule: \(error.localizedDescription, privacy: .public)")
            } else {
                Log.notifications.info("Scheduled heads-up in \(interval, privacy: .public)s")
            }
        }
    }
}
