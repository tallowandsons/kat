import Foundation

/// A clock time with no associated date, used for the schedule's active window bounds.
struct TimeOfDay: Codable, Comparable, Hashable {
    var hour: Int
    var minute: Int

    var minutesSinceMidnight: Int { hour * 60 + minute }

    static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        lhs.minutesSinceMidnight < rhs.minutesSinceMidnight
    }

    /// For binding to SwiftUI's `DatePicker(displayedComponents: .hourAndMinute)`, which
    /// needs a `Date` — only the hour/minute are meaningful, the date portion is ignored.
    func asDate(calendar: Calendar = .current) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }

    init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    init(from date: Date, calendar: Calendar = .current) {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        self.hour = components.hour ?? 0
        self.minute = components.minute ?? 0
    }
}
