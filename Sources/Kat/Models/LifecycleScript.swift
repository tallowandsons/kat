import Foundation

/// A user-configured shell script run (fire-and-forget) on every break start/end, unless
/// disabled. Kept as discrete, independently toggleable entries per the brief rather than
/// one combined script per lifecycle event.
struct LifecycleScript: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var label: String
    var scriptPath: String
    var isEnabled: Bool = true
}
