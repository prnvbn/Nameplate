import SwiftUI

@main
struct Nameplate: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @ObservedObject private var accessibility = AccessibilityAccess.shared

    var body: some Scene {
        MenuBarExtra {
            if !accessibility.isGranted {
                Button {
                    delegate.openSettings(showAccessibilitySetup: true)
                } label: {
                    Label(
                        "Accessibility Access Required…", systemImage: "exclamationmark.circle.fill"
                    )
                }
                Divider()
            }
            Button("Settings…") { delegate.openSettings() }
            Divider()
            Button("Quit Nameplate") { delegate.quitNameplate() }
        } label: {
            Image(nsImage: MenuBarStatusIcon.image(needsAccessibility: !accessibility.isGranted))
                .accessibilityLabel(
                    accessibility.isGranted
                        ? "Nameplate" : "Nameplate, Accessibility access required"
                )
                .help(
                    accessibility.isGranted
                        ? "Nameplate"
                        : "Nameplate needs Accessibility access. Open the menu to finish setup.")
        }

        Settings {
            ApplicationSettingsView(onChange: { delegate.settingsDidChange() })
        }
    }
}
