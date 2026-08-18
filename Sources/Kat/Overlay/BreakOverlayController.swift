import AppKit
import SwiftUI

/// Presents the blocking break overlay: one borderless window per connected display.
/// Best-effort blocking — sits above the Dock/menu bar/other apps via `.screenSaver`
/// level, but Mission Control and the Cmd+Tab HUD can still render above it. That's an
/// OS-level limit, not something worth chasing with private APIs.
@MainActor
final class BreakOverlayController {
    private let scheduler: BreakScheduler
    private var windows: [NSWindow] = []
    nonisolated(unsafe) private var screenChangeObserver: NSObjectProtocol?

    /// Read fresh on each `present()` — same "reload-free" pattern as
    /// `BreakScheduler.scheduleProvider` — so Preferences edits (task 8) apply next break.
    var customButtonsProvider: () -> [CustomButtonConfig] = { [] }

    init(scheduler: BreakScheduler) {
        self.scheduler = scheduler
        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.rebuildIfPresented() }
        }
    }

    deinit {
        if let screenChangeObserver {
            NotificationCenter.default.removeObserver(screenChangeObserver)
        }
    }

    /// A break already in progress when a display is connected/disconnected should still
    /// cover every currently-connected screen, not just whatever was attached when it began.
    private func rebuildIfPresented() {
        guard !windows.isEmpty else { return }
        dismiss()
        present()
    }

    func present() {
        guard windows.isEmpty else { return }

        let viewModel = BreakOverlayViewModel(scheduler: scheduler, customButtons: customButtonsProvider())

        windows = NSScreen.screens.map { screen in
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            window.isOpaque = true
            window.hasShadow = false
            window.isMovable = false
            window.backgroundColor = .black
            window.contentView = NSHostingView(rootView: BreakOverlayView(viewModel: viewModel))
            return window
        }

        for window in windows where window.screen != NSScreen.main {
            window.orderFrontRegardless()
        }
        // Give key focus to the window on the main screen so its buttons respond to
        // the keyboard/first click without an extra activation click.
        if let mainWindow = windows.first(where: { $0.screen == NSScreen.main }) ?? windows.first {
            mainWindow.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func dismiss() {
        for window in windows {
            window.orderOut(nil)
        }
        windows.removeAll()
    }
}
