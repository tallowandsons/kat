import Foundation

/// Pure, side-effect-free scheduling math — kept separate from `BreakScheduler` so it's
/// trivially unit-testable without any AppKit/timer involvement.
enum ScheduleWindowCalculator {
    static func isWithinActiveWindow(_ date: Date, schedule: ScheduleConfig, calendar: Calendar = .current) -> Bool {
        guard schedule.activeWeekdays.contains(Weekday.of(date, calendar: calendar)) else { return false }
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        guard let hour = comps.hour, let minute = comps.minute else { return false }
        let tod = TimeOfDay(hour: hour, minute: minute)
        return tod >= schedule.windowStart && tod < schedule.windowEnd
    }

    /// The next wall-clock-aligned moment (a multiple of `intervalMinutes` past midnight)
    /// strictly after `date` that falls within the schedule's active weekdays/time window.
    ///
    /// Used both for ordinary "what's next" scheduling and for the postpone snap-back
    /// behavior: postponing sets a one-off override time, and once that occurrence
    /// resolves, calling this again with the postponed time naturally lands back on the
    /// regular grid rather than perpetuating the offset.
    ///
    /// Returns `nil` if the schedule can never trigger (no active weekdays, or an
    /// empty/inverted time window).
    static func nextBreakDate(after date: Date, schedule: ScheduleConfig, calendar: Calendar = .current) -> Date? {
        guard schedule.intervalMinutes > 0,
              !schedule.activeWeekdays.isEmpty,
              schedule.windowStart < schedule.windowEnd
        else { return nil }

        // 8 days: today plus a full week, so a Friday-evening search still finds Monday morning.
        for dayOffset in 0..<8 {
            guard let dayStart = calendar.date(
                byAdding: .day,
                value: dayOffset,
                to: calendar.startOfDay(for: date)
            ) else { continue }

            guard schedule.activeWeekdays.contains(Weekday.of(dayStart, calendar: calendar)) else { continue }

            var minuteOfDay = 0
            while minuteOfDay < 24 * 60 {
                defer { minuteOfDay += schedule.intervalMinutes }

                let hour = minuteOfDay / 60
                let minute = minuteOfDay % 60
                let tod = TimeOfDay(hour: hour, minute: minute)
                guard tod >= schedule.windowStart, tod < schedule.windowEnd else { continue }

                // bySettingHour(minute:second:of:) respects wall-clock time across DST
                // transitions, unlike adding raw seconds to the day's start.
                guard let candidate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: dayStart),
                      candidate > date
                else { continue }

                return candidate
            }
        }
        return nil
    }
}
