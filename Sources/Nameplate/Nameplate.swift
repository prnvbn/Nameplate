import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )
        item.button?.title = "NP"
        statusItem = item
        print("Nameplate launched")

        let menu = NSMenu()
        let quitItem = NSMenuItem(
            title: "Quit Nameplate",
            action: #selector(quitNameplate),
            keyEquivalent: "q"
        )

        quitItem.target = self
        menu.addItem(quitItem)
        item.menu = menu
    }

    @objc func quitNameplate() {
        NSApp.terminate(nil)
    }
}

@main
struct Nameplate {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
