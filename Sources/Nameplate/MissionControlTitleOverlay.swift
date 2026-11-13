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

            let frame = preset.labelFrame(for: thumbnail)
            if let panel = panels[windowID], titles[windowID] == thumbnail.title {
                if panel.frame != frame {
                    panel.setFrame(frame, display: true)
                }
            } else {
                panels.removeValue(forKey: windowID)?.close()
                panels[windowID] = preset.makePanel(
                    title: thumbnail.title, bundleIdentifier: thumbnail.bundleIdentifier,
                    frame: frame)
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

}
