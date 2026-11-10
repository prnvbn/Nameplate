import AppKit

struct InstalledApplication {
    let name: String
    let bundleIdentifier: String
    let url: URL
}

enum InstalledApplications {
    static func scan() -> [InstalledApplication] {
        let fileManager = FileManager.default
        let folders = [URL(fileURLWithPath: "/Applications"),
                       URL(fileURLWithPath: "/System/Applications"),
                       fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications")]
        var appsByID: [String: InstalledApplication] = [:]

        for folder in folders {
            guard let enumerator = fileManager.enumerator(at: folder,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]) else { continue }
            for case let url as URL in enumerator {
                guard url.pathExtension == "app" else { continue }
                enumerator.skipDescendants()
                guard let bundle = Bundle(url: url), let identifier = bundle.bundleIdentifier else { continue }
                let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                    ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                    ?? url.deletingPathExtension().lastPathComponent
                appsByID[identifier] = InstalledApplication(name: name, bundleIdentifier: identifier, url: url)
            }
        }
        return appsByID.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
