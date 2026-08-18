import SwiftUI

struct PreferencesView: View {
    @Bindable var settingsStore: SettingsStore

    var body: some View {
        TabView {
            GeneralSettingsView(settingsStore: settingsStore)
                .tabItem { Label("General", systemImage: "gearshape") }
            ScheduleSettingsView(settingsStore: settingsStore)
                .tabItem { Label("Schedule", systemImage: "calendar") }
            BehaviourSettingsView(settingsStore: settingsStore)
                .tabItem { Label("Behaviour", systemImage: "slider.horizontal.3") }
            CustomButtonsSettingsView(settingsStore: settingsStore)
                .tabItem { Label("Custom Buttons", systemImage: "hand.tap") }
            ScriptsSettingsView(settingsStore: settingsStore)
                .tabItem { Label("Scripts", systemImage: "terminal") }
        }
        .padding()
        .frame(width: 520, height: 420)
    }
}
