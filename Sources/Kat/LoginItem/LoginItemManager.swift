import ServiceManagement

/// Thin wrapper over `SMAppService.mainApp`. Deliberately not cached anywhere — callers
/// should read `isEnabled` live each time, since the user can also flip this from System
/// Settings directly and a cached bool would drift out of sync.
enum LoginItemManager {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Log.settings.error("Login item registration failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
