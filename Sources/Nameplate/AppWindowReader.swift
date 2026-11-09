import AppKit
import ApplicationServices

func getAppWindowTitles(_ localizedName: String) -> [String] {
    guard AXIsProcessTrusted() else {
        print("Accessibility permission required")
        return []
    }

    let apps = NSWorkspace.shared.runningApplications.filter { $0.localizedName == localizedName }
    var titles: [String] = []

    for app in apps {
        let application = AXUIElementCreateApplication(app.processIdentifier)
        guard let windows = accessibilityValue(application, kAXWindowsAttribute as CFString)
            as? [AXUIElement]
        else { continue }

        for window in windows {
            if let title = accessibilityValue(window, kAXTitleAttribute as CFString) as? String {
                titles.append(title)
            }
        }
    }

    return titles
}

private func accessibilityValue(_ element: AXUIElement, _ attribute: CFString) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return nil }
    return value
}
