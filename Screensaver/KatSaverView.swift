import ScreenSaver

@objc(KatSaverView)
final class KatSaverView: ScreenSaverView {
    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        animationTimeInterval = 1.0
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func draw(_ rect: NSRect) {
        NSColor.black.setFill()
        rect.fill()

        let now = Date()
        let status = BreakStatus.read()

        let text = statusText(status, at: now)
        let font = NSFont.systemFont(ofSize: 24, weight: .medium)
        let textSize = text.size(withAttributes: [.font: font])

        // Cat above the text, mirroring the break overlay's layout (image, then message).
        if let cat = Self.catImage {
            let catSize = NSSize(width: 140, height: 140 * cat.size.height / cat.size.width)
            let gap: CGFloat = 24
            let totalHeight = catSize.height + gap + textSize.height
            let catOrigin = NSPoint(
                x: bounds.midX - catSize.width / 2,
                y: bounds.midY - totalHeight / 2 + gap + textSize.height
            )
            cat.draw(in: NSRect(origin: catOrigin, size: catSize))
            drawCentered(text, font: font, yOffset: -(totalHeight / 2) + textSize.height / 2)
        } else {
            drawCentered(text, font: font, yOffset: 0)
        }

        if status?.isScreenLocked == true {
            drawLockIndicator()
        }
    }

    /// The bundled artwork is black line art, drawn white to show up on the black
    /// background — `NSImage.isTemplate` only auto-tints for AppKit controls
    /// (NSImageView, NSButton, etc.), not for a manual `draw(in:)` call like this one, so
    /// the recolor is done by hand: draw the shape, then flood-fill white constrained to
    /// its alpha via `.sourceAtop`.
    private static let catImage: NSImage? = {
        guard let url = Bundle(for: KatSaverView.self).url(forResource: "CatFull", withExtension: "pdf"),
              let original = NSImage(contentsOf: url)
        else { return nil }

        let tinted = NSImage(size: original.size)
        tinted.lockFocus()
        original.draw(in: NSRect(origin: .zero, size: original.size))
        NSColor.white.set()
        NSRect(origin: .zero, size: original.size).fill(using: .sourceAtop)
        tinted.unlockFocus()
        return tinted
    }()

    private func drawLockIndicator() {
        let text = "🔒"
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 32)]
        let size = text.size(withAttributes: attrs)
        let padding: CGFloat = 24
        let point = NSPoint(x: bounds.maxX - size.width - padding, y: padding)
        text.draw(at: point, withAttributes: attrs)
    }

    private func statusText(_ status: BreakStatus?, at now: Date) -> String {
        guard let status else {
            return "Kat status unavailable"
        }
        switch status.phase {
        case .onBreak:
            guard let breakEndDate = status.breakEndDate else { return "On break" }
            let remaining = max(0, Int(breakEndDate.timeIntervalSince(now).rounded()))
            return "On break — \(Self.format(seconds: remaining)) remaining"
        case .idle:
            // Sticky until the user actually returns — see BreakStatus.breakOverMessage.
            if let breakOverMessage = status.breakOverMessage, !breakOverMessage.isEmpty {
                return breakOverMessage
            }
            guard let nextBreakDate = status.nextBreakDate else { return "No upcoming breaks" }
            let remaining = max(0, Int(nextBreakDate.timeIntervalSince(now).rounded()))
            return "Next break in \(Self.format(seconds: remaining))"
        }
    }

    private func drawCentered(_ text: String, font: NSFont, color: NSColor = .white, yOffset: CGFloat) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let size = text.size(withAttributes: attrs)
        let point = NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2 + yOffset)
        text.draw(at: point, withAttributes: attrs)
    }

    override func animateOneFrame() {
        setNeedsDisplay(bounds)
    }

    override var hasConfigureSheet: Bool { false }
    override var configureSheet: NSWindow? { nil }

    private static func format(seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
