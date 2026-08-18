import Foundation

/// User-configurable break cadence and the active window it's confined to.
struct ScheduleConfig: Codable, Equatable {
    var intervalMinutes: Int
    var durationSeconds: Int
    var activeWeekdays: Set<Weekday>
    /// Inclusive lower bound: a break may start at exactly `windowStart`.
    var windowStart: TimeOfDay
    /// Exclusive upper bound: a break must start strictly before `windowEnd`.
    var windowEnd: TimeOfDay

    static let `default` = ScheduleConfig(
        intervalMinutes: 60,
        durationSeconds: 5 * 60,
        activeWeekdays: Weekday.weekdays,
        windowStart: TimeOfDay(hour: 8, minute: 0),
        windowEnd: TimeOfDay(hour: 18, minute: 0)
    )
}
