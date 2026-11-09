import AppKit
import ApplicationServices

@MainActor
func inspectMissionControl() {
    guard AXIsProcessTrusted() else {
        print("Accessibility permission required")
        return
    }

    for bundleIdentifier in ["com.apple.WindowManager", "com.apple.dock"] {
        guard let app = NSRunningApplication.runningApplications(
            withBundleIdentifier: bundleIdentifier
        ).first else {
            continue
        }

        let element = AXUIElementCreateApplication(app.processIdentifier)
        var childrenValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element, kAXChildrenAttribute as CFString, &childrenValue
        )

        guard result == .success,
            let children = childrenValue as? [AXUIElement]
        else {
            print("Could not read \(bundleIdentifier) children:", result)
            continue
        }

        print("\(bundleIdentifier) children:", children.count)
        for child in children {
            var identifierValue: CFTypeRef?
            if AXUIElementCopyAttributeValue(
                child, kAXIdentifierAttribute as CFString, &identifierValue
            ) == .success, let identifier = identifierValue as? String {
                print("Child:", identifier)
            }
        }
    }
}

