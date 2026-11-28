import AppKit

/// Polls the compositor surface because Dock AXExpose notifications stopped
/// arriving on macOS 27. Window metadata does not require Accessibility access.
@MainActor
final class MissionControlMonitor {
    private static let pollingInterval: TimeInterval = 0.10
    private static let timerTolerance: TimeInterval = 0.02

    private var timer: Timer?
    private var visibility = MissionControlVisibility()

    func start(onChange: @escaping @MainActor (Bool) -> Void) {
        stop()
        let timer = Timer(timeInterval: Self.pollingInterval, repeats: true) { [weak self] _ in
            // The timer is installed only on the main run loop.
            MainActor.assumeIsolated {
                self?.poll(onChange: onChange)
            }
        }
        timer.tolerance = Self.timerTolerance
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
        poll(onChange: onChange)
        print("Mission Control surface monitor started")
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        visibility = MissionControlVisibility()
    }

    private func poll(onChange: (Bool) -> Void) {
        guard let surfacePresent = missionControlSurfacePresent() else {
            return  // A failed window-list read says nothing about visibility.
        }

        if let isVisible = visibility.update(surfacePresent: surfacePresent) {
            onChange(isVisible)
        }
    }

    func missionControlSurfacePresent() -> Bool? {
        // Resolve current PIDs so a Dock or WindowManager restart cannot leave
        // detection attached to a dead process.
        let dockPID = NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.apple.dock"
        ).first?.processIdentifier
        let windowManagerPID = NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.apple.WindowManager"
        ).first?.processIdentifier

        guard
            let windows = CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
            ) as? [[String: Any]]
        else {
            return nil
        }

        return windows.contains { window in
            guard let owner = window[kCGWindowOwnerPID as String] as? NSNumber,
                let layer = window[kCGWindowLayer as String] as? NSNumber
            else {
                return false
            }
            return Self.isMissionControlSurface(
                ownerPID: owner.int32Value,
                layer: layer.intValue,
                dockPID: dockPID,
                windowManagerPID: windowManagerPID
            )
        }
    }

    static func isMissionControlSurface(
        ownerPID: pid_t,
        layer: Int,
        dockPID: pid_t?,
        windowManagerPID: pid_t?
    ) -> Bool {
        // Dock owns the surface through macOS 26; WindowManager owns it on 27.
        (ownerPID == dockPID && layer == 18)
            || (ownerPID == windowManagerPID && layer == 19)
    }
}

/// Emits a change whenever the sampled surface visibility changes.
struct MissionControlVisibility {
    private(set) var isVisible = false

    mutating func update(surfacePresent: Bool) -> Bool? {
        guard surfacePresent != isVisible else { return nil }
        isVisible = surfacePresent
        return isVisible
    }
}
