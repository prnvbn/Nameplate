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
        let textWidth = (thumbnail.title as NSString).size(withAttributes: [.font: preset.font]).width
        let width = min(textWidth + 56, max(thumbnail.frame.width - 16, 100), 400)
        let height: CGFloat = 42
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
        background.layer?.backgroundColor = preset.backgroundColor.cgColor
        background.layer?.cornerRadius = preset.cornerRadius
        background.autoresizingMask = [.width, .height]
        panel.contentView?.addSubview(background)

        let label = NSTextField(labelWithString: title)
        label.cell = VerticallyCenteredTitleCell(textCell: title)
        label.frame = NSRect(x: 18, y: 0, width: frame.width - 36, height: frame.height)
        label.autoresizingMask = [.width, .height]
        label.textColor = preset.textColor
        label.font = preset.font
        label.lineBreakMode = .byTruncatingMiddle
        panel.contentView?.addSubview(label)
        panel.orderFrontRegardless()
        return panel
    }
}

private final class VerticallyCenteredTitleCell: NSTextFieldCell {
    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        var drawingRect = super.drawingRect(forBounds: rect)
        let textHeight = cellSize(forBounds: rect).height
        drawingRect.origin.y += (drawingRect.height - textHeight) / 2
        drawingRect.size.height = textHeight
        return drawingRect
    }
}
