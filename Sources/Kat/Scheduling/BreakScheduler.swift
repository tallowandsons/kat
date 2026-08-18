import AppKit
import Foundation
import Observation

enum BreakPhase: Equatable {
    case idle
    case onBreak
}

/// Central state machine driving when breaks happen. Everything else (overlay,
/// notifications, lifecycle scripts, menu bar) reacts to this rather than owning any
/// scheduling logic itself.
@MainActor
@Observable
final class BreakScheduler {
    private(set) var phase: BreakPhase = .idle
    private(set) var isPaused: Bool = false
    private(set) var nextBreakDate: Date?
    private(set) var breakEndDate: Date?

    /// Read fresh on every tick/action so Preferences edits apply within ~1s without
    /// needing an explicit "reload" call.
    var scheduleProvider: () -> ScheduleConfig
    /// Whether the "postpone while camera is in use" setting is on. Only gates the
    /// automatic schedule — `startBreakNow()` always fires immediately regardless.
    var isCameraGateEnabled: () -> Bool = { true }
    var isCameraInUse: () -> Bool = { false }

    var onBreakStart: (() -> Void)?
    var onBreakEnd: (() -> Void)?
    /// Fired whenever `nextBreakDate` is reassigned (not on every tick) — used by
    /// `BreakNotificationManager` to keep the heads-up notification's fire time in sync.
    var onNextBreakDateChange: ((Date?) -> Void)?

    private let calendar: Calendar
    // Timer isn't Sendable and `deinit` is always nonisolated even on a @MainActor class;
    // this timer is only ever touched from the main thread in practice (scheduled on
    // RunLoop.main, invalidated from deinit of a singleton-lifetime object). Excluded
    // from @Observable tracking since it's a private implementation detail, not state
    // any view should react to.
    @ObservationIgnored
    nonisolated(unsafe) private var timer: Timer?
    @ObservationIgnored
    nonisolated(unsafe) private var wakeObserver: NSObjectProtocol?
    @ObservationIgnored
    nonisolated(unsafe) private var clockChangeObserver: NSObjectProtocol?

    init(
        calendar: Calendar = .current,
        scheduleProvider: @escaping () -> ScheduleConfig = { .default }
    ) {
        self.calendar = calendar
        self.scheduleProvider = scheduleProvider
        self.nextBreakDate = ScheduleWindowCalculator.nextBreakDate(
            after: Date(),
            schedule: scheduleProvider(),
            calendar: calendar
        )
        startTicking()
        observeTimeJumps()
    }

    deinit {
        timer?.invalidate()
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
        if let clockChangeObserver {
            NotificationCenter.default.removeObserver(clockChangeObserver)
        }
    }

    /// After sleep or a manual clock change, `nextBreakDate` may be long past — recompute
    /// it fresh from now rather than firing an ambush break the moment the Mac wakes up.
    private func observeTimeJumps() {
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.recomputeAfterTimeJump() }
        }
        clockChangeObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name.NSSystemClockDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.recomputeAfterTimeJump() }
        }
    }

    private func recomputeAfterTimeJump() {
        guard phase == .idle, !isPaused else { return }
        setNextBreakDate(ScheduleWindowCalculator.nextBreakDate(after: Date(), schedule: scheduleProvider(), calendar: calendar))
    }

    private func startTicking() {
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tick()
            }
        }
        // .common (not .default) so this keeps firing while the status-bar menu is open
        // and tracking the run loop in .eventTracking mode.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        let now = Date()
        switch phase {
        case .idle:
            guard !isPaused, let nextBreakDate, now >= nextBreakDate else { return }
            if isCameraGateEnabled(), isCameraInUse() {
                // Deferred, not skipped: re-checked every tick, so the break fires within
                // a second of the camera going off rather than waiting for a fixed delay.
                return
            }
            beginBreak(at: now)
        case .onBreak:
            guard let breakEndDate, now >= breakEndDate else { return }
            endBreak(at: now, advanceSchedule: true)
        }
    }

    private func beginBreak(at now: Date) {
        let schedule = scheduleProvider()
        phase = .onBreak
        breakEndDate = now.addingTimeInterval(TimeInterval(schedule.durationSeconds))
        Log.scheduler.info("Break started at \(now, privacy: .public)")
        onBreakStart?()
    }

    private func endBreak(at now: Date, advanceSchedule: Bool) {
        phase = .idle
        breakEndDate = nil
        Log.scheduler.info("Break ended at \(now, privacy: .public)")
        onBreakEnd?()
        if advanceSchedule {
            setNextBreakDate(ScheduleWindowCalculator.nextBreakDate(after: now, schedule: scheduleProvider(), calendar: calendar))
        }
    }

    private func setNextBreakDate(_ date: Date?) {
        nextBreakDate = date
        onNextBreakDateChange?(date)
    }

    // MARK: - User-facing actions

    func startBreakNow() {
        guard phase == .idle else { return }
        beginBreak(at: Date())
    }

    /// Delays only the in-progress/imminent break. The occurrence after this one is
    /// recomputed fresh from the schedule grid, so postponing doesn't drift later breaks.
    func postpone(minutes: Int) {
        let now = Date()
        if phase == .onBreak {
            endBreak(at: now, advanceSchedule: false)
        }
        setNextBreakDate(now.addingTimeInterval(TimeInterval(minutes * 60)))
    }

    func skip() {
        guard phase == .onBreak else { return }
        endBreak(at: Date(), advanceSchedule: true)
    }

    func pause() {
        isPaused = true
    }

    func resume() {
        guard isPaused else { return }
        isPaused = false
        setNextBreakDate(ScheduleWindowCalculator.nextBreakDate(after: Date(), schedule: scheduleProvider(), calendar: calendar))
    }
}
