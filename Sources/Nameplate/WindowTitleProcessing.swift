import Foundation

private let titleRulesDefaultsKey = "windowTitleRulesByBundleIdentifier"

struct WindowTitleRule: Codable, Equatable, Identifiable {
    enum Kind: String, Codable, CaseIterable {
        case removeAfter = "Remove after"
        case replace = "Replace text"
        case regexReplace = "Replace regex"
        case addSuffix = "Add suffix"
        case removeSuffix = "Remove suffix"

        var editorLabel: String {
            self == .removeAfter ? "Remove ending" : displayName
        }

        var patternLabel: String {
            switch self {
            case .removeAfter: "Separator"
            case .replace, .regexReplace: "Find"
            case .addSuffix, .removeSuffix: "Suffix"
            }
        }

        var patternPlaceholder: String {
            switch self {
            case .removeAfter: "e.g. —"
            case .replace, .regexReplace: "Find text"
            case .addSuffix, .removeSuffix: "Suffix text"
            }
        }

        var patternFieldWidth: Double {
            self == .removeAfter ? 100 : 180
        }

        var explanation: String? {
            self == .removeAfter
                ? "Removes the last matching separator and everything after it."
                : nil
        }

        var usesReplacement: Bool {
            self == .replace || self == .regexReplace
        }

        var displayName: String {
            self == .removeAfter ? "Remove separator and following text" : rawValue
        }
    }

    var id = UUID()
    var kind: Kind = .removeAfter
    var pattern = ""
    var replacement = ""
    var isEnabled = true

    func apply(to title: String) -> String {
        guard isEnabled, !pattern.isEmpty else { return title }
        switch kind {
        case .removeAfter:
            guard let range = title.range(of: pattern, options: .backwards) else { return title }
            return String(title[..<range.lowerBound])
        case .addSuffix:
            return title + pattern
        case .removeSuffix:
            guard title.hasSuffix(pattern) else { return title }
            return String(title.dropLast(pattern.count))
        case .replace:
            return title.replacingOccurrences(of: pattern, with: replacement)
        case .regexReplace:
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return title }
            return regex.stringByReplacingMatches(
                in: title,
                range: NSRange(title.startIndex..., in: title),
                withTemplate: replacement
            )
        }
    }

    func suggestedSeparator(for sample: String) -> String? {
        guard kind == .removeAfter, !sample.isEmpty, !sample.contains(pattern) else {
            return nil
        }
        return WindowTitleProcessing.separator(in: sample)
    }

    var validationError: String? {
        guard kind == .regexReplace, !pattern.isEmpty else { return nil }
        do {
            _ = try NSRegularExpression(pattern: pattern)
            return nil
        } catch {
            return "Invalid regular expression"
        }
    }
}

enum WindowTitleProcessing {
    static func separator(in title: String) -> String? {
        [" — ", " - ", " – "]
            .compactMap { separator in
                title.range(of: separator, options: .backwards).map { (separator, $0) }
            }
            .max(by: { $0.1.lowerBound < $1.1.lowerBound })?
            .0
    }

    static var rulesByApp: [String: [WindowTitleRule]] {
        get {
            if let data = UserDefaults.standard.data(forKey: titleRulesDefaultsKey),
                let rules = try? JSONDecoder().decode([String: [WindowTitleRule]].self, from: data)
            {
                return rules
            }
            return [:]
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            UserDefaults.standard.set(data, forKey: titleRulesDefaultsKey)
        }
    }

    static func displayTitle(_ title: String, for bundleIdentifier: String) -> String {
        process(title, using: rulesByApp[bundleIdentifier] ?? [])
    }

    static func process(_ title: String, using rules: [WindowTitleRule]) -> String {
        rules.reduce(title) { result, rule in rule.apply(to: result) }
    }
}
