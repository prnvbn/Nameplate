import SwiftUI

@main
struct Nameplate: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            Button("Settings…") { delegate.openSettings() }
            Divider()
            Button("Quit Nameplate") { delegate.quitNameplate() }
        } label: {
            Text("NP")
        }

        Settings {
            ApplicationSettingsView(onChange: { delegate.settingsDidChange() })
        }
    }
}
