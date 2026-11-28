import AppKit
import ApplicationServices

struct MissionControlThumbnail {
    let windowID: Int
    let bundleIdentifier: String
    let title: String
    let frame: CGRect
}

private struct AppWindowTitle {
    var text: String?
}

@MainActor
func missionControlThumbnails(for appBundleIdentifiers: [String]) -> [MissionControlThumbnail] {
    guard AXIsProcessTrusted() else { return [] }
    let appWindowTitles = windowTitles(for: appBundleIdentifiers)
    guard !appWindowTitles.isEmpty else { return [] }

    var thumbnails: [MissionControlThumbnail] = []
    for bundleIdentifier in ["com.apple.WindowManager", "com.apple.dock"] {
        guard
            let app = NSRunningApplication.runningApplications(
                withBundleIdentifier: bundleIdentifier
            ).first
        else { continue }

        var pending = [AXUIElementCreateApplication(app.processIdentifier)]
        var visited = 0
        while !pending.isEmpty && visited < 500 {
            let element = pending.removeLast()
            visited += 1

            if let identifier = axString(element, kAXIdentifierAttribute as CFString),
                let targetBundleIdentifier = appBundleIdentifiers.first(where: {
                    identifier.hasPrefix($0 + ".space.")
                }),
                let windowID = axWindowID(element),
                let originalTitle = appWindowTitles[windowID],
                let title = axString(element, kAXTitleAttribute as CFString),
                let frame = axFrame(element),
                frame.width > 0, frame.height > 0
            {
                thumbnails.append(
                    MissionControlThumbnail(
                        windowID: windowID,
                        bundleIdentifier: targetBundleIdentifier,
                        title: WindowTitleProcessing.displayTitle(
                            originalTitle.text ?? title, for: targetBundleIdentifier),
                        frame: frame
                    ))
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
    if thumbnails.isEmpty {
        print(missionControlDiagnosticReport(for: appBundleIdentifiers))
    }
    for thumbnail in thumbnails {
        print(
            "Thumbnail: id=\(thumbnail.windowID), title=\(thumbnail.title), frame=\(thumbnail.frame)"
        )
    }
}

@MainActor
func missionControlDiagnosticReport(for appBundleIdentifiers: [String]) -> String {
    var lines: [String] = []
    func print(_ line: String) { lines.append(line) }
    print("Mission Control diagnostics: accessibilityTrusted=\(AXIsProcessTrusted())")
    guard AXIsProcessTrusted() else { return lines.joined(separator: "\n") }
    if let surfaces = CGWindowListCopyWindowInfo(
        [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
    ) as? [[String: Any]] {
        let systemPIDs = Set(
            ["com.apple.dock", "com.apple.WindowManager"].flatMap {
                NSRunningApplication.runningApplications(withBundleIdentifier: $0).map(
                    \.processIdentifier)
            })
        for surface in surfaces {
            guard let owner = surface[kCGWindowOwnerPID as String] as? NSNumber,
                systemPIDs.contains(owner.int32Value)
            else { continue }
            print(
                "System surface: pid=\(owner), layer=\(String(describing: surface[kCGWindowLayer as String])), bounds=\(String(describing: surface[kCGWindowBounds as String]))"
            )
        }
    } else {
        print("Window list unavailable")
    }
    let windows = windowTitles(for: appBundleIdentifiers)
    print("Selected application window IDs: \(windows.keys.sorted())")
    for bundleIdentifier in ["com.apple.WindowManager", "com.apple.dock"] {
        guard
            let app = NSRunningApplication.runningApplications(
                withBundleIdentifier: bundleIdentifier
            ).first
        else {
            print("\(bundleIdentifier): not running")
            continue
        }
        var pending = [AXUIElementCreateApplication(app.processIdentifier)]
        var visited = 0
        var failures: [Int32: Int] = [:]
        while let element = pending.popLast(), visited < 500 {
            visited += 1
            let role = axString(element, kAXRoleAttribute as CFString) ?? "missing"
            let identifier = axString(element, kAXIdentifierAttribute as CFString)
            let windowID = axWindowID(element)
            var attributes: CFArray?
            let result = AXUIElementCopyAttributeNames(element, &attributes)
            if result != .success { failures[result.rawValue, default: 0] += 1 }
            // Omit window titles and descriptions from diagnostic output.
            print(
                "\(bundleIdentifier) element \(visited): role=\(role), identifier=\(identifier ?? "missing"), wid=\(windowID.map(String.init) ?? "missing"), matchedWindow=\(windowID.map { windows[$0] != nil } ?? false), hasTitle=\(axString(element, kAXTitleAttribute as CFString) != nil), frame=\(String(describing: axFrame(element))), attributes=\((attributes as? [String] ?? []).sorted())"
            )
            if let children = axChildren(element) { pending.append(contentsOf: children) }
        }
        print(
            "\(bundleIdentifier): inspected=\(visited), pending=\(pending.count), attributeErrors=\(failures)"
        )
    }
    return lines.joined(separator: "\n")
}

private func windowTitles(for appBundleIdentifiers: [String]) -> [Int: AppWindowTitle] {
    let appPIDs = Set(
        NSWorkspace.shared.runningApplications
            .filter { appBundleIdentifiers.contains($0.bundleIdentifier ?? "") }
            .map(\.processIdentifier))
    guard
        let windows = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID)
            as? [[String: Any]]
    else { return [:] }

    var titles: [Int: AppWindowTitle] = [:]
    var windowIDsByPID: [pid_t: Set<Int>] = [:]
    for window in windows {
        guard let owner = window[kCGWindowOwnerPID as String] as? NSNumber,
            appPIDs.contains(owner.int32Value),
            let number = window[kCGWindowNumber as String] as? NSNumber
        else { continue }
        let windowID = number.intValue
        titles[windowID] = AppWindowTitle(
            text: (window[kCGWindowName as String] as? String).flatMap {
                $0.isEmpty ? nil : $0
            })
        windowIDsByPID[owner.int32Value, default: []].insert(windowID)
    }

    for (pid, windowIDs) in windowIDsByPID {
        let application = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(application, kAXWindowsAttribute as CFString, &value)
                == .success,
            let windows = value as? [AXUIElement]
        else { continue }
        for window in windows {
            guard let windowID = axWindowID(window), windowIDs.contains(windowID),
                let title = axString(window, kAXTitleAttribute as CFString), !title.isEmpty
            else { continue }
            titles[windowID]?.text = title
        }
    }
    return titles
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
    guard
        AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success
    else { return nil }
    return value as? [AXUIElement]
}

private func axFrame(_ element: AXUIElement) -> CGRect? {
    var positionValue: CFTypeRef?
    var sizeValue: CFTypeRef?
    guard
        AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue)
            == .success,
        AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue)
            == .success,
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
