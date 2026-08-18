import OSLog

/// Centralized loggers, visible via Console.app or `log stream --predicate
/// 'subsystem == "com.tallowandsons.kat"'` — there's no attached terminal/debugger
/// once Kat is launched normally, so `print()` isn't a reliable way to observe it.
enum Log {
    static let scheduler = Logger(subsystem: "com.tallowandsons.kat", category: "scheduler")
    static let notifications = Logger(subsystem: "com.tallowandsons.kat", category: "notifications")
    static let scripts = Logger(subsystem: "com.tallowandsons.kat", category: "scripts")
    static let settings = Logger(subsystem: "com.tallowandsons.kat", category: "settings")
    static let media = Logger(subsystem: "com.tallowandsons.kat", category: "media")
}
