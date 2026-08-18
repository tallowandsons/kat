import AppKit
import SwiftUI

struct ScriptsSettingsView: View {
    @Bindable var settingsStore: SettingsStore

    var body: some View {
        Form {
            Section("On break start") {
                scriptList($settingsStore.onStartScripts)
            }
            Section("On break end") {
                scriptList($settingsStore.onEndScripts)
            }
        }
        .padding()
    }

    @ViewBuilder
    private func scriptList(_ scripts: Binding<[LifecycleScript]>) -> some View {
        ForEach(scripts) { $script in
            HStack {
                Toggle("", isOn: $script.isEnabled).labelsHidden()
                TextField("Label", text: $script.label).frame(width: 120)
                TextField("Script path", text: $script.scriptPath)
                Button("Choose…") { chooseScript(into: $script.scriptPath) }
                Button {
                    scripts.wrappedValue.removeAll { $0.id == script.id }
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.borderless)
            }
        }
        Button("Add Script") {
            scripts.wrappedValue.append(LifecycleScript(label: "New Script", scriptPath: ""))
        }
    }

    private func chooseScript(into path: Binding<String>) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            path.wrappedValue = url.path
        }
    }
}
