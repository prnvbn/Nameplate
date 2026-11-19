import AppKit

@MainActor
enum MenuBarStatusIcon {
    private static let regular = makeImage(needsAccessibility: false)
    private static let warning = makeImage(needsAccessibility: true)

    static func image(needsAccessibility: Bool) -> NSImage {
        needsAccessibility ? warning : regular
    }

    private static func makeImage(needsAccessibility: Bool) -> NSImage {
        let size = NSSize(width: needsAccessibility ? 23 : 18, height: 18)
        let icon = Bundle.module.image(forResource: "MenuBarIcon")
        let image = NSImage(size: size, flipped: false) { _ in
            icon?.draw(in: NSRect(x: 0, y: 0, width: 18, height: 18))
            if needsAccessibility {
                // A colored badge requires a non-template image. Tint only the app icon
                // with the current appearance's label color before adding the badge.
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current?.compositingOperation = .sourceIn
                NSColor.labelColor.setFill()
                NSRect(origin: .zero, size: size).fill()
                NSGraphicsContext.restoreGraphicsState()

                // Cut a transparent border so the warning stays distinct in either menu bar appearance.
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current?.compositingOperation = .copy
                NSColor.clear.setFill()
                NSBezierPath(ovalIn: NSRect(x: 12, y: 7, width: 12, height: 12)).fill()
                NSGraphicsContext.restoreGraphicsState()
                NSColor.systemYellow.setStroke()
                let outline = NSBezierPath(ovalIn: NSRect(x: 13.6, y: 8.6, width: 8.8, height: 8.8))
                outline.lineWidth = 1.2
                outline.stroke()
                NSColor.systemYellow.setFill()
                NSBezierPath(
                    roundedRect: NSRect(x: 17.35, y: 12.2, width: 1.3, height: 3.5),
                    xRadius: 0.65, yRadius: 0.65
                ).fill()
                NSBezierPath(ovalIn: NSRect(x: 17.35, y: 9.8, width: 1.3, height: 1.3)).fill()
            }
            return true
        }
        image.isTemplate = !needsAccessibility
        return image
    }
}
