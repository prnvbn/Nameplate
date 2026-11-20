import Foundation

@MainActor
enum ApplicationSetup {
    private static let applicationsPresentedKey = "hasPresentedApplicationSetup"

    static func shouldOfferApplications(in defaults: UserDefaults = .standard) -> Bool {
        !defaults.bool(forKey: applicationsPresentedKey)
            && !SelectedApplications.hasSavedSelection(in: defaults)
    }

    static func markApplicationsPresented(in defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: applicationsPresentedKey)
    }
}
