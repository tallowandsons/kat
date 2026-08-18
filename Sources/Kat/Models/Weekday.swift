import Foundation

/// Mirrors `Calendar.Component.weekday` numbering (1 = Sunday ... 7 = Saturday)
/// so conversions to/from `DateComponents` never need remapping.
enum Weekday: Int, CaseIterable, Codable, Comparable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    static func < (lhs: Weekday, rhs: Weekday) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    static func of(_ date: Date, calendar: Calendar) -> Weekday {
        let rawValue = calendar.component(.weekday, from: date)
        guard let weekday = Weekday(rawValue: rawValue) else {
            preconditionFailure("Calendar.Component.weekday returned out-of-range value \(rawValue)")
        }
        return weekday
    }

    static let weekdays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]

    /// Display order for UI lists — Monday-first, matching the UK/ISO week rather than
    /// `Calendar.Component.weekday`'s Sunday-first numbering (kept as the raw values
    /// since `ScheduleWindowCalculator` relies on that mapping being unchanged).
    static let mondayFirstOrder: [Weekday] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]

    var displayName: String {
        Calendar.current.weekdaySymbols[rawValue - 1]
    }
}
