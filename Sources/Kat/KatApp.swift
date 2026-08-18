import SwiftUI

@main
struct KatApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Placeholder scene only — Kat is menu-bar only and has no main window.
        // The real Preferences UI is a manually-managed NSWindowController (see Preferences/).
        Settings {
            EmptyView()
        }
    }
}
