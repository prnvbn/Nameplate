import AppKit
import SwiftUI

private let nameplatePresetDefaultsKey = "nameplatePreset"

@MainActor
enum NameplatePreset: String, CaseIterable, Identifiable {
    struct StickyNotePaperColor: Identifiable {
        let id: String
        let color: NSColor

        func matches(_ selected: NSColor) -> Bool {
            guard let first = color.usingColorSpace(.sRGB),
                  let second = selected.usingColorSpace(.sRGB) else { return false }
            return abs(first.redComponent - second.redComponent) < 0.01
                && abs(first.greenComponent - second.greenComponent) < 0.01
                && abs(first.blueComponent - second.blueComponent) < 0.01
        }
    }

    static let stickyNotePaperColors: [StickyNotePaperColor] = [
        .init(id: "Yellow", color: NSColor(srgbRed: 1, green: 0.96, blue: 0.70, alpha: 1)),
        .init(id: "Pink", color: NSColor(srgbRed: 1, green: 0.79, blue: 0.85, alpha: 1)),
        .init(id: "Blue", color: NSColor(srgbRed: 0.76, green: 0.88, blue: 1, alpha: 1)),
        .init(id: "Green", color: NSColor(srgbRed: 0.80, green: 0.94, blue: 0.76, alpha: 1)),
        .init(id: "Lavender", color: NSColor(srgbRed: 0.88, green: 0.82, blue: 0.97, alpha: 1)),
        .init(id: "Peach", color: NSColor(srgbRed: 1, green: 0.86, blue: 0.74, alpha: 1)),
    ]

    case basic
    case accentRail
    case licensePlate
    case stickyNote

    var id: String { rawValue }

    var name: String {
        switch self {
        case .basic: "Basic"
        case .accentRail: "Accent Rail"
        case .stickyNote: "Sticky Note"
        case .licensePlate: "Number Plate"
        }
    }

    var description: String {
        switch self {
        case .basic: "Compact dark nameplate with macOS system type"
        case .accentRail: "Dark nameplate with a customizable color strip"
        case .stickyNote: "Note with a customizable paper color and soft shadow"
        case .licensePlate: "Ivory face, bold lettering, and a dark border"
        }
    }

    func resetAppearance() {
        switch self {
        case .basic: UserDefaults.standard.removeObject(forKey: "basicTextColor")
        case .accentRail: UserDefaults.standard.removeObject(forKey: "accentRailColor")
        case .stickyNote: UserDefaults.standard.removeObject(forKey: "stickyNoteColor")
        case .licensePlate: break
        }
    }

    var backgroundColor: NSColor {
        switch self {
        case .basic: NSColor(calibratedWhite: 0.12, alpha: 1)
        case .accentRail: NSColor(calibratedWhite: 0.12, alpha: 0.9)
        case .stickyNote: Self.stickyNoteColor
        case .licensePlate: NSColor(calibratedWhite: 0.08, alpha: 1)
        }
    }

    var textColor: NSColor {
        switch self {
        case .basic: Self.basicTextColor
        case .accentRail: NSColor(calibratedWhite: 1, alpha: 0.96)
        case .stickyNote: NSColor(calibratedWhite: 0.18, alpha: 1)
        case .licensePlate: NSColor(calibratedWhite: 0.08, alpha: 1)
        }
    }

    var font: NSFont {
        switch self {
        case .basic: .systemFont(ofSize: 15, weight: .semibold)
        case .accentRail: .systemFont(ofSize: 14, weight: .semibold)
        case .stickyNote: .systemFont(ofSize: 15, weight: .medium)
        case .licensePlate: .monospacedSystemFont(ofSize: 18, weight: .bold)
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .basic: 18
        case .accentRail: 8
        case .stickyNote: 3
        case .licensePlate: 7
        }
    }

    var panelInset: CGFloat {
        switch self {
        case .basic, .accentRail: 12
        case .stickyNote: 24
        case .licensePlate: 1
        }
    }

