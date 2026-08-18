import AppKit
import SwiftUI

@MainActor
final class WelcomeWindowController: NSWindowController {
    // Single source of truth for the content size — WelcomeView's outermost .frame must
    // match this, since `show()` uses it directly rather than reading `window.frame`
    // back (that read raced the just-assigned NSHostingController's layout pass and
    // intermittently observed a stale/zero size, breaking horizontal centering).
    private static let contentSize = NSSize(width: 460, height: 500)

    convenience init(settingsStore: SettingsStore) {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.contentSize),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to Kat"
        window.isReleasedWhenClosed = false
        self.init(window: window)

        window.contentViewController = NSHostingController(
            rootView: WelcomeView(settingsStore: settingsStore, onDismiss: { [weak self] in
                self?.close()
            })
        )
    }

    func show() {
        // NSWindow.center() deliberately biases above true vertical center (roughly
        // 40% down from the top) — this computes exact horizontal + vertical centering
        // on the screen the mouse is on instead.
        if let window {
            let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main
            if let screen {
                let screenFrame = screen.visibleFrame
                let windowFrameSize = window.frameRect(forContentRect: NSRect(origin: .zero, size: Self.contentSize)).size
                let origin = NSPoint(
                    x: screenFrame.midX - windowFrameSize.width / 2,
                    y: screenFrame.midY - windowFrameSize.height / 2
                )
                window.setFrame(NSRect(origin: origin, size: windowFrameSize), display: false)
            }
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
