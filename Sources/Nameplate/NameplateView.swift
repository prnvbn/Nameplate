import AppKit
import SwiftUI

/// The AppKit renderer used directly by overlay panels and bridged into settings.
final class NameplateContentView: NSView {
    init(preset: NameplatePreset, title: String, frame: NSRect,
         scale: CGFloat = 1, compact: Bool = false) {
        super.init(frame: frame)
        bounds = NSRect(origin: .zero, size: CGSize(
            width: frame.width / scale, height: frame.height / scale))
        render(preset: preset, title: title, compact: compact)
    }

    required init?(coder: NSCoder) { nil }

    func render(preset: NameplatePreset, title: String, compact: Bool) {
        // Preview updates can change the title or colors without replacing the host view.
        subviews.forEach { $0.removeFromSuperview() }
        let plateFrame = bounds.insetBy(dx: preset.panelInset, dy: preset.panelInset)
        let frame = NSRect(origin: .zero, size: plateFrame.size)
        let font = compact && preset == .licensePlate
            ? NSFont.monospacedSystemFont(ofSize: 12, weight: .bold) : preset.font
        let adhesiveHeight: CGFloat = compact ? 10 : 14
        let background = NSView(frame: plateFrame)
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
            background.layer?.borderColor = NameplatePreset.stickyNoteShade.withAlphaComponent(0.45).cgColor
            background.layer?.borderWidth = 0.5
            background.layer?.shadowColor = NSColor.black.cgColor
            background.layer?.shadowOpacity = 0.3
            background.layer?.shadowRadius = 9
            background.layer?.shadowOffset = CGSize(width: 2, height: -4)
            let adhesive = NSView(frame: NSRect(x: 0, y: frame.height - adhesiveHeight,
                                                 width: frame.width, height: adhesiveHeight))
            adhesive.wantsLayer = true
            adhesive.layer?.backgroundColor = NameplatePreset.stickyNoteShade.withAlphaComponent(0.45).cgColor
            adhesive.autoresizingMask = [.width, .minYMargin]
            background.addSubview(adhesive)
            let fold = CAShapeLayer()
            let foldPath = CGMutablePath()
            foldPath.move(to: CGPoint(x: frame.width - 19, y: 0))
            foldPath.addLine(to: CGPoint(x: frame.width, y: 0))
            foldPath.addLine(to: CGPoint(x: frame.width, y: 19))
            foldPath.closeSubpath()
            fold.path = foldPath
            fold.fillColor = NameplatePreset.stickyNoteShade.cgColor
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
        addSubview(background)

        switch preset {
        case .basic, .accentRail:
            let text = CATextLayer()
            text.string = NSAttributedString(
                string: preset.displayText(title),
                attributes: [.font: font, .foregroundColor: preset.textColor]
            )
            text.alignmentMode = .center
            text.isWrapped = false
            text.truncationMode = .none
            text.contentsScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
            let textHeight = ceil(font.ascender - font.descender) + 2
            text.frame = CGRect(
                x: 0, y: (frame.height - textHeight) / 2,
                width: frame.width, height: textHeight
            )
            background.layer?.addSublayer(text)
        case .stickyNote:
            let label = NSTextField(wrappingLabelWithString: preset.displayText(title))
            label.font = font
            label.textColor = preset.textColor
            label.alignment = .left
            label.lineBreakMode = .byWordWrapping
            label.frame = NSRect(x: compact ? 9 : 14, y: compact ? 9 : 16,
                                 width: frame.width - (compact ? 18 : 28),
                                 height: frame.height - (compact ? 26 : 42))
            label.autoresizingMask = [.width, .height]
            background.addSubview(label)
        case .licensePlate:
            let label = NSTextField(labelWithString: preset.displayText(title))
            let padding: CGFloat = compact ? 8 : 12
            label.textColor = preset.textColor
            label.font = font
            label.alignment = .center
            label.lineBreakMode = .byTruncatingMiddle
            let labelHeight = label.intrinsicContentSize.height
            label.frame = NSRect(
                x: plateFrame.minX + padding,
                y: plateFrame.minY + (frame.height - labelHeight) / 2,
                width: frame.width - padding * 2,
                height: labelHeight
            )
            label.autoresizingMask = [.width, .minYMargin, .maxYMargin]
            addSubview(label)
        }
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        updateTextScale()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateTextScale()
    }

    private func updateTextScale() {
        for background in subviews {
            for text in background.layer?.sublayers?.compactMap({ $0 as? CATextLayer }) ?? [] {
                text.contentsScale = window?.backingScaleFactor ?? 2
            }
        }
    }
}

struct NameplateView: View {
    let preset: NameplatePreset
    let title: String
    var compact = false

    var plateSize: CGSize {
        let font = compact && preset == .licensePlate
            ? NSFont.monospacedSystemFont(ofSize: 12, weight: .bold) : preset.font
        let textWidth = ceil((preset.displayText(title) as NSString)
            .size(withAttributes: [.font: font]).width)
        switch preset {
        case .basic: return CGSize(width: textWidth + (compact ? 24 : 44), height: compact ? 32 : 36)
        case .accentRail: return CGSize(width: textWidth + (compact ? 38 : 52), height: compact ? 32 : 36)
        case .stickyNote: return CGSize(width: compact ? 80 : 120, height: compact ? 72 : 104)
        case .licensePlate: return CGSize(width: textWidth + (compact ? 28 : 32), height: compact ? 31 : 40)
        }
    }

    var body: some View {
        NameplatePreview(preset: preset, title: title, compact: compact, plateSize: plateSize)
            .allowsHitTesting(false)
            .frame(width: plateSize.width + preset.panelInset * 2,
                   height: plateSize.height + preset.panelInset * 2)
            .padding(-preset.panelInset)
    }
}

private struct NameplatePreview: NSViewRepresentable {
    let preset: NameplatePreset
    let title: String
    let compact: Bool
    let plateSize: CGSize

    private var contentSize: CGSize {
        CGSize(width: plateSize.width + preset.panelInset * 2,
               height: plateSize.height + preset.panelInset * 2)
    }

    func makeNSView(context: Context) -> NameplateContentView {
        NameplateContentView(preset: preset, title: title,
                             frame: NSRect(origin: .zero, size: contentSize), compact: compact)
    }

    func updateNSView(_ view: NameplateContentView, context: Context) {
        view.setFrameSize(contentSize)
        view.bounds = NSRect(origin: .zero, size: contentSize)
        view.render(preset: preset, title: title, compact: compact)
    }
}
