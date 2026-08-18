import Foundation
import Testing
@testable import Kat

@Suite("ScheduleWindowCalculator")
struct ScheduleWindowCalculatorTests {
    // Fixed UTC calendar so tests are deterministic regardless of the machine's timezone.
    private static func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return utcCalendar().date(from: components)!
    }

    // 2024-01-01 is a Monday.
    private let schedule = ScheduleConfig(
        intervalMinutes: 60,
        durationSeconds: 300,
        activeWeekdays: Weekday.weekdays, // Mon-Fri
        windowStart: TimeOfDay(hour: 8, minute: 0),
        windowEnd: TimeOfDay(hour: 18, minute: 0)
    )

    @Test("Aligns to the next wall-clock hour within the window")
    func alignsToNextHour() {
        let now = Self.date(2024, 1, 1, 9, 17) // Monday 9:17am
        let next = ScheduleWindowCalculator.nextBreakDate(after: now, schedule: schedule, calendar: Self.utcCalendar())
        #expect(next == Self.date(2024, 1, 1, 10, 0))
    }

    @Test("A moment exactly on the grid returns the following slot, not itself")
    func exactlyOnGridReturnsNextSlot() {
        let now = Self.date(2024, 1, 1, 10, 0) // Monday exactly 10:00am
        let next = ScheduleWindowCalculator.nextBreakDate(after: now, schedule: schedule, calendar: Self.utcCalendar())
        #expect(next == Self.date(2024, 1, 1, 11, 0))
    }

    @Test("Before the window start jumps forward to windowStart the same day")
    func beforeWindowJumpsToWindowStart() {
        let now = Self.date(2024, 1, 1, 6, 0) // Monday 6am, window starts 8am
        let next = ScheduleWindowCalculator.nextBreakDate(after: now, schedule: schedule, calendar: Self.utcCalendar())
        #expect(next == Self.date(2024, 1, 1, 8, 0))
    }

    @Test("windowEnd is exclusive: no break starts at or after 18:00")
    func windowEndIsExclusive() {
        let now = Self.date(2024, 1, 1, 17, 30) // Monday 5:30pm
        let next = ScheduleWindowCalculator.nextBreakDate(after: now, schedule: schedule, calendar: Self.utcCalendar())
        // Next 60-min grid slot after 17:30 is 18:00, which is excluded, so it rolls to
        // the next active day's windowStart.
        #expect(next == Self.date(2024, 1, 2, 8, 0))
    }

    @Test("After Friday's window rolls forward to Monday, skipping the weekend")
    func rollsOverWeekend() {
        let now = Self.date(2024, 1, 5, 17, 15) // Friday 5:15pm
        let next = ScheduleWindowCalculator.nextBreakDate(after: now, schedule: schedule, calendar: Self.utcCalendar())
        #expect(next == Self.date(2024, 1, 8, 8, 0)) // Monday 8am
    }

    @Test("Postpone-then-snap-back: an off-grid postponed time still resolves to the next grid slot")
    func postponeSnapsBackToGrid() {
        // Simulates: break was due at 10:00, postponed 5 minutes to 10:05.
        let postponedTime = Self.date(2024, 1, 1, 10, 5)
        let next = ScheduleWindowCalculator.nextBreakDate(after: postponedTime, schedule: schedule, calendar: Self.utcCalendar())
        #expect(next == Self.date(2024, 1, 1, 11, 0))
    }

    @Test("No active weekdays means the schedule never triggers")
    func noActiveWeekdaysReturnsNil() {
        let emptySchedule = ScheduleConfig(
            intervalMinutes: 60,
            durationSeconds: 300,
            activeWeekdays: [],
            windowStart: TimeOfDay(hour: 8, minute: 0),
            windowEnd: TimeOfDay(hour: 18, minute: 0)
        )
        let now = Self.date(2024, 1, 1, 9, 0)
        let next = ScheduleWindowCalculator.nextBreakDate(after: now, schedule: emptySchedule, calendar: Self.utcCalendar())
        #expect(next == nil)
    }

    @Test("isWithinActiveWindow matches weekday and time bounds")
    func isWithinActiveWindowChecksBothDimensions() {
        let calendar = Self.utcCalendar()
        #expect(ScheduleWindowCalculator.isWithinActiveWindow(Self.date(2024, 1, 1, 9, 0), schedule: schedule, calendar: calendar) == true)
        #expect(ScheduleWindowCalculator.isWithinActiveWindow(Self.date(2024, 1, 1, 7, 59), schedule: schedule, calendar: calendar) == false)
        #expect(ScheduleWindowCalculator.isWithinActiveWindow(Self.date(2024, 1, 1, 18, 0), schedule: schedule, calendar: calendar) == false)
        #expect(ScheduleWindowCalculator.isWithinActiveWindow(Self.date(2024, 1, 6, 9, 0), schedule: schedule, calendar: calendar) == false) // Saturday
    }
}
