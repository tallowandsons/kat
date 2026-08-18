import SwiftUI

struct BehaviourSettingsView: View {
    @Bindable var settingsStore: SettingsStore

    var body: some View {
        Form {
            Section("Camera") {
                Toggle("Postpone breaks while camera is in use", isOn: $settingsStore.postponeOnCameraUse)
                Text("Detects camera activity the same way the system's camera-in-use indicator does. Breaks are deferred, not skipped — they fire as soon as the camera turns off.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Media") {
                Toggle("Pause media when a break starts", isOn: $settingsStore.pauseMediaOnBreakStart)
                Text("Only affects apps and sites that register with the system's Now Playing info (Music, Spotify, Safari video/audio, etc.) — the same thing Control Center's media controls act on.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}
