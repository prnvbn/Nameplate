import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let missionControlMonitor = MissionControlMonitor()
    private let titleOverlay = MissionControlTitleOverlay()
    private var overlayRefreshTimer: Timer?

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

        startMissionControlMonitoring()
    }

    func startMissionControlMonitoring() {
        missionControlMonitor.start { [weak self] isVisible in
            guard let self else { return }
            if isVisible {
                print("Mission Control entered")
                self.refreshMissionControlTitles()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                    guard let self, self.overlayRefreshTimer != nil else { return }
                    inspectMissionControl(for: targetApplicationBundleIdentifier)
                }
                let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
                    MainActor.assumeIsolated {
                        self?.refreshMissionControlTitles()
                    }
                }
                self.overlayRefreshTimer = timer
                RunLoop.main.add(timer, forMode: .common)
            } else {
                print("Mission Control exited")
                self.overlayRefreshTimer?.invalidate()
                self.overlayRefreshTimer = nil
                self.titleOverlay.hide()
            }
        }
    }

    private func refreshMissionControlTitles() {
        let thumbnails = missionControlThumbnails(for: targetApplicationBundleIdentifier)
        titleOverlay.show(thumbnails: thumbnails)
    }

    @objc func inspectNow() {
        inspectMissionControl(for: targetApplicationBundleIdentifier)
    }

    @objc func quitNameplate() {
        overlayRefreshTimer?.invalidate()
        titleOverlay.hide()
        missionControlMonitor.stop()
        NSApp.terminate(nil)
    }
}

