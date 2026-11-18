import SwiftUI

@main
struct Nameplate: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            if !AccessibilityAccess.isGranted {
                Button("Accessibility Access Required…") { delegate.openSettings() }
                Divider()
            }
            Button("Settings…") { delegate.openSettings() }
            Divider()
            Button("Quit Nameplate") { delegate.quitNameplate() }
        } label: {
            Image("MenuBarIcon", bundle: .module)
                .renderingMode(.template)
                .accessibilityLabel("Nameplate")
        }

        Settings {
            ApplicationSettingsView(onChange: { delegate.settingsDidChange() })
        }
    }
}
