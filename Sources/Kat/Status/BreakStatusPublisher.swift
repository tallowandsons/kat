import Foundation

/// Writes `BreakStatus` to disk whenever `BreakScheduler`'s state changes, so
/// `KatSaver.saver` (a separate process) can read it. Only writes on actual state
/// transitions (break start/end, next-break reschedule) — the screensaver computes the
/// live countdown itself from the stored dates, so there's no need to write every second.
@MainActor
enum BreakStatusPublisher {
    static func publish(from scheduler: BreakScheduler, isScreenLocked: Bool, breakOverMessage: String?) {
        BreakStatus(
            phase: scheduler.phase == .onBreak ? .onBreak : .idle,
            breakEndDate: scheduler.breakEndDate,
            nextBreakDate: scheduler.nextBreakDate,
            isScreenLocked: isScreenLocked,
            breakOverMessage: breakOverMessage
        ).write()
    }
}
