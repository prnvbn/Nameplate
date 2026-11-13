import AppKit

private let nameplatePresetDefaultsKey = "nameplatePreset"

enum NameplatePreset: String, CaseIterable, Identifiable {
    case native
    case licensePlate

    var id: String { rawValue }

    var name: String {
        switch self {
        case .native: "Native"
        case .licensePlate: "Number Plate"
        }
    }

    var description: String {
        switch self {
        case .native: "Compact dark label with macOS system type"
        case .licensePlate: "Ivory face, bold lettering, and a dark border"
        }
    }

    var backgroundColor: NSColor {
        switch self {
        case .native: NSColor(calibratedWhite: 0.12, alpha: 0.82)
        case .licensePlate: NSColor(calibratedWhite: 0.08, alpha: 1)
        }
    }

    var textColor: NSColor {
        switch self {
        case .native: NSColor(calibratedWhite: 1, alpha: 0.96)
        case .licensePlate: NSColor(calibratedWhite: 0.08, alpha: 1)
        }
    }

    var font: NSFont {
        switch self {
        case .native: .systemFont(ofSize: 15, weight: .semibold)
        case .licensePlate: .monospacedSystemFont(ofSize: 18, weight: .bold)
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .native: 18
        case .licensePlate: 7
        }
    }

    func displayText(_ title: String) -> String {
        self == .licensePlate ? title.uppercased() : title
    }

    static var selected: NameplatePreset {
        get { NameplatePreset(rawValue: UserDefaults.standard.string(forKey: nameplatePresetDefaultsKey) ?? "") ?? .native }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: nameplatePresetDefaultsKey) }
    }
}
