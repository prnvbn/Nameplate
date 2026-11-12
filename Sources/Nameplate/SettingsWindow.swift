import AppKit
import SwiftUI

private let selectedApplicationsDefaultsKey = "selectedApplicationBundleIdentifiers"

private let appVersion: String = {
    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
        return version
    }
    guard let url = Bundle.module.url(forResource: "version", withExtension: "txt"),
        let version = try? String(contentsOf: url, encoding: .utf8)
    else { return "Unknown" }
    return version.trimmingCharacters(in: .whitespacesAndNewlines)
}()

@MainActor
enum SelectedApplications {
    static var bundleIdentifiers: [String] {
        if let identifiers = UserDefaults.standard.stringArray(forKey: selectedApplicationsDefaultsKey) {
            return identifiers
        }
        if let previousIdentifier = UserDefaults.standard.string(forKey: "targetBundleIdentifier") {
            return [previousIdentifier]
        }
        return []
    }

    static func save(_ identifiers: [String]) {
        UserDefaults.standard.set(identifiers, forKey: selectedApplicationsDefaultsKey)
    }
}

@MainActor
final class SettingsWindow: NSWindowController {
    init(onChange: @escaping () -> Void) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 850, height: 610),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Nameplate Settings"
        window.minSize = NSSize(width: 720, height: 520)
        window.center()
        window.contentView = NSHostingView(rootView: ApplicationSettingsView(onChange: onChange))
        super.init(window: window)
    }

    required init?(coder: NSCoder) { nil }

    func present() {
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

@MainActor
struct ApplicationSettingsView: View {
    private enum Page: String, CaseIterable {
        case applications = "Applications"
        case appearance = "Nameplate Style"
        case about = "About"

        var symbol: String {
            switch self {
            case .applications: "square.stack.3d.up"
            case .appearance: "paintpalette"
            case .about: "info.circle"
            }
        }
    }

    let onChange: () -> Void
    @State private var installedApps = InstalledApplications.scan()
    @State private var selectedIdentifiers = SelectedApplications.bundleIdentifiers
    @State private var titleRulesByApp = WindowTitleProcessing.rulesByApp
    @State private var sampleTitles: [String: String] = [:]
    @State private var openWindowSamples: [String: String] = [:]
    @State private var expandedTitleProcessing: Set<String> = []
    @State private var search = ""
    @State private var manualIdentifier = ""
    @State private var selectedPreset = NameplatePreset.selected
    @State private var page: Page? = .applications

    private var filteredApps: [InstalledApplication] {
        guard !search.isEmpty else { return installedApps }
        return installedApps.filter {
            $0.name.localizedCaseInsensitiveContains(search)
                || $0.bundleIdentifier.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 220)
                .frame(maxHeight: .infinity)
                .background(Color(nsColor: .underPageBackgroundColor))
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text((page ?? .applications).rawValue)
                        .font(.system(size: 24, weight: .semibold))
                    if page == .applications {
                        applicationsPage
                    } else if page == .appearance {
                        appearancePage
                    } else {
                        aboutPage
                    }
                }
                .frame(maxWidth: 680, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(28)
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 720, minHeight: 520)
    }

    private var sidebar: some View {
        List(selection: $page) {
            Section {
                ForEach(Page.allCases, id: \.self) { candidate in
                    Label(candidate.rawValue, systemImage: candidate.symbol)
                        .tag(candidate)
                }
            } header: {
                Text("Nameplate")
            }
        }
        .listStyle(.sidebar)
    }

    private var applicationsPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Choose the apps whose window titles appear in Mission Control.")
                .foregroundStyle(.secondary)
            settingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Add applications").font(.headline)
                    TextField("Search installed apps", text: $search)
                        .textFieldStyle(.roundedBorder)
                    List(filteredApps, id: \.bundleIdentifier) { app in
                        let isSelected = selectedIdentifiers.contains(app.bundleIdentifier)
                        Button { toggle(app.bundleIdentifier) } label: {
                            HStack {
                                applicationRow(app)
                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.accentColor)
                                        .accessibilityLabel("Selected")
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
                    }
                    .frame(height: 210)
                    .overlay {
                        if filteredApps.isEmpty {
                            Text("No matching applications").foregroundStyle(.secondary)
                        }
                    }
                    HStack {
                        TextField("Or enter a bundle identifier", text: $manualIdentifier)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { addManualIdentifier() }
                        Button("Add App") { addManualIdentifier() }
                            .disabled(manualIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            settingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Selected applications").font(.headline)
                    if selectedIdentifiers.isEmpty {
                        Text("No applications selected")
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 12)
                    } else {
                        ForEach(selectedIdentifiers, id: \.self) { identifier in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    if let app = installedApps.first(where: { $0.bundleIdentifier == identifier }) {
                                        applicationRow(app)
                                    } else {
                                        Label(identifier, systemImage: "app")
                                    }
                                    Button { remove(identifier) } label: {
                                        Image(systemName: "minus.circle.fill")
                                    }
                                    .buttonStyle(.borderless)
                                    .help("Remove \(identifier)")
                                }
                                Button {
                                    if expandedTitleProcessing.contains(identifier) {
                                        expandedTitleProcessing.remove(identifier)
                                    } else {
                                        expandedTitleProcessing.insert(identifier)
                                        refreshOpenWindowSample(for: identifier)
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: expandedTitleProcessing.contains(identifier) ? "chevron.down" : "chevron.right")
                                            .font(.caption.weight(.semibold))
                                            .frame(width: 14)
                                        Text("Title processing")
                                            .fontWeight(.medium)
                                        Spacer()
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 28)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityValue(expandedTitleProcessing.contains(identifier) ? "Expanded" : "Collapsed")
                                if expandedTitleProcessing.contains(identifier) {
                                    titleRuleEditor(for: identifier)
                                        .padding(.top, 8)
                                }
                            }
                            if identifier != selectedIdentifiers.last { Divider() }
                        }
                    }
                }
            }
        }
    }

    private func titleRuleEditor(for identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            let rules = titleRulesByApp[identifier] ?? []
            ForEach(Array(rules.enumerated()), id: \.element.id) { index, rule in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Toggle("", isOn: ruleBinding(identifier, rule.id, \.isEnabled))
                            .labelsHidden()
                        Text("Rule \(index + 1)").fontWeight(.medium)
                        Spacer()
                        Button { moveRule(identifier, from: index, by: -1) } label: {
                            Image(systemName: "arrow.up")
                        }.disabled(index == 0)
                        Button { moveRule(identifier, from: index, by: 1) } label: {
                            Image(systemName: "arrow.down")
                        }.disabled(index == rules.count - 1)
                        Button(role: .destructive) { removeRule(identifier, id: rule.id) } label: {
                            Image(systemName: "trash")
                        }
                    }
                    HStack(spacing: 12) {
                        Text("Action")
                        Menu {
                            ForEach(WindowTitleRule.Kind.allCases, id: \.self) { kind in
                                Button {
                                    updateRule(identifier, id: rule.id, \.kind, to: kind)
                                } label: {
                                    if rule.kind == kind {
                                        Label(kind.rawValue, systemImage: "checkmark")
                                    } else {
                                        Text(kind.rawValue)
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text(rule.kind.rawValue)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 10)
                            .frame(height: 28)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                        }
                        .menuStyle(.borderlessButton)
                        .background(Color(nsColor: .controlBackgroundColor),
                                    in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.25), lineWidth: 1))
                        .accessibilityLabel("Action: \(rule.kind.rawValue)")
                    }
                    TextField(rule.kind == .removeAfter ? "Separator, e.g.  — " : "Find", text: ruleBinding(identifier, rule.id, \.pattern))
                        .textFieldStyle(.roundedBorder)
                    if rule.kind == .removeAfter,
                       let sample = sampleTitles[identifier],
                       !sample.isEmpty,
                       !sample.contains(rule.pattern),
                       let separator = WindowTitleProcessing.separator(in: sample) {
                        HStack(spacing: 6) {
                            Text("This separator doesn’t match the sample title.")
                                .foregroundStyle(.secondary)
                            Button("Use “\(separator.trimmingCharacters(in: .whitespaces))”") {
                                updateRule(identifier, id: rule.id, \.pattern, to: separator)
                            }
                            .buttonStyle(.link)
                        }
                        .font(.caption)
                    }
                    if rule.kind != .removeAfter {
                        TextField("Replace with (empty removes it)", text: ruleBinding(identifier, rule.id, \.replacement))
                            .textFieldStyle(.roundedBorder)
                    }
                    if let error = rule.validationError {
                        Text(error).font(.caption).foregroundStyle(.red)
                    }
                }
                .padding(12)
                .background(Color(nsColor: .underPageBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            }
            Button { addRule(identifier) } label: { Label("Add rule", systemImage: "plus") }
            HStack {
                Text("Sample window title").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Refresh") { refreshOpenWindowSample(for: identifier) }
                    .buttonStyle(.link)
                    .font(.caption)
            }
            TextField("Try a window title", text: Binding(
                get: { sampleTitles[identifier] ?? "" },
                set: { sampleTitles[identifier] = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            if openWindowSamples[identifier] == nil {
                Text("Open a window in this app, then refresh to use its title here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let sample = sampleTitles[identifier], !sample.isEmpty {
                Text("Result: \(WindowTitleProcessing.process(sample, using: rules))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    private func refreshOpenWindowSample(for identifier: String) {
        if let title = OpenWindowTitleReader.sampleTitle(for: identifier) {
            openWindowSamples[identifier] = title
            sampleTitles[identifier] = title
        } else {
            openWindowSamples.removeValue(forKey: identifier)
        }
    }

    private func ruleBinding<Value>(_ identifier: String, _ id: UUID, _ keyPath: WritableKeyPath<WindowTitleRule, Value>) -> Binding<Value> {
        Binding(
            get: { titleRulesByApp[identifier]!.first(where: { $0.id == id })![keyPath: keyPath] },
            set: { updateRule(identifier, id: id, keyPath, to: $0) }
        )
    }

    private func addRule(_ identifier: String) {
        var rule = WindowTitleRule()
        if let sample = sampleTitles[identifier],
           let separator = WindowTitleProcessing.separator(in: sample) {
            rule.pattern = separator
        }
        titleRulesByApp[identifier, default: []].append(rule)
        persistTitleRules()
    }

    private func updateRule<Value>(_ identifier: String, id: UUID, _ keyPath: WritableKeyPath<WindowTitleRule, Value>, to value: Value) {
        guard let index = titleRulesByApp[identifier]?.firstIndex(where: { $0.id == id }) else { return }
        titleRulesByApp[identifier]![index][keyPath: keyPath] = value
        persistTitleRules()
    }

    private func removeRule(_ identifier: String, id: UUID) {
        titleRulesByApp[identifier]?.removeAll { $0.id == id }
        persistTitleRules()
    }

    private func moveRule(_ identifier: String, from index: Int, by offset: Int) {
        titleRulesByApp[identifier]?.swapAt(index, index + offset)
        persistTitleRules()
    }

    private func persistTitleRules() {
        WindowTitleProcessing.rulesByApp = titleRulesByApp
        onChange()
    }

    private var appearancePage: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Choose a nameplate preset. More styling controls can go here later.")
                .foregroundStyle(.secondary)
            settingsCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Preview").font(.headline)
                    nameplatePreview
                }
            }
            settingsCard {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Presets")
                        .font(.headline)
                        .padding(.bottom, 8)
                    ForEach(NameplatePreset.allCases) { preset in
                        Button {
                            selectedPreset = preset
                            NameplatePreset.selected = preset
                            onChange()
                        } label: {
                            HStack(spacing: 16) {
                                Text("Window title")
                                    .font(Font(preset.font))
                                    .foregroundStyle(Color(nsColor: preset.textColor))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color(nsColor: preset.backgroundColor),
                                                in: RoundedRectangle(cornerRadius: preset.cornerRadius))
                                    .frame(width: 150, alignment: .leading)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(preset.name).fontWeight(.medium)
                                    Text(preset.description).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if selectedPreset == preset {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                            .padding(.vertical, 14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if preset != NameplatePreset.allCases.last { Divider() }
                    }
                }
            }
        }
    }

    private var aboutPage: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Nameplate")
                    .font(.title2.bold())
                Text("See window titles at a glance in Mission Control.")
                    .foregroundStyle(.secondary)
                Divider()
                HStack {
                    Text("Version")
                    Spacer()
                    Text(appVersion)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private var nameplatePreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .underPageBackgroundColor))
            VStack(spacing: 0) {
                HStack(spacing: 5) {
                    ForEach(0..<3) { _ in
                        Circle().fill(Color.secondary.opacity(0.45))
                            .frame(width: 7, height: 7)
                    }
                    Spacer()
                    Text("Example window")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(10)
                Divider()
                VStack(alignment: .leading, spacing: 9) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.18))
                        .frame(width: 140, height: 8)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.12))
                        .frame(maxWidth: .infinity, minHeight: 8, maxHeight: 8)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.12))
                        .frame(width: 190, height: 8)
                    Spacer()
                }
                .padding(16)
            }
            Text("Example window")
                .font(Font(selectedPreset.font))
                .foregroundStyle(Color(nsColor: selectedPreset.textColor))
                .padding(.horizontal, 18)
                .frame(height: 42)
                .background(Color(nsColor: selectedPreset.backgroundColor),
                            in: RoundedRectangle(cornerRadius: selectedPreset.cornerRadius))
        }
        .frame(height: 190)
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(Color.secondary.opacity(0.2), lineWidth: 1))
    }

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor),
                        in: RoundedRectangle(cornerRadius: 14))
    }

    private func applicationRow(_ app: InstalledApplication) -> some View {
        HStack(spacing: 10) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.url.path))
                .resizable()
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name).fontWeight(.medium)
                Text(app.bundleIdentifier).font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func addManualIdentifier() {
        add(manualIdentifier.trimmingCharacters(in: .whitespacesAndNewlines))
        manualIdentifier = ""
    }

    private func add(_ identifier: String) {
        guard !identifier.isEmpty, !selectedIdentifiers.contains(identifier) else { return }
        selectedIdentifiers.append(identifier)
        persist()
    }

    private func remove(_ identifier: String) {
        selectedIdentifiers.removeAll { $0 == identifier }
        persist()
    }

    private func toggle(_ identifier: String) {
        if selectedIdentifiers.contains(identifier) {
            remove(identifier)
        } else {
            add(identifier)
        }
    }

    private func persist() {
        SelectedApplications.save(selectedIdentifiers)
        onChange()
    }
}
