import AppKit
import ApplicationServices

struct MissionControlThumbnail {
    let title: String
    let frame: CGRect
}

@MainActor
func zedMissionControlThumbnails(titles: [String]) -> [MissionControlThumbnail] {
    guard AXIsProcessTrusted(), !titles.isEmpty else { return [] }

    var thumbnails: [MissionControlThumbnail] = []
    for bundleIdentifier in ["com.apple.WindowManager", "com.apple.dock"] {
        guard let app = NSRunningApplication.runningApplications(
            withBundleIdentifier: bundleIdentifier
        ).first else { continue }

        var pending = [AXUIElementCreateApplication(app.processIdentifier)]
        var visited = 0
        while !pending.isEmpty && visited < 500 {
            let element = pending.removeLast()
            visited += 1

            if let name = axString(element, kAXTitleAttribute as CFString)
                ?? axString(element, kAXDescriptionAttribute as CFString),
                let title = titles.first(where: { name == $0 || name.contains($0) }),
                let frame = axFrame(element),
                frame.width > 0, frame.height > 0
            {
                thumbnails.append(MissionControlThumbnail(title: title, frame: frame))
            }

            if let children = axChildren(element) {
                pending.append(contentsOf: children)
            }
        }
    }
    return thumbnails
}

@MainActor
func inspectMissionControl() {
    let titles = getAppWindowTitles("Zed")
    let thumbnails = zedMissionControlThumbnails(titles: titles)
    print("Found \(thumbnails.count) Zed Mission Control thumbnails")
    for thumbnail in thumbnails {
        print("Zed thumbnail: \(thumbnail.title), frame: \(thumbnail.frame)")
    }
}

private func axChildren(_ element: AXUIElement) -> [AXUIElement]? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success
    else { return nil }
    return value as? [AXUIElement]
}

private func axString(_ element: AXUIElement, _ attribute: CFString) -> String? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return nil }
    return value as? String
}

private func axFrame(_ element: AXUIElement) -> CGRect? {
    var positionValue: CFTypeRef?
    var sizeValue: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
        AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
        let positionValue, let sizeValue,
        CFGetTypeID(positionValue) == AXValueGetTypeID(),
        CFGetTypeID(sizeValue) == AXValueGetTypeID()
    else { return nil }

    let positionAXValue = positionValue as! AXValue
    let sizeAXValue = sizeValue as! AXValue
    guard AXValueGetType(positionAXValue) == .cgPoint,
        AXValueGetType(sizeAXValue) == .cgSize
    else { return nil }

    var position = CGPoint.zero
    var size = CGSize.zero
    guard AXValueGetValue(positionAXValue, .cgPoint, &position),
        AXValueGetValue(sizeAXValue, .cgSize, &size)
    else { return nil }
    return CGRect(origin: position, size: size)
}
