import SwiftUI

struct GeneralSettingsView: View {
    @Bindable var settingsStore: SettingsStore
    @State private var launchAtLoginEnabled = LoginItemManager.isEnabled
    @State private var debugWelcomeWindowController: WelcomeWindowController?

    var body: some View {
        Form {
            Stepper(
                "Break every \(settingsStore.scheduleConfig.intervalMinutes) minutes",
                value: $settingsStore.scheduleConfig.intervalMinutes,
                in: 5...240,
                step: 5
            )
            Stepper(
                "Break duration: \(settingsStore.scheduleConfig.durationSeconds / 60) minutes",
                value: durationMinutesBinding,
                in: 1...60
            )
            Toggle("Launch at Login", isOn: $launchAtLoginEnabled)
                .onChange(of: launchAtLoginEnabled) { _, newValue in
                    LoginItemManager.setEnabled(newValue)
                }
            Stepper(
                "Screensaver lock icon delay: \(settingsStore.lockGracePeriodSeconds)s",
                value: $settingsStore.lockGracePeriodSeconds,
                in: 0...300,
                step: 5
            )
            Text("Should match System Settings → Lock Screen → \"Require password after screen saver begins\" — macOS doesn't expose that timing directly, so the Kat screensaver's 🔒 indicator has to compute it from this instead.")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("Screensaver message after a break ends", text: $settingsStore.breakOverMessage)

            Button("Show Welcome Screen (debug)") {
                let controller = WelcomeWindowController(settingsStore: settingsStore)
                debugWelcomeWindowController = controller
                controller.show()
            }
        }
        .padding()
    }

    private var durationMinutesBinding: Binding<Int> {
        Binding(
            get: { settingsStore.scheduleConfig.durationSeconds / 60 },
            set: { settingsStore.scheduleConfig.durationSeconds = $0 * 60 }
        )
    }
}
