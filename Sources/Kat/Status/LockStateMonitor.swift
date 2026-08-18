import CoreGraphics
import Foundation

/// Tracks whether a password is *actually* required right now — not just whether the
/// screensaver/lock screen UI is showing. Three direct signals were tried and rejected,
/// since all of them reflect "the lock screen UI is visible" rather than "a password is
/// now required": the `com.apple.screenIsLocked` distributed notification,
/// `IsSecureEventInputEnabled()`, and `CGSessionCopyCurrentDictionary()`'s
/// `CGSSessionScreenIsLocked` key. macOS doesn't appear to expose the post-screensaver
/// "require password after N seconds" grace period as queryable state anywhere — it's
/// seemingly pure client-side UI timing inside the lock screen itself.
///
/// So this computes it instead: `CGSSessionScreenIsLocked` reliably fires the moment the
/// screensaver/lock UI engages, so that timestamp plus the user's configured grace period
/// (matching System Settings → Lock Screen → "Require password after screen saver
/// begins", surfaced as `SettingsStore.lockGracePeriodSeconds`) gives the real answer.
@MainActor
final class LockStateMonitor {
    private(set) var isLocked: Bool = false

    var onChange: ((Bool) -> Void)?
    var gracePeriodSecondsProvider: () -> Int = { 5 }
    /// Fired the moment the screensaver/lock UI actually disengages — i.e. the user is
    /// genuinely back — used to clear the "break over" sticky message on the screensaver.
    var onScreensaverDisengaged: (() -> Void)?

    private var screensaverEngagedAt: Date?
    private var wasScreensaverEngaged = false

    nonisolated(unsafe) private var timer: Timer?

    init() {
        startPolling()
    }

    deinit {
        timer?.invalidate()
    }

    private func startPolling() {
        poll()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func poll() {
        let now = Date()
        let screensaverEngaged = Self.querySessionScreenSaverEngaged()

        if screensaverEngaged {
            if screensaverEngagedAt == nil {
                screensaverEngagedAt = now
            }
        } else {
            screensaverEngagedAt = nil
            if wasScreensaverEngaged {
                onScreensaverDisengaged?()
            }
        }
        wasScreensaverEngaged = screensaverEngaged

        let locked: Bool
        if let screensaverEngagedAt {
            locked = now.timeIntervalSince(screensaverEngagedAt) >= TimeInterval(gracePeriodSecondsProvider())
        } else {
            locked = false
        }

        guard locked != isLocked else { return }
        isLocked = locked
        onChange?(locked)
    }

    private static func querySessionScreenSaverEngaged() -> Bool {
        guard let info = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        return (info["CGSSessionScreenIsLocked"] as? Bool) ?? false
    }
}
