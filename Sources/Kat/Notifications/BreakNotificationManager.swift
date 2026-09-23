import Foundation
import UserNotifications

/// Fires a single heads-up notification ~1 minute before each scheduled break, kept in
/// sync by re-arming whenever `BreakScheduler.nextBreakDate` changes (postpone, skip,
/// pause/resume, or the natural post-break recompute all flow through the same path).
///
/// Presentation isn't pre-scheduled via a system `UNNotificationTrigger` — that fires
/// blind to anything that happens after it's armed. Instead this re-checks every second,
/// same as `BreakScheduler.tick()`'s own camera gate, so a break silently deferred by the
/// camera doesn't still get a "starting soon" notification for a break that isn't
/// starting soon.
@MainActor
final class BreakNotificationManager {
    private static let identifier = "com.tallowandsons.kat.upcoming-break"
    private static let leadTime: TimeInterval = 60

    private let center = UNUserNotificationCenter.current()

    var isCameraGateEnabled: () -> Bool = { true }
    var isCameraInUse: () -> Bool = { false }

    private var nextBreakDate: Date?
    /// The `nextBreakDate` we've already presented a heads-up for, so a once-a-second
    /// re-check doesn't re-fire it every tick once it's in the window.
    private var firedForBreakDate: Date?

    // Same nonisolated(unsafe)-Timer pattern as BreakScheduler/CameraMonitor/LockStateMonitor.
    nonisolated(unsafe) private var timer: Timer?

    init() {
        startTicking()
    }

    deinit {
        timer?.invalidate()
    }

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
        if nextBreakDate != self.nextBreakDate {
            firedForBreakDate = nil
        }
        self.nextBreakDate = nextBreakDate
    }

    private func startTicking() {
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        guard let nextBreakDate, firedForBreakDate != nextBreakDate else { return }

        let now = Date()
        let fireAt = nextBreakDate.addingTimeInterval(-Self.leadTime)
        guard now >= fireAt else { return }

        // Past the break's own due time (camera has been holding it off past nextBreakDate
        // itself) -- too late for a "starting soon" heads-up to make sense; give up on this
        // occurrence rather than firing a stale one once the camera eventually clears.
        guard now < nextBreakDate else {
            firedForBreakDate = nextBreakDate
            return
        }

        if isCameraGateEnabled(), isCameraInUse() {
            // Deferred, not skipped: re-checked every tick, same as BreakScheduler.tick().
            return
        }

        firedForBreakDate = nextBreakDate
        present()
    }

    private func present() {
        let content = UNMutableNotificationContent()
        content.title = "Break starting soon"
        content.body = "Your break starts in about a minute."
        content.sound = .default

        let request = UNNotificationRequest(identifier: Self.identifier, content: content, trigger: nil)
        center.add(request) { error in
            if let error {
                Log.notifications.error("Failed to present: \(error.localizedDescription, privacy: .public)")
            } else {
                Log.notifications.info("Presented heads-up notification")
            }
        }
    }
}