    func displayText(_ title: String) -> String {
        self == .licensePlate ? title.uppercased() : title
    }

    static var plateScale: Double {
        get {
            let value = UserDefaults.standard.object(forKey: "plateScale") as? Double ?? 1
            return value.isFinite ? min(2, max(0.5, value)) : 1
        }
        set { UserDefaults.standard.set(newValue.isFinite ? min(2, max(0.5, newValue)) : 1, forKey: "plateScale") }
    }

    static var basicTextColor: NSColor {
        get { storedColor(for: "basicTextColor", fallback: NSColor(calibratedWhite: 1, alpha: 0.96)) }
        set { saveColor(newValue, for: "basicTextColor") }
    }

    static var accentRailColor: NSColor {
        get { storedColor(for: "accentRailColor", fallback: NSColor(srgbRed: 214.0 / 255, green: 245.0 / 255, blue: 156.0 / 255, alpha: 1)) }
        set { saveColor(newValue, for: "accentRailColor") }
    }

    static var stickyNoteColor: NSColor {
        get { storedColor(for: "stickyNoteColor", fallback: stickyNotePaperColors[0].color) }
        set { saveColor(newValue, for: "stickyNoteColor") }
    }

    static var stickyNoteShade: NSColor {
        stickyNoteColor.blended(withFraction: 0.14, of: .black) ?? stickyNoteColor
    }

    private static func storedColor(for key: String, fallback: NSColor) -> NSColor {
        guard let components = UserDefaults.standard.array(forKey: key) as? [Double],
              components.count == 3 else { return fallback }
        return NSColor(srgbRed: components[0], green: components[1], blue: components[2], alpha: 1)
    }

    private static func saveColor(_ color: NSColor, for key: String) {
        guard let rgb = color.usingColorSpace(.sRGB) else { return }
        UserDefaults.standard.set([Double(rgb.redComponent), Double(rgb.greenComponent), Double(rgb.blueComponent)], forKey: key)
    }

    static var selected: NameplatePreset {
        get {
            NameplatePreset(
                rawValue: UserDefaults.standard.string(forKey: nameplatePresetDefaultsKey) ?? "")
                ?? .basic
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: nameplatePresetDefaultsKey) }
    }

    func labelFrame(for thumbnail: MissionControlThumbnail) -> NSRect {
        let preset = self
        let textWidth = (preset.displayText(thumbnail.title) as NSString)
            .size(withAttributes: [.font: preset.font]).width
        let width: CGFloat
        let height: CGFloat
        switch preset {
        case .basic:
            width = ceil(textWidth) + 44
            height = 36
        case .accentRail:
            width = ceil(textWidth) + 52
            height = 36
        case .stickyNote:
            width = max(104, min(ceil(textWidth) + 24, 180))
            height = max(88, width * 0.8)
        case .licensePlate:
            width = min(textWidth + 32, max(thumbnail.frame.width - 16, 100), 400)
            height = 40
        }
        let scaledWidth = width * Self.plateScale
        let scaledHeight = height * Self.plateScale
        return NSRect(
            x: thumbnail.frame.midX - scaledWidth / 2,
            y: (NSScreen.screens.first?.frame.maxY ?? 0) - thumbnail.frame.midY - scaledHeight / 2,
            width: scaledWidth,
            height: scaledHeight
        ).insetBy(dx: -panelInset * Self.plateScale, dy: -panelInset * Self.plateScale)
    }

    func makePanel(title: String, bundleIdentifier: String, frame: NSRect) -> NSPanel {
        let preset = self
        let panel = NSPanel(
            contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        // Each style draws its own shadow inside the transparent panel margin.
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        panel.contentView = NameplateContentView(
            preset: preset, title: title, frame: NSRect(origin: .zero, size: frame.size),
            scale: Self.plateScale)
        panel.orderFrontRegardless()
        return panel
    }

    func previewPlate(_ title: String, compact: Bool = false) -> some View {
        NameplateView(preset: self, title: title, compact: compact)
    }
}
