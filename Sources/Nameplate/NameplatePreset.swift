import AppKit

private let nameplatePresetDefaultsKey = "nameplatePreset"

enum NameplatePreset: String, CaseIterable, Identifiable {
    case classic
    case subtle
    case accent
    case licensePlate

    var id: String { rawValue }

    var name: String {
        switch self {
        case .classic: "Graphite"
        case .subtle: "Porcelain"
        case .accent: "Slate"
        case .licensePlate: "Number Plate"
        }
    }

    var description: String {
        switch self {
        case .classic: "Soft charcoal with warm white text"
        case .subtle: "Warm light surface with dark text"
        case .accent: "Muted blue-gray with white text"
        case .licensePlate: "Ivory face, bold lettering, and a dark border"
        }
    }

    var backgroundColor: NSColor {
        switch self {
        case .classic: NSColor(calibratedRed: 0.12, green: 0.14, blue: 0.17, alpha: 1)
        case .subtle: NSColor(calibratedRed: 0.94, green: 0.93, blue: 0.90, alpha: 1)
        case .accent: NSColor(calibratedRed: 0.16, green: 0.24, blue: 0.31, alpha: 1)
        case .licensePlate: NSColor(calibratedWhite: 0.08, alpha: 1)
        }
    }

    var textColor: NSColor {
        switch self {
        case .classic, .accent: NSColor(calibratedWhite: 0.97, alpha: 1)
        case .subtle: NSColor(calibratedWhite: 0.12, alpha: 1)
        case .licensePlate: NSColor(calibratedWhite: 0.08, alpha: 1)
        }
    }

    var font: NSFont {
        switch self {
        case .classic: .systemFont(ofSize: 13, weight: .medium)
        case .subtle: .systemFont(ofSize: 12, weight: .medium)
        case .accent: .systemFont(ofSize: 13, weight: .semibold)
        case .licensePlate: .monospacedSystemFont(ofSize: 18, weight: .bold)
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .classic: 7
        case .subtle: 7
        case .accent: 7
        case .licensePlate: 7
        }
    }

    func displayText(_ title: String) -> String {
        self == .licensePlate ? title.uppercased() : title
    }

    static var selected: NameplatePreset {
        get { NameplatePreset(rawValue: UserDefaults.standard.string(forKey: nameplatePresetDefaultsKey) ?? "") ?? .classic }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: nameplatePresetDefaultsKey) }
    }
}
