import AppKit
import SwiftUI

private let nameplatePresetDefaultsKey = "nameplatePreset"

@MainActor
enum NameplatePreset: String, CaseIterable, Identifiable {
    case native
    case licensePlate

    var id: String { rawValue }

    var name: String {
        switch self {
        case .native: "Native"
        case .licensePlate: "Number Plate"
        }
    }

    var description: String {
        switch self {
        case .native: "Compact dark label with macOS system type"
        case .licensePlate: "Ivory face, bold lettering, and a dark border"
        }
    }

    var backgroundColor: NSColor {
        switch self {
        case .native: NSColor(calibratedWhite: 0.12, alpha: 0.82)
        case .licensePlate: NSColor(calibratedWhite: 0.08, alpha: 1)
        }
    }

    var textColor: NSColor {
        switch self {
        case .native: NSColor(calibratedWhite: 1, alpha: 0.96)
        case .licensePlate: NSColor(calibratedWhite: 0.08, alpha: 1)
        }
    }

    var font: NSFont {
        switch self {
        case .native: .systemFont(ofSize: 15, weight: .semibold)
        case .licensePlate: .monospacedSystemFont(ofSize: 18, weight: .bold)
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .native: 18
        case .licensePlate: 7
        }
    }

    func displayText(_ title: String) -> String {
        self == .licensePlate ? title.uppercased() : title
    }

    static var selected: NameplatePreset {
        get {
            NameplatePreset(
                rawValue: UserDefaults.standard.string(forKey: nameplatePresetDefaultsKey) ?? "")
                ?? .native
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
        case .native:
            width = ceil(textWidth) + 44
            height = 36
        case .licensePlate:
            width = min(textWidth + 32, max(thumbnail.frame.width - 16, 100), 400)
            height = 40
        }
        return NSRect(
            x: thumbnail.frame.midX - width / 2,
            y: (NSScreen.screens.first?.frame.maxY ?? 0) - thumbnail.frame.midY - height / 2,
            width: width,
            height: height
        )
    }

    func makePanel(title: String, frame: NSRect) -> NSPanel {
        let preset = self
        let panel = NSPanel(
            contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        let background = NSView(frame: NSRect(origin: .zero, size: frame.size))
        background.wantsLayer = true
        switch preset {
        case .native:
            background.layer?.backgroundColor = preset.backgroundColor.cgColor
            background.layer?.borderColor = NSColor(calibratedWhite: 1, alpha: 0.14).cgColor
            background.layer?.borderWidth = 0.5
            background.layer?.shadowColor = NSColor.black.cgColor
            background.layer?.shadowOpacity = 0.22
            background.layer?.shadowRadius = 5
            background.layer?.shadowOffset = CGSize(width: 0, height: -2)
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
        case .native:
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
        case .native:
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
