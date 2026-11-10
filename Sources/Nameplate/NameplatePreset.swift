import AppKit

private let nameplatePresetDefaultsKey = "nameplatePreset"

enum NameplatePreset: String, CaseIterable, Identifiable {
    case classic
    case subtle
    case accent

    var id: String { rawValue }

    var name: String {
        switch self {
        case .classic: "Graphite"
        case .subtle: "Porcelain"
        case .accent: "Slate"
        }
    }

    var description: String {
        switch self {
        case .classic: "Soft charcoal with warm white text"
        case .subtle: "Warm light surface with dark text"
        case .accent: "Muted blue-gray with white text"
        }
    }

    var backgroundColor: NSColor {
        switch self {
        case .classic: NSColor(calibratedRed: 0.12, green: 0.14, blue: 0.17, alpha: 0.94)
        case .subtle: NSColor(calibratedRed: 0.94, green: 0.93, blue: 0.90, alpha: 0.96)
        case .accent: NSColor(calibratedRed: 0.16, green: 0.24, blue: 0.31, alpha: 0.95)
        }
    }

    var textColor: NSColor {
        switch self {
        case .classic, .accent: NSColor(calibratedWhite: 0.97, alpha: 1)
        case .subtle: NSColor(calibratedWhite: 0.12, alpha: 1)
        }
    }

    var font: NSFont {
        switch self {
        case .classic: .systemFont(ofSize: 13, weight: .medium)
        case .subtle: .systemFont(ofSize: 12, weight: .medium)
        case .accent: .systemFont(ofSize: 13, weight: .semibold)
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .classic: 7
        case .subtle: 7
        case .accent: 7
        }
    }

    static var selected: NameplatePreset {
        get { NameplatePreset(rawValue: UserDefaults.standard.string(forKey: nameplatePresetDefaultsKey) ?? "") ?? .classic }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: nameplatePresetDefaultsKey) }
    }
}
