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
    case stickyNote
    case licensePlate

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

    var backgroundColor: NSColor {
        switch self {
        case .basic: NSColor(calibratedWhite: 0.12, alpha: Self.basicOpacity)
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

    static var basicOpacity: Double {
        get { UserDefaults.standard.object(forKey: "basicOpacity") as? Double ?? 0.82 }
        set { UserDefaults.standard.set(newValue, forKey: "basicOpacity") }
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

    private static var stickyNoteShade: NSColor {
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
        )
    }

    func makePanel(title: String, bundleIdentifier: String, frame: NSRect) -> NSPanel {
        let preset = self
        let panel = NSPanel(
            contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        let content = NSView(frame: NSRect(origin: .zero, size: frame.size))
        panel.contentView = content
        let frame = NSRect(origin: .zero, size: NSSize(
            width: frame.width / Self.plateScale, height: frame.height / Self.plateScale))
        content.bounds = frame

        let background = NSView(frame: NSRect(origin: .zero, size: frame.size))
        background.wantsLayer = true
        switch preset {
        case .basic:
            background.layer?.backgroundColor = preset.backgroundColor.cgColor
            background.layer?.borderColor = NSColor(calibratedWhite: 1, alpha: 0.14).cgColor
            background.layer?.borderWidth = 0.5
            background.layer?.shadowColor = NSColor.black.cgColor
            background.layer?.shadowOpacity = 0.22
            background.layer?.shadowRadius = 5
            background.layer?.shadowOffset = CGSize(width: 0, height: -2)
        case .accentRail:
            background.layer?.backgroundColor = preset.backgroundColor.cgColor
            background.layer?.shadowColor = NSColor.black.cgColor
            background.layer?.shadowOpacity = 0.22
            background.layer?.shadowRadius = 5
            background.layer?.shadowOffset = CGSize(width: 0, height: -2)
            let rail = NSView(frame: NSRect(x: 8, y: 7, width: 5, height: frame.height - 14))
            rail.wantsLayer = true
            rail.layer?.backgroundColor = NameplatePreset.accentRailColor.cgColor
            rail.layer?.cornerRadius = 2.5
            background.addSubview(rail)
        case .stickyNote:
            background.layer?.backgroundColor = preset.backgroundColor.cgColor
            background.layer?.borderColor = Self.stickyNoteShade.withAlphaComponent(0.45).cgColor
            background.layer?.borderWidth = 0.5
            background.layer?.shadowColor = NSColor.black.cgColor
            background.layer?.shadowOpacity = 0.3
            background.layer?.shadowRadius = 9
            background.layer?.shadowOffset = CGSize(width: 2, height: -4)
            let adhesive = NSView(frame: NSRect(x: 0, y: frame.height - 14,
                                                 width: frame.width, height: 14))
            adhesive.wantsLayer = true
            adhesive.layer?.backgroundColor = Self.stickyNoteShade.withAlphaComponent(0.45).cgColor
            adhesive.autoresizingMask = [.width, .minYMargin]
            background.addSubview(adhesive)
            let fold = CAShapeLayer()
            let foldPath = CGMutablePath()
            foldPath.move(to: CGPoint(x: frame.width - 19, y: 0))
            foldPath.addLine(to: CGPoint(x: frame.width, y: 0))
            foldPath.addLine(to: CGPoint(x: frame.width, y: 19))
            foldPath.closeSubpath()
            fold.path = foldPath
            fold.fillColor = Self.stickyNoteShade.cgColor
            background.layer?.addSublayer(fold)
        case .licensePlate:
            background.layer?.backgroundColor = preset.backgroundColor.cgColor
            let face = NSView(frame: background.bounds.insetBy(dx: 3, dy: 3))
            face.wantsLayer = true
            face.layer?.backgroundColor =
                NSColor(calibratedRed: 0.94, green: 0.93, blue: 0.87, alpha: 1).cgColor
            face.layer?.cornerRadius = 4
            face.layer?.borderColor = NSColor(calibratedWhite: 0.25, alpha: 1).cgColor
            face.layer?.borderWidth = 1.5
            face.autoresizingMask = [.width, .height]
            background.addSubview(face)
        }
        background.layer?.cornerRadius = preset.cornerRadius
        background.autoresizingMask = [.width, .height]
        panel.contentView?.addSubview(background)

        switch preset {
        case .basic, .accentRail:
            let text = CATextLayer()
            text.string = NSAttributedString(
                string: preset.displayText(title),
                attributes: [.font: preset.font, .foregroundColor: preset.textColor]
            )
            text.alignmentMode = .center
            text.isWrapped = false
            text.truncationMode = .none
            text.contentsScale = panel.backingScaleFactor
            let textHeight = ceil(preset.font.ascender - preset.font.descender) + 2
            text.frame = CGRect(
                x: 0, y: (frame.height - textHeight) / 2,
                width: frame.width, height: textHeight
            )
            background.layer?.addSublayer(text)
        case .stickyNote:
            let label = NSTextField(wrappingLabelWithString: preset.displayText(title))
            label.font = preset.font
            label.textColor = preset.textColor
            label.alignment = .left
            label.lineBreakMode = .byWordWrapping
            label.frame = NSRect(x: 14, y: 16, width: frame.width - 28,
                                 height: frame.height - 42)
            label.autoresizingMask = [.width, .height]
            background.addSubview(label)
        case .licensePlate:
            let label = NSTextField(labelWithString: preset.displayText(title))
            let padding: CGFloat = 12
            label.textColor = preset.textColor
            label.font = preset.font
            label.alignment = .center
            label.lineBreakMode = .byTruncatingMiddle
            let labelHeight = label.intrinsicContentSize.height
            label.frame = NSRect(
                x: padding,
                y: (frame.height - labelHeight) / 2,
                width: frame.width - padding * 2,
                height: labelHeight
            )
            label.autoresizingMask = [.width, .minYMargin, .maxYMargin]
            panel.contentView?.addSubview(label)
        }
        panel.orderFrontRegardless()
        return panel
    }

    @ViewBuilder
    func previewPlate(_ title: String, compact: Bool = false)
        -> some View
    {
        let preset = self
        switch preset {
        case .basic:
            Text(title)
                .font(Font(preset.font))
                .foregroundStyle(Color(nsColor: preset.textColor))
                .lineLimit(1)
                .padding(.horizontal, compact ? 12 : 18)
                .frame(height: compact ? 32 : 36)
                .background(
                    Color(nsColor: preset.backgroundColor),
                    in: RoundedRectangle(cornerRadius: preset.cornerRadius)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: preset.cornerRadius)
                        .stroke(Color.white.opacity(0.14), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.22), radius: 5, y: 2)
        case .accentRail:
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Color(nsColor: NameplatePreset.accentRailColor))
                    .frame(width: 5, height: compact ? 17 : 22)
                Text(title)
                    .font(Font(preset.font))
                    .foregroundStyle(Color(nsColor: preset.textColor))
                    .lineLimit(1)
            }
            .padding(.horizontal, compact ? 10 : 12)
            .frame(height: compact ? 32 : 36)
            .background(Color(nsColor: preset.backgroundColor),
                        in: RoundedRectangle(cornerRadius: preset.cornerRadius))
            .shadow(color: .black.opacity(0.22), radius: 5, y: 2)
        case .stickyNote:
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: preset.cornerRadius)
                    .fill(Color(nsColor: preset.backgroundColor))
                Color(nsColor: Self.stickyNoteShade).opacity(0.45)
                    .frame(height: compact ? 10 : 14)
                Text(title)
                    .font(Font(preset.font))
                    .foregroundStyle(Color(nsColor: preset.textColor))
                    .multilineTextAlignment(.leading)
                    .lineLimit(compact ? 2 : 4)
                    .padding(.horizontal, compact ? 9 : 14)
                    .padding(.top, compact ? 17 : 26)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 19))
                    path.addLine(to: CGPoint(x: 19, y: 19))
                    path.addLine(to: CGPoint(x: 19, y: 0))
                    path.closeSubpath()
                }
                .fill(Color(nsColor: Self.stickyNoteShade))
                .frame(width: 19, height: 19)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
            .frame(width: compact ? 80 : 120, height: compact ? 72 : 104)
            .clipShape(RoundedRectangle(cornerRadius: preset.cornerRadius))
            .shadow(color: .black.opacity(0.3), radius: 9, x: 2, y: 4)
        case .licensePlate:
            Text(preset.displayText(title))
                .font(
                    Font(compact ? .monospacedSystemFont(ofSize: 12, weight: .bold) : preset.font)
                )
                .foregroundStyle(Color(nsColor: preset.textColor))
                .lineLimit(1)
                .padding(.horizontal, compact ? 8 : 12)
                .frame(height: compact ? 25 : 34)
                .background(
                    Color(red: 0.94, green: 0.93, blue: 0.87),
                    in: RoundedRectangle(cornerRadius: 4)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color(white: 0.25), lineWidth: 1.5)
                )
                .padding(3)
                .background(
                    Color(nsColor: preset.backgroundColor),
                    in: RoundedRectangle(cornerRadius: preset.cornerRadius))
        }
    }
}
