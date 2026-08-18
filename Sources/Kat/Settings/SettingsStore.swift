import Foundation
import Observation

/// Persists all user-configurable settings to `UserDefaults`. Scalars use a plain key;
/// the four structured settings (schedule, custom buttons, on-start/on-end scripts) are
/// each JSON-encoded, since `UserDefaults` has no native support for Codable structs.
@MainActor
@Observable
final class SettingsStore {
    private enum Keys {
        static let postponeOnCameraUse = "postponeOnCameraUse"
        static let pauseMediaOnBreakStart = "pauseMediaOnBreakStart"
        static let lockGracePeriodSeconds = "lockGracePeriodSeconds"
        static let breakOverMessage = "breakOverMessage"
        static let scheduleConfig = "scheduleConfig"
        static let customButtons = "customButtons"
        static let onStartScripts = "onStartScripts"
        static let onEndScripts = "onEndScripts"
        static let hasShownWelcome = "hasShownWelcome"
    }

    @ObservationIgnored
    private let defaults: UserDefaults

    var postponeOnCameraUse: Bool {
        didSet { defaults.set(postponeOnCameraUse, forKey: Keys.postponeOnCameraUse) }
    }
    var pauseMediaOnBreakStart: Bool {
        didSet { defaults.set(pauseMediaOnBreakStart, forKey: Keys.pauseMediaOnBreakStart) }
    }
    /// Should match System Settings → Lock Screen → "Require password after screen saver
    /// begins" — macOS doesn't expose that grace period as queryable state, so the
    /// screensaver's lock indicator has to compute it from this instead. See
    /// `LockStateMonitor`.
    var lockGracePeriodSeconds: Int {
        didSet { defaults.set(lockGracePeriodSeconds, forKey: Keys.lockGracePeriodSeconds) }
    }
    /// Shown on the Kat screensaver instead of "next break in…" for the stretch between a
    /// break ending and you actually returning (screensaver disengaging).
    var breakOverMessage: String {
        didSet { defaults.set(breakOverMessage, forKey: Keys.breakOverMessage) }
    }
    var scheduleConfig: ScheduleConfig {
        didSet { persist(scheduleConfig, key: Keys.scheduleConfig) }
    }
    var customButtons: [CustomButtonConfig] {
        didSet { persist(customButtons, key: Keys.customButtons) }
    }
    var onStartScripts: [LifecycleScript] {
        didSet { persist(onStartScripts, key: Keys.onStartScripts) }
    }
    var onEndScripts: [LifecycleScript] {
        didSet { persist(onEndScripts, key: Keys.onEndScripts) }
    }
    /// Whether the first-launch welcome screen has already been shown and acknowledged.
    var hasShownWelcome: Bool {
        didSet { defaults.set(hasShownWelcome, forKey: Keys.hasShownWelcome) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        postponeOnCameraUse = defaults.object(forKey: Keys.postponeOnCameraUse) as? Bool ?? true
        pauseMediaOnBreakStart = defaults.object(forKey: Keys.pauseMediaOnBreakStart) as? Bool ?? true
        lockGracePeriodSeconds = defaults.object(forKey: Keys.lockGracePeriodSeconds) as? Int ?? 5
        breakOverMessage = defaults.string(forKey: Keys.breakOverMessage) ?? "Break over"
        scheduleConfig = Self.load(ScheduleConfig.self, key: Keys.scheduleConfig, defaults: defaults) ?? .default
        customButtons = Self.load([CustomButtonConfig].self, key: Keys.customButtons, defaults: defaults) ?? []
        onStartScripts = Self.load([LifecycleScript].self, key: Keys.onStartScripts, defaults: defaults) ?? []
        onEndScripts = Self.load([LifecycleScript].self, key: Keys.onEndScripts, defaults: defaults) ?? []
        hasShownWelcome = defaults.object(forKey: Keys.hasShownWelcome) as? Bool ?? false
    }

    private func persist(_ value: some Encodable, key: String) {
        guard let data = try? JSONEncoder().encode(value) else {
            Log.settings.error("Failed to encode value for key \(key, privacy: .public)")
            return
        }
        defaults.set(data, forKey: key)
    }

    private static func load<T: Decodable>(_ type: T.Type, key: String, defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
