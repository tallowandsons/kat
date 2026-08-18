import AppKit
import SwiftUI

struct BreakOverlayView: View {
    let viewModel: BreakOverlayViewModel

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 24) {
                    Text(Self.clockFormatter.string(from: context.date))
                        .font(.system(size: 22, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    Self.catImage
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                        .padding(.vertical, 8)
                    Text("Time for a break")
                        .font(.system(size: 40, weight: .semibold))
                    Text(remainingText(at: context.date))
                        .font(.system(size: 22, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 16) {
                    Button("Postpone 5 minutes") { viewModel.postpone(minutes: 5) }
                    Button("Postpone 10 minutes") { viewModel.postpone(minutes: 10) }
                    Button("Skip break") { viewModel.skip() }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                if !viewModel.customButtons.isEmpty {
                    HStack(spacing: 16) {
                        ForEach(viewModel.customButtons) { button in
                            Button(customButtonLabel(button)) { viewModel.runCustomButton(button) }
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                Spacer().frame(height: 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black)
            .foregroundStyle(.white)
        }
    }

    private func customButtonLabel(_ button: CustomButtonConfig) -> String {
        viewModel.clickedButtonIDs.contains(button.id) ? "✓ \(button.label)" : button.label
    }

    private func remainingText(at now: Date) -> String {
        guard let breakEndDate = viewModel.breakEndDate else { return "" }
        let totalSeconds = max(0, Int(breakEndDate.timeIntervalSince(now).rounded()))
        return String(format: "%d:%02d remaining", totalSeconds / 60, totalSeconds % 60)
    }

    private static let clockFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    // Template-rendered so it follows the overlay's .foregroundStyle(.white) — the bundled
    // artwork is drawn in black, which would otherwise be invisible on the black background.
    private static let catImage: Image = {
        guard let url = Bundle.main.url(forResource: "CatFull", withExtension: "pdf"),
              let nsImage = NSImage(contentsOf: url)
        else {
            return Image(systemName: "cup.and.saucer.fill")
        }
        return Image(nsImage: nsImage).renderingMode(.template)
    }()
}
