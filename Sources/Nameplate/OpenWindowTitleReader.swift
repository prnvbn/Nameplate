import AppKit
import ApplicationServices

@MainActor
enum OpenWindowTitleReader {
    static func sampleTitle(for bundleIdentifier: String) -> String? {
        guard AXIsProcessTrusted() else { return nil }
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier) {
            let application = AXUIElementCreateApplication(app.processIdentifier)
            var windowsValue: CFTypeRef?
            guard AXUIElementCopyAttributeValue(application, kAXWindowsAttribute as CFString, &windowsValue) == .success,
                  let windows = windowsValue as? [AXUIElement]
            else { continue }
            for window in windows {
                var titleValue: CFTypeRef?
                guard AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue) == .success,
                      let title = titleValue as? String,
                      !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                else { continue }
                return title
            }
        }
        return nil
    }
}
