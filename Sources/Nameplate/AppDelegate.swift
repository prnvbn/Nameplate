import AppKit
import Combine
import CoreServices

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let missionControlMonitor = MissionControlMonitor()
    private let titleOverlay = MissionControlTitleOverlay()
    private var overlayRefreshTimer: Timer?
    private var settingsWindow: SettingsWindow?
    private var accessibilityObservation: AnyCancellable?

    func applicationDidFinishLaunching(
        _ notification: Notification
    ) {
        let launchEvent = NSAppleEventManager.shared().currentAppleEvent
        let openedByUser = launchEvent?.eventID == kAEOpenApplication
            && launchEvent?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == nil
        print("Nameplate launched")
        NSApp.setActivationPolicy(.accessory)
        AppUpdater.shared.start()
        AccessibilityAccess.shared.startMonitoring()
        accessibilityObservation = AccessibilityAccess.shared.$isGranted.sink { [weak self] granted in
            guard granted, ApplicationSetup.shouldOfferApplications() else { return }
            ApplicationSetup.markApplicationsPresented()
            self?.openSettings(showApplications: true)
        }
        if !AccessibilityAccess.shared.isGranted {
            openSettings(showAccessibilitySetup: true)
        } else if openedByUser && settingsWindow == nil {
            openSettings()
        }

        startMissionControlMonitoring()
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication, hasVisibleWindows flag: Bool
    ) -> Bool {
        openSettings()
        return false
    }

    func startMissionControlMonitoring() {
        missionControlMonitor.start { [weak self] isVisible in
            guard let self else { return }
            if isVisible {
                print("Mission Control entered")
                self.refreshMissionControlTitles()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                    guard let self, self.overlayRefreshTimer != nil else { return }
                    inspectMissionControl(for: SelectedApplications.bundleIdentifiers)
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
        let thumbnails = missionControlThumbnails(for: SelectedApplications.bundleIdentifiers)
        titleOverlay.show(thumbnails: thumbnails, preset: NameplatePreset.selected)
    }

    func settingsDidChange() {
        titleOverlay.hide()
        refreshMissionControlTitles()
    }

    func openSettings(showAccessibilitySetup: Bool = false, showApplications: Bool = false) {
        if settingsWindow == nil {
            settingsWindow = SettingsWindow(showApplications: showApplications) { [weak self] in
                self?.settingsDidChange()
            }
        }
        settingsWindow?.present()
        if showApplications {
            NotificationCenter.default.post(
                name: SettingsWindow.applicationsSetupRequested, object: nil)
        }
        if showAccessibilitySetup {
            NotificationCenter.default.post(
                name: SettingsWindow.accessibilitySetupRequested, object: nil)
        }
    }

    func quitNameplate() {
        overlayRefreshTimer?.invalidate()
        titleOverlay.hide()
        missionControlMonitor.stop()
        NSApp.terminate(nil)
    }
}
