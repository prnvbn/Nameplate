import AppKit

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

        let windows = getAppWindows("Zed")

        print("Found \(windows.count) Zed windows")

        for window in windows {
            print("Zed window: \(window.title), frame: \(window.frame)")
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

