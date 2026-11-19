// Run from the repository root:
// swiftc -parse-as-library scripts/render-style-previews.swift Sources/Nameplate/NameplatePreset.swift Sources/Nameplate/MissionControlInspector.swift Sources/Nameplate/WindowTitleProcessing.swift -o /tmp/nameplate-style-previews
// /tmp/nameplate-style-previews
import AppKit
import SwiftUI

@main
struct RenderStylePreviews {
    @MainActor
    static func main() throws {
        // Keep documentation previews independent of saved application preferences.
        UserDefaults.standard.setVolatileDomain([
            "basicOpacity": 0.82,
            "basicTextColor": [0.96, 0.96, 0.96],
            "accentRailColor": [214.0 / 255, 245.0 / 255, 156.0 / 255],
            "stickyNoteColor": [1.0, 0.96, 0.70],
        ], forName: UserDefaults.argumentDomain)
        let directory = URL(fileURLWithPath: "Assets/styles", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let styles: [(NameplatePreset, String)] = [
            (.basic, "basic"), (.accentRail, "accent-rail"),
            (.stickyNote, "sticky-note"), (.licensePlate, "number-plate"),
        ]
        for (preset, filename) in styles {
            let preview = preset.previewPlate("Project notes")
                .frame(width: 380, height: 200)
                .background(Color(red: 0.88, green: 0.91, blue: 0.94))
                .environment(\.colorScheme, .light)
            let renderer = ImageRenderer(content: preview)
            renderer.scale = 2
            guard let image = renderer.cgImage,
                  let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
            else { fatalError("Could not render \(preset.name)") }
            try data.write(to: directory.appendingPathComponent("\(filename).png"))
        }
    }
}
