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

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var overlay: NSPanel?
    private let missionControlMonitor = MissionControlMonitor()

    func applicationDidFinishLaunching(
        _ notification: Notification
    ) {
        print("Nameplate launched")

        let item = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )
        item.button?.title = "NP"
        statusItem = item

        let menu = NSMenu()

        let inspectItem = NSMenuItem(
            title: "Inspect Mission Control",
            action: #selector(inspectNow),
            keyEquivalent: ""
        )

        inspectItem.target = self
        menu.addItem(inspectItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "Quit Nameplate",
            action: #selector(quitNameplate),
            keyEquivalent: "q"
        )

        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu

        let titles = getAppWindows("Zed")

        print("Found \(titles.count) Zed window titles")

        for title in titles {
            print("Zed window:", title)
        }

        startMissionControlMonitoring()
    }

    func startMissionControlMonitoring() {
        missionControlMonitor.start { isVisible in
            if isVisible {
                print("Mission Control entered")
                inspectMissionControl()
            } else {
                print("Mission Control exited")
            }
        }
    }


    @objc func inspectNow() {
        inspectMissionControl()
    }

    func showTestOverlay() {
        let rect = NSRect(
            x: 220,
            y: 220,
            width: 400,
            height: 90
        )

        let panel = NSPanel(
            contentRect: rect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.level = .floating

        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .fullScreenAuxiliary,
        ]

        let tf = NSTextField(
            labelWithString: "TEST"
        )

        tf.font = NSFont.systemFont(ofSize: 18)
        tf.textColor = .white

        tf.frame = NSRect(
            x: 20,
            y: 30,
            width: 200,
            height: 40
        )

        panel.contentView?.addSubview(tf)

        self.overlay = panel
        panel.orderFrontRegardless()
    }

    @objc func quitNameplate() {
        missionControlMonitor.stop()
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

        withExtendedLifetime(delegate) {
            app.run()
        }
    }
}
