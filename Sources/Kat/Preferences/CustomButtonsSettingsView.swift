import AppKit
import SwiftUI

struct CustomButtonsSettingsView: View {
    @Bindable var settingsStore: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Buttons shown on the break overlay. Clicking one runs its script without ending the break.")
                .font(.caption)
                .foregroundStyle(.secondary)

            List {
                ForEach($settingsStore.customButtons) { $button in
                    HStack {
                        TextField("Label", text: $button.label)
                            .frame(width: 140)
                        TextField("Script path", text: $button.scriptPath)
                        Button("Choose…") { chooseScript(into: $button.scriptPath) }
                    }
                }
                .onDelete { settingsStore.customButtons.remove(atOffsets: $0) }
            }

            Button("Add Button") {
                settingsStore.customButtons.append(CustomButtonConfig(label: "New Button", scriptPath: ""))
            }
        }
        .padding()
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
