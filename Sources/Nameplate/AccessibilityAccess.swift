import AppKit
import ApplicationServices
import Combine

@MainActor
final class AccessibilityAccess: ObservableObject {
    static let shared = AccessibilityAccess()

    @Published private(set) var isGranted = AXIsProcessTrusted()
    private var refreshTimer: Timer?

    static var settingsPaneName: String {
        if #available(macOS 27, *) { return "Device Control and Data Access" }
        return "Accessibility"
    }

    func startMonitoring() {
        guard refreshTimer == nil else { return }
        refresh()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        refreshTimer = timer
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
    }

    func refresh() {
        let granted = AXIsProcessTrusted()
        if isGranted != granted { isGranted = granted }
    }

    func request() {
        guard
            let url = URL(
                string:
                    "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
