import AppKit
import SwiftUI

/// A manually-managed window rather than SwiftUI's `Settings {}` scene — that scene's
/// Cmd+,/activation wiring assumes a normal app with an app menu to hang the shortcut
/// off, which `LSUIElement` apps don't have, and is known to be flaky before the scene
/// has been shown once.
@MainActor
final class PreferencesWindowController: NSWindowController {
    convenience init(settingsStore: SettingsStore, onCheckForUpdatesChanged: (() -> Void)? = nil) {
        let hostingController = NSHostingController(
            rootView: PreferencesView(settingsStore: settingsStore, onCheckForUpdatesChanged: onCheckForUpdatesChanged)
        )
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Kat Preferences"
        window.styleMask = [.titled, .closable, .miniaturizable]
        self.init(window: window)
    }

    func show() {
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
