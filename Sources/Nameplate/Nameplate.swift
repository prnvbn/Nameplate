import SwiftUI

@main
struct Nameplate: App {
    static let showMenuBarIconKey = "showMenuBarIcon"

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @AppStorage(showMenuBarIconKey) private var showMenuBarIcon = true
    @State private var hasSelectedApplications = !SelectedApplications.bundleIdentifiers.isEmpty
    @ObservedObject private var accessibility = AccessibilityAccess.shared

    var body: some Scene {
        MenuBarExtra(isInserted: $showMenuBarIcon) {
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
            if !hasSelectedApplications {
                Button("Choose Applications…") { delegate.openSettings(showApplications: true) }
                Divider()
            }
            Button("Settings…") { delegate.openSettings() }
            CheckForUpdatesButton()
            Divider()
            Button("Quit Nameplate") { delegate.quitNameplate() }
        } label: {
            Image(nsImage: MenuBarStatusIcon.image(needsAccessibility: !accessibility.isGranted))
                .onReceive(
                    NotificationCenter.default.publisher(for: SelectedApplications.selectionDidChange)
                ) { _ in
                    hasSelectedApplications = !SelectedApplications.bundleIdentifiers.isEmpty
                }
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
