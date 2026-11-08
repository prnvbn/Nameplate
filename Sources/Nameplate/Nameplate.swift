import AppKit
import ApplicationServices

func getAppWindows(_ localizedName: String) -> [String] {
    guard AXIsProcessTrusted() else {
        print("Accessibility permission required")
        return []
    }

    let apps = NSWorkspace.shared.runningApplications
        .filter { $0.localizedName == localizedName }

    var titles: [String] = []

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

            let result = AXUIElementCopyAttributeValue(
                window,
                kAXTitleAttribute as CFString,
                &titleValue
            )

            if result == .success,
                let title = titleValue as? String
            {
                titles.append(title)
            }
        }
    }

    return titles
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var overlay: NSPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )
        item.button?.title = "NP"
        statusItem = item
        print("Nameplate launched")

        print(getAppWindows("Zed"))

        let menu = NSMenu()
        let quitItem = NSMenuItem(
            title: "Quit Nameplate",
            action: #selector(quitNameplate),
            keyEquivalent: "q"
        )

        quitItem.target = self
        menu.addItem(quitItem)
        item.menu = menu

        showTestOverlay()
    }

    func showTestOverlay() {
        let rect = NSRect(x: 220, y: 220, width: 400, height: 90)
        let panel = NSPanel(
            contentRect: rect,
            styleMask: [.borderless], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .red
        panel.ignoresMouseEvents = true
        panel.level = .floating
        panel.hidesOnDeactivate = false

        let tf = NSTextField(labelWithString: "TEST")
        tf.font = NSFont.systemFont(ofSize: 18)

        tf.frame = NSRect(x: 20, y: 30, width: 200, height: 40)

        panel.contentView?.addSubview(tf)
        panel.orderFrontRegardless()
        self.overlay = panel
    }

    @objc func quitNameplate() {
        NSApp.terminate(nil)
    }
}

@main
struct Nameplate {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
