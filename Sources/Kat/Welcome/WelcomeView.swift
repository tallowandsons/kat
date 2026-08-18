import AppKit
import SwiftUI

struct WelcomeView: View {
    let settingsStore: SettingsStore
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Self.catImage
                .resizable()
                .scaledToFit()
                .frame(width: 140, height: 140)

            VStack(spacing: 12) {
                Text("Welcome to Kat")
                    .font(.system(size: 28, weight: .semibold))
                Text(welcomeMessage)
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 360)
            }

            Spacer()

            Button("Got it!") { onDismiss() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

            Spacer().frame(height: 8)
        }
        .padding(32)
        .frame(width: 460, height: 500)
        .background(.black)
        .foregroundStyle(.white)
    }

    private var welcomeMessage: String {
        let minutes = settingsStore.scheduleConfig.durationSeconds / 60
        let cameraNote = settingsStore.postponeOnCameraUse ? ", unless your camera is on" : ""
        return "Kat will start a \(minutes)-minute break every hour on the hour\(cameraNote). You can change these settings any time from the menu bar."
    }

    // Same template-tinting approach as the break overlay — the artwork is black line
    // art, which needs to render white against this view's black background.
    private static let catImage: Image = {
        guard let url = Bundle.main.url(forResource: "CatFull", withExtension: "pdf"),
              let nsImage = NSImage(contentsOf: url)
        else {
            return Image(systemName: "cup.and.saucer.fill")
        }
        return Image(nsImage: nsImage).renderingMode(.template)
    }()
}
