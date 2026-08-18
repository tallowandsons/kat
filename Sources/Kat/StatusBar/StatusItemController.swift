import AppKit

/// Owns the menu-bar icon and its dropdown menu — the app's only permanent UI surface.
@MainActor
final class StatusItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let scheduler: BreakScheduler

    private let countdownItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let pauseResumeItem = NSMenuItem()

    // See BreakScheduler's `timer` property for why this needs `nonisolated(unsafe)`.
    nonisolated(unsafe) private var refreshTimer: Timer?

    var onOpenPreferences: (() -> Void)?

    init(scheduler: BreakScheduler) {
        self.scheduler = scheduler
        super.init()

        statusItem.button?.image = Self.menuBarIcon()
        statusItem.menu = buildMenu()
        refresh()
        startRefreshTimer()
    }

    private static func menuBarIcon() -> NSImage? {
        guard let url = Bundle.main.url(forResource: "CatFace", withExtension: "pdf"),
              let image = NSImage(contentsOf: url)
        else {
            return NSImage(systemSymbolName: "cup.and.saucer.fill", accessibilityDescription: "Kat")
        }
        image.isTemplate = true
        // Preserve the artwork's native aspect ratio (it isn't square) — forcing an exact
        // 18x18 stretched it. Constrain by height, matching typical status-item sizing.
        let targetHeight: CGFloat = 16
        let aspectRatio = image.size.width / image.size.height
        image.size = NSSize(width: targetHeight * aspectRatio, height: targetHeight)
        image.accessibilityDescription = "Kat"
        return image
    }

    deinit {
        refreshTimer?.invalidate()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        menu.addItem(
            withTitle: "Start Break Now",
            action: #selector(startBreakNow),
            keyEquivalent: ""
        ).target = self

        menu.addItem(.separator())

        countdownItem.isEnabled = false
        menu.addItem(countdownItem)

        pauseResumeItem.target = self
        pauseResumeItem.action = #selector(togglePause)
        menu.addItem(pauseResumeItem)

        menu.addItem(.separator())

        menu.addItem(
            withTitle: "Preferences…",
            action: #selector(openPreferences),
            keyEquivalent: ","
        ).target = self

        menu.addItem(.separator())

        menu.addItem(
            withTitle: "Quit Kat",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        return menu
    }

    private func startRefreshTimer() {
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh()
            }
        }
        // .common so the countdown keeps ticking while the menu itself is open and
        // tracking the run loop in .eventTracking mode.
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    private func refresh() {
        countdownItem.title = countdownText()
        pauseResumeItem.title = scheduler.isPaused ? "Resume Breaks" : "Pause Breaks"
    }

    private func countdownText() -> String {
        let now = Date()
        switch scheduler.phase {
        case .onBreak:
            guard let breakEndDate = scheduler.breakEndDate else { return "On break" }
            return "On break — \(Self.format(seconds: breakEndDate.timeIntervalSince(now))) remaining"
        case .idle:
            if scheduler.isPaused {
                return "Breaks paused"
            }
            guard let nextBreakDate = scheduler.nextBreakDate else {
                return "No upcoming breaks"
            }
            return "Next break in \(Self.format(seconds: nextBreakDate.timeIntervalSince(now)))"
        }
    }

    private static func format(seconds: TimeInterval) -> String {
        let totalSeconds = max(0, Int(seconds.rounded()))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    @objc private func startBreakNow() {
        scheduler.startBreakNow()
        refresh()
    }

    @objc private func togglePause() {
        if scheduler.isPaused {
            scheduler.resume()
        } else {
            scheduler.pause()
        }
        refresh()
    }

    @objc private func openPreferences() {
        onOpenPreferences?()
    }
}

extension StatusItemController: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        refresh()
    }
}
