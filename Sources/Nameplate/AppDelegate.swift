import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let missionControlMonitor = MissionControlMonitor()
    private let titleOverlay = MissionControlTitleOverlay()
    private var overlayRefreshTimer: Timer?
    private var settingsWindow: SettingsWindow?

    func applicationDidFinishLaunching(
        _ notification: Notification
    ) {
        print("Nameplate launched")
        NSApp.setActivationPolicy(.accessory)

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
                    inspectMissionControl(for: SelectedApplications.activeBundleIdentifiers)
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
        let thumbnails = missionControlThumbnails(for: SelectedApplications.activeBundleIdentifiers)
        titleOverlay.show(thumbnails: thumbnails, preset: NameplatePreset.selected)
    }

    func settingsDidChange() {
        titleOverlay.hide()
        refreshMissionControlTitles()
    }

    func openSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindow { [weak self] in
                self?.settingsDidChange()
            }
        }
        settingsWindow?.present()
    }

    func quitNameplate() {
        overlayRefreshTimer?.invalidate()
        titleOverlay.hide()
        missionControlMonitor.stop()
        NSApp.terminate(nil)
    }
}
