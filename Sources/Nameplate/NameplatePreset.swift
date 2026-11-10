import AppKit

private let nameplatePresetDefaultsKey = "nameplatePreset"

enum NameplatePreset: String, CaseIterable, Identifiable {
    case classic
    case subtle
    case accent

    var id: String { rawValue }

    var name: String {
        switch self {
        case .classic: "Classic"
        case .subtle: "Subtle"
        case .accent: "Accent"
        }
    }

    var description: String {
        switch self {
        case .classic: "Dark label with strong contrast"
        case .subtle: "Quiet label with a lighter background"
        case .accent: "Blue label that stands out"
        }
    }

    var backgroundColor: NSColor {
        switch self {
        case .classic: .black.withAlphaComponent(0.78)
        case .subtle: .windowBackgroundColor.withAlphaComponent(0.82)
        case .accent: .systemBlue.withAlphaComponent(0.92)
        }
    }

    var textColor: NSColor {
        switch self {
        case .classic, .accent: .white
        case .subtle: .labelColor
        }
    }

    var font: NSFont {
        switch self {
        case .classic: .systemFont(ofSize: 13, weight: .semibold)
        case .subtle: .systemFont(ofSize: 12, weight: .medium)
        case .accent: .systemFont(ofSize: 13, weight: .bold)
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .classic: 5
        case .subtle: 8
        case .accent: 7
        }
    }

    static var selected: NameplatePreset {
        get { NameplatePreset(rawValue: UserDefaults.standard.string(forKey: nameplatePresetDefaultsKey) ?? "") ?? .classic }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: nameplatePresetDefaultsKey) }
    }
}
