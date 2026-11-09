import AppKit
import ApplicationServices

struct AppWindow {
    let title: String
    let frame: CGRect
}

func getAppWindows(_ localizedName: String) -> [AppWindow] {
    guard AXIsProcessTrusted() else {
        print("Accessibility permission required")
        return []
    }

    let apps = NSWorkspace.shared.runningApplications
        .filter { $0.localizedName == localizedName }

    var appWindows: [AppWindow] = []

    for app in apps {
        let axApp = AXUIElementCreateApplication(
            app.processIdentifier
        )

        var value: CFTypeRef?

        let result = AXUIElementCopyAttributeValue(
            axApp,
            kAXWindowsAttribute as CFString,
            &value
        )

        guard result == .success,
            let windows = value as? [AXUIElement]
        else {
            continue
        }

        for window in windows {
            var titleValue: CFTypeRef?
            var positionValue: CFTypeRef?
            var sizeValue: CFTypeRef?

            let titleResult = AXUIElementCopyAttributeValue(
                window,
                kAXTitleAttribute as CFString,
                &titleValue
            )
            let positionResult = AXUIElementCopyAttributeValue(
                window, kAXPositionAttribute as CFString, &positionValue
            )
            let sizeResult = AXUIElementCopyAttributeValue(
                window, kAXSizeAttribute as CFString, &sizeValue
            )

            guard titleResult == .success,
                positionResult == .success,
                sizeResult == .success,
                let title = titleValue as? String,
                let positionValue,
                let sizeValue,
                CFGetTypeID(positionValue) == AXValueGetTypeID(),
                CFGetTypeID(sizeValue) == AXValueGetTypeID(),
                let positionAXValue = positionValue as! AXValue?,
                let sizeAXValue = sizeValue as! AXValue?,
                AXValueGetType(positionAXValue) == .cgPoint,
                AXValueGetType(sizeAXValue) == .cgSize
            else { continue }

            var position = CGPoint.zero
            var size = CGSize.zero
            guard AXValueGetValue(positionAXValue, .cgPoint, &position),
                AXValueGetValue(sizeAXValue, .cgSize, &size)
            else { continue }

            appWindows.append(AppWindow(title: title, frame: CGRect(origin: position, size: size)))
        }
    }

    return appWindows
}

