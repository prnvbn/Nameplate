import AppKit

@MainActor
final class MissionControlTitleOverlay {
    private struct ThumbnailKey: Hashable {
        let title: String
        let occurrence: Int
    }

    private var panels: [ThumbnailKey: NSPanel] = [:]

    func show(thumbnails: [MissionControlThumbnail]) {
        guard !thumbnails.isEmpty else {
            hide()
            return
        }

        var occurrences: [String: Int] = [:]
        var currentKeys: Set<ThumbnailKey> = []

        for thumbnail in thumbnails {
            let occurrence = occurrences[thumbnail.title, default: 0]
            occurrences[thumbnail.title] = occurrence + 1
            let key = ThumbnailKey(title: thumbnail.title, occurrence: occurrence)
            currentKeys.insert(key)

            let frame = labelFrame(for: thumbnail.frame)
            if let panel = panels[key] {
                if panel.frame != frame {
                    panel.setFrame(frame, display: true)
                }
            } else {
                panels[key] = makePanel(title: thumbnail.title, frame: frame)
            }
        }

        for key in Set(panels.keys).subtracting(currentKeys) {
            panels.removeValue(forKey: key)?.close()
        }
    }

    func hide() {
        panels.values.forEach { $0.close() }
        panels.removeAll()
    }

    private func labelFrame(for thumbnailFrame: CGRect) -> NSRect {
        let width = min(max(thumbnailFrame.width - 16, 80), 400)
        return NSRect(
            x: thumbnailFrame.minX + 8,
            y: (NSScreen.screens.first?.frame.maxY ?? 0) - thumbnailFrame.minY - 30,
            width: width,
            height: 24
        )
    }

    private func makePanel(title: String, frame: NSRect) -> NSPanel {
        let panel = NSPanel(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        let label = NSTextField(labelWithString: title)
        label.frame = NSRect(origin: .zero, size: frame.size)
        label.autoresizingMask = [.width, .height]
        label.textColor = .white
        label.backgroundColor = NSColor.black.withAlphaComponent(0.7)
        label.drawsBackground = true
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.lineBreakMode = .byTruncatingMiddle
        panel.contentView?.addSubview(label)
        panel.orderFrontRegardless()
        return panel
    }
}
