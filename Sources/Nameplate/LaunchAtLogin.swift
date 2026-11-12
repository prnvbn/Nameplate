import Foundation
import ServiceManagement

@MainActor
enum LaunchAtLogin {
    static var isPackagedApp: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    static var isEnabled: Bool {
        guard #available(macOS 13.0, *) else { return false }
        return switch SMAppService.mainApp.status {
        case .enabled, .requiresApproval: true
        case .notRegistered, .notFound: false
        @unknown default: false
        }
    }

    static var requiresApproval: Bool {
        guard #available(macOS 13.0, *) else { return false }
        return SMAppService.mainApp.status == .requiresApproval
    }

    static func setEnabled(_ enabled: Bool) throws {
        guard #available(macOS 13.0, *) else { return }
        if enabled {
            if !isEnabled { try SMAppService.mainApp.register() }
        } else if isEnabled {
            try SMAppService.mainApp.unregister()
        }
    }

    static func openSystemSettings() {
        guard #available(macOS 13.0, *) else { return }
        SMAppService.openSystemSettingsLoginItems()
    }
}
