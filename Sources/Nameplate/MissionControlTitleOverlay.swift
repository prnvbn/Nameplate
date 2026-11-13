import AppKit

@MainActor
final class MissionControlTitleOverlay {
    private var panels: [Int: NSPanel] = [:]
    private var titles: [Int: String] = [:]

    func show(thumbnails: [MissionControlThumbnail], preset: NameplatePreset) {
        guard !thumbnails.isEmpty else {
            hide()
            return
        }

        var currentIDs: Set<Int> = []

        for thumbnail in thumbnails {
            let windowID = thumbnail.windowID
            currentIDs.insert(windowID)

            let frame = labelFrame(for: thumbnail, preset: preset)
            if let panel = panels[windowID], titles[windowID] == thumbnail.title {
                if panel.frame != frame {
                    panel.setFrame(frame, display: true)
                }
            } else {
                panels.removeValue(forKey: windowID)?.close()
                panels[windowID] = makePanel(title: thumbnail.title, frame: frame, preset: preset)
                titles[windowID] = thumbnail.title
            }
        }

        for windowID in Set(panels.keys).subtracting(currentIDs) {
            panels.removeValue(forKey: windowID)?.close()
            titles.removeValue(forKey: windowID)
        }
    }

    func hide() {
        panels.values.forEach { $0.close() }
        panels.removeAll()
        titles.removeAll()
    }

    private func labelFrame(for thumbnail: MissionControlThumbnail, preset: NameplatePreset) -> NSRect {
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

    private func makePanel(title: String, frame: NSRect, preset: NameplatePreset) -> NSPanel {
        let panel = NSPanel(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        let background = NSView(frame: NSRect(origin: .zero, size: frame.size))
        background.wantsLayer = true
        let labelContainer: NSView
        switch preset {
        case .native:
            background.layer?.backgroundColor = preset.backgroundColor.cgColor
            background.layer?.borderColor = NSColor(calibratedWhite: 1, alpha: 0.14).cgColor
            background.layer?.borderWidth = 0.5
            background.layer?.shadowColor = NSColor.black.cgColor
            background.layer?.shadowOpacity = 0.22
            background.layer?.shadowRadius = 5
            background.layer?.shadowOffset = CGSize(width: 0, height: -2)
            labelContainer = panel.contentView ?? background
        case .licensePlate:
            background.layer?.backgroundColor = preset.backgroundColor.cgColor
            let face = NSView(frame: background.bounds.insetBy(dx: 3, dy: 3))
            face.wantsLayer = true
            face.layer?.backgroundColor = NSColor(calibratedRed: 0.94, green: 0.93, blue: 0.87, alpha: 1).cgColor
            face.layer?.cornerRadius = 4
            face.layer?.borderColor = NSColor(calibratedWhite: 0.25, alpha: 1).cgColor
            face.layer?.borderWidth = 1.5
            face.autoresizingMask = [.width, .height]
            background.addSubview(face)
            labelContainer = panel.contentView ?? background
        }
        background.layer?.cornerRadius = preset.cornerRadius
        background.autoresizingMask = [.width, .height]
        panel.contentView?.addSubview(background)

        if preset == .native {
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
            panel.orderFrontRegardless()
            return panel
        }

        let label = NSTextField(labelWithString: preset.displayText(title))
        let padding: CGFloat = preset == .native ? 22 : 12
        label.textColor = preset.textColor
        label.font = preset.font
        label.alignment = .center
        label.lineBreakMode = preset == .native ? .byClipping : .byTruncatingMiddle
        let labelHeight = label.intrinsicContentSize.height
        label.frame = NSRect(
            x: padding,
            y: (frame.height - labelHeight) / 2,
            width: frame.width - padding * 2,
            height: labelHeight
        )
        label.autoresizingMask = [.width, .minYMargin, .maxYMargin]
        labelContainer.addSubview(label)
        panel.orderFrontRegardless()
        return panel
    }
}
