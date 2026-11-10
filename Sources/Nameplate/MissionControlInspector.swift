import AppKit
import ApplicationServices

struct MissionControlThumbnail {
    let windowID: Int
    let title: String
    let frame: CGRect
}

@MainActor
func missionControlThumbnails(for appBundleIdentifiers: [String]) -> [MissionControlThumbnail] {
    guard AXIsProcessTrusted() else { return [] }
    let appWindowIDs = windowIDs(for: appBundleIdentifiers)
    guard !appWindowIDs.isEmpty else { return [] }

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

            if let identifier = axString(element, kAXIdentifierAttribute as CFString),
                appBundleIdentifiers.contains(where: { identifier.hasPrefix($0 + ".space.") }),
                let windowID = axWindowID(element),
                appWindowIDs.contains(windowID),
                let title = axString(element, kAXTitleAttribute as CFString),
                let frame = axFrame(element),
                frame.width > 0, frame.height > 0
            {
                thumbnails.append(MissionControlThumbnail(windowID: windowID, title: title, frame: frame))
            }

            if let children = axChildren(element) {
                pending.append(contentsOf: children)
            }
        }
    }
    return thumbnails
}

@MainActor
func inspectMissionControl(for appBundleIdentifiers: [String]) {
    let thumbnails = missionControlThumbnails(for: appBundleIdentifiers)
    print("Found \(thumbnails.count) Mission Control thumbnails for \(appBundleIdentifiers)")
    for thumbnail in thumbnails {
        print("Thumbnail: id=\(thumbnail.windowID), title=\(thumbnail.title), frame=\(thumbnail.frame)")
    }
}

private func windowIDs(for appBundleIdentifiers: [String]) -> Set<Int> {
    let appPIDs = Set(NSWorkspace.shared.runningApplications
        .filter { appBundleIdentifiers.contains($0.bundleIdentifier ?? "") }
        .map(\.processIdentifier))
    guard let windows = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID)
        as? [[String: Any]] else { return [] }

    return Set(windows.compactMap { window in
        guard let owner = window[kCGWindowOwnerPID as String] as? NSNumber,
            appPIDs.contains(owner.int32Value),
            let number = window[kCGWindowNumber as String] as? NSNumber
        else { return nil }
        return number.intValue
    })
}

private func axWindowID(_ element: AXUIElement) -> Int? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, "wid" as CFString, &value) == .success else {
        return nil
    }
    if let number = value as? NSNumber { return number.intValue }
    if let string = value as? String { return Int(string) }
    return nil
}

private func axString(_ element: AXUIElement, _ attribute: CFString) -> String? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return nil }
    return value as? String
}

private func axChildren(_ element: AXUIElement) -> [AXUIElement]? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success
    else { return nil }
    return value as? [AXUIElement]
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
