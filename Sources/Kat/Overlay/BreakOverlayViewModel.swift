import Foundation
import Observation

/// Thin wrapper so `BreakOverlayView` depends on a small, view-shaped surface rather than
/// reaching into `BreakScheduler` directly.
///
/// `@Observable` (rather than a plain class) so the "clicked" checkmark updates
/// immediately rather than waiting for the next `TimelineView` tick, and — since one
/// instance is shared across every screen's overlay window — clicking a custom button on
/// one display marks it clicked on all of them.
@MainActor
@Observable
final class BreakOverlayViewModel {
    @ObservationIgnored
    private let scheduler: BreakScheduler
    let customButtons: [CustomButtonConfig]
    private(set) var clickedButtonIDs: Set<UUID> = []

    init(scheduler: BreakScheduler, customButtons: [CustomButtonConfig] = []) {
        self.scheduler = scheduler
        self.customButtons = customButtons
    }

    var breakEndDate: Date? { scheduler.breakEndDate }

    func postpone(minutes: Int) {
        scheduler.postpone(minutes: minutes)
    }

    func skip() {
        scheduler.skip()
    }

    /// Runs the button's script without ending the break — the user can still separately
    /// Postpone/Skip. Re-clickable (e.g. to retry), the checkmark just tracks "clicked at
    /// least once this break."
    func runCustomButton(_ button: CustomButtonConfig) {
        ScriptRunner.run(path: button.scriptPath)
        clickedButtonIDs.insert(button.id)
    }
}
