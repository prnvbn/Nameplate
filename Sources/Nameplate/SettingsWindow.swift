import AppKit
import SwiftUI

private let selectedApplicationsDefaultsKey = "selectedApplicationBundleIdentifiers"
private let allApplicationsDefaultsKey = "enableForAllApplications"

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
    static var allApplicationsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: allApplicationsDefaultsKey) }
        set { UserDefaults.standard.set(newValue, forKey: allApplicationsDefaultsKey) }
    }

    static var activeBundleIdentifiers: [String] {
        guard allApplicationsEnabled else { return bundleIdentifiers }
        return Array(Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier)))
    }

    static var bundleIdentifiers: [String] {
        if let identifiers = UserDefaults.standard.stringArray(
            forKey: selectedApplicationsDefaultsKey)
        {
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
        case general = "General"
        case applications = "Applications"
        case appearance = "Nameplate Style"
        case about = "About"

        var symbol: String {
            switch self {
            case .general: "gearshape"
            case .applications: "square.stack.3d.up"
            case .appearance: "paintpalette"
            case .about: "info.circle"
            }
        }
    }

    let onChange: () -> Void
    @State private var installedApps = InstalledApplications.scan()
    @State private var selectedIdentifiers = SelectedApplications.bundleIdentifiers
    @State private var allApplicationsEnabled = SelectedApplications.allApplicationsEnabled
    @State private var titleRulesByApp = WindowTitleProcessing.rulesByApp
    @State private var sampleTitles: [String: String] = [:]
    @State private var openWindowSamples: [String: String] = [:]
    @State private var expandedTitleProcessing: Set<String> = []
    @State private var search = ""
    @State private var manualIdentifier = ""
    @State private var selectedPreset = NameplatePreset.selected
    @State private var plateScale = NameplatePreset.plateScale
    @State private var basicOpacity = NameplatePreset.basicOpacity
    @State private var basicTextColor = Color(nsColor: NameplatePreset.basicTextColor)
    @State private var accentRailColor = Color(nsColor: NameplatePreset.accentRailColor)
    @State private var stickyNoteColor = Color(nsColor: NameplatePreset.stickyNoteColor)
    @State private var page: Page? = .general
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var accessibilityGranted = AccessibilityAccess.isGranted
    @State private var launchAtLoginError: String?

    private var filteredIdentifiers: [String] {
        let identifiers = Set(installedApps.map(\.bundleIdentifier))
            .union(selectedIdentifiers)
            .union(titleRulesByApp.keys)
        return identifiers.filter { identifier in
            guard !search.isEmpty else { return true }
            let name = installedApps.first { $0.bundleIdentifier == identifier }?.name ?? ""
            return name.localizedCaseInsensitiveContains(search)
                || identifier.localizedCaseInsensitiveContains(search)
        }.sorted { first, second in
            let firstName = installedApps.first { $0.bundleIdentifier == first }?.name ?? first
            let secondName = installedApps.first { $0.bundleIdentifier == second }?.name ?? second
            return firstName.localizedStandardCompare(secondName) == .orderedAscending
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
                    Text((page ?? .general).rawValue)
                        .font(.system(size: 24, weight: .semibold))
                    if page == .general {
                        generalPage
                    } else if page == .applications {
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
        .alert(
            "Could not change Launch at Login",
            isPresented: Binding(
                get: { launchAtLoginError != nil },
                set: { if !$0 { launchAtLoginError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { launchAtLoginError = nil }
        } message: {
            Text(launchAtLoginError ?? "")
        }
    }

    private var generalPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            settingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Accessibility Access").fontWeight(.medium)
                        Spacer()
                        Label(accessibilityGranted ? "Granted" : "Required",
                              systemImage: accessibilityGranted ? "checkmark.circle.fill" : "exclamationmark.circle")
                            .foregroundStyle(accessibilityGranted ? Color.green : Color.orange)
                            .font(.caption)
                    }
                    Text(accessibilityGranted
                         ? "Nameplate can read window titles in Mission Control."
                         : "Allow Nameplate in Privacy & Security → Accessibility to show window titles.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !accessibilityGranted {
                        Button("Open Accessibility Settings") { AccessibilityAccess.request() }
                    }
                }
            }
            settingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(
                        isOn: Binding(
                            get: { launchAtLogin },
                            set: { updateLaunchAtLogin($0) }
                        )
                    ) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Launch at Login")
                                .fontWeight(.medium)
                            Text("Start Nameplate when you sign in to your Mac.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .disabled(!LaunchAtLogin.isPackagedApp)
                    if !LaunchAtLogin.isPackagedApp {
                        Text("Available when Nameplate is opened from the built app bundle.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if LaunchAtLogin.requiresApproval {
                        HStack {
                            Text("Allow Nameplate in macOS Login Items to finish setup.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Open Login Items") { LaunchAtLogin.openSystemSettings() }
                        }
                    }
                }
            }
        }
        .onAppear {
            launchAtLogin = LaunchAtLogin.isEnabled
            accessibilityGranted = AccessibilityAccess.isGranted
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            accessibilityGranted = AccessibilityAccess.isGranted
        }
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLogin.setEnabled(enabled)
            launchAtLogin = LaunchAtLogin.isEnabled
        } catch {
            launchAtLogin = LaunchAtLogin.isEnabled
            launchAtLoginError = error.localizedDescription
        }
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
            Text("Choose which apps show window titles in Mission Control.")
                .foregroundStyle(.secondary)
            settingsCard {
                Toggle(
                    isOn: Binding(
                        get: { allApplicationsEnabled },
                        set: {
                            allApplicationsEnabled = $0
                            SelectedApplications.allApplicationsEnabled = $0
                            onChange()
                        }
                    )
                ) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Enable for all applications")
                            .fontWeight(.medium)
                        Text("Show nameplates for windows from every running application.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            settingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Applications").font(.headline)
                    Text(
                        allApplicationsEnabled
                            ? "All running apps show nameplates. Keep selections and title rules here for individual apps."
                            : "Select apps for nameplates and edit their title rules below."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    TextField("Search installed apps", text: $search)
                        .textFieldStyle(.roundedBorder)
                    List(filteredIdentifiers, id: \.self) { identifier in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Button {
                                    toggle(identifier)
                                } label: {
                                    HStack(spacing: 10) {
                                        if let app = installedApps.first(where: {
                                            $0.bundleIdentifier == identifier
                                        }) {
                                            applicationRow(app)
                                        } else {
                                            Label(identifier, systemImage: "app")
                                        }
                                        Spacer()
                                        if selectedIdentifiers.contains(identifier) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(Color.accentColor)
                                                .accessibilityHidden(true)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(identifier), \(selectedIdentifiers.contains(identifier) ? "Selected" : "Not selected")")
                                Button {
                                    if expandedTitleProcessing.contains(identifier) {
                                        expandedTitleProcessing.remove(identifier)
                                    } else {
                                        expandedTitleProcessing.insert(identifier)
                                        refreshOpenWindowSample(for: identifier)
                                    }
                                } label: {
                                    Text(
                                        expandedTitleProcessing.contains(identifier)
                                            ? "Hide rules" : "Edit rules"
                                    )
                                    .font(.caption)
                                }
                                .buttonStyle(.borderless)
                                .help("Title processing for \(identifier)")
                                .accessibilityLabel("Title processing for \(identifier)")
                            }
                            if expandedTitleProcessing.contains(identifier) {
                                titleRuleEditor(for: identifier)
                                    .padding(.vertical, 8)
                            }
                        }
                        .listRowBackground(
                            selectedIdentifiers.contains(identifier)
                                ? Color.accentColor.opacity(0.14) : Color.clear)
                    }
                    .frame(height: 300)
                    .overlay {
                        if filteredIdentifiers.isEmpty {
                            Text("No matching applications").foregroundStyle(.secondary)
                        }
                    }
                    HStack {
                        TextField("Or enter a bundle identifier", text: $manualIdentifier)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { addManualIdentifier() }
                        Button("Add App") { addManualIdentifier() }
                            .disabled(
                                manualIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
                                    .isEmpty)
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
                        Button {
                            moveRule(identifier, from: index, by: -1)
                        } label: {
                            Image(systemName: "arrow.up")
                        }.disabled(index == 0)
                        Button {
                            moveRule(identifier, from: index, by: 1)
                        } label: {
                            Image(systemName: "arrow.down")
                        }.disabled(index == rules.count - 1)
                        Button(role: .destructive) {
                            removeRule(identifier, id: rule.id)
                        } label: {
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
                        .background(
                            Color(nsColor: .controlBackgroundColor),
                            in: RoundedRectangle(cornerRadius: 6)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                        )
                        .accessibilityLabel("Action: \(rule.kind.rawValue)")
                    }
                    TextField(
                        rule.kind == .removeAfter ? "Separator, e.g.  — " : "Find",
                        text: ruleBinding(identifier, rule.id, \.pattern)
                    )
                    .textFieldStyle(.roundedBorder)
                    if rule.kind == .removeAfter,
                        let sample = sampleTitles[identifier],
                        !sample.isEmpty,
                        !sample.contains(rule.pattern),
                        let separator = WindowTitleProcessing.separator(in: sample)
                    {
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
                        TextField(
                            "Replace with (empty removes it)",
                            text: ruleBinding(identifier, rule.id, \.replacement)
                        )
                        .textFieldStyle(.roundedBorder)
                    }
                    if let error = rule.validationError {
                        Text(error).font(.caption).foregroundStyle(.red)
                    }
                }
                .padding(12)
                .background(
                    Color(nsColor: .underPageBackgroundColor), in: RoundedRectangle(cornerRadius: 8)
                )
            }
            Button {
                addRule(identifier)
            } label: {
                Label("Add rule", systemImage: "plus")
            }
            HStack {
                Text("Sample window title").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Refresh") { refreshOpenWindowSample(for: identifier) }
                    .buttonStyle(.link)
                    .font(.caption)
            }
            TextField(
                "Try a window title",
                text: Binding(
                    get: { sampleTitles[identifier] ?? "" },
                    set: { sampleTitles[identifier] = $0 }
                )
            )
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

    private func ruleBinding<Value>(
        _ identifier: String, _ id: UUID, _ keyPath: WritableKeyPath<WindowTitleRule, Value>
    ) -> Binding<Value> {
        Binding(
            get: { titleRulesByApp[identifier]!.first(where: { $0.id == id })![keyPath: keyPath] },
            set: { updateRule(identifier, id: id, keyPath, to: $0) }
        )
    }

    private func addRule(_ identifier: String) {
        titleRulesByApp[identifier, default: []].append(WindowTitleRule())
        persistTitleRules()
    }

    private func updateRule<Value>(
        _ identifier: String, id: UUID, _ keyPath: WritableKeyPath<WindowTitleRule, Value>,
        to value: Value
    ) {
        guard let index = titleRulesByApp[identifier]?.firstIndex(where: { $0.id == id }) else {
            return
        }
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
            Text("Choose a nameplate preset.")
                .foregroundStyle(.secondary)
            settingsCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Preview").font(.headline)
                    nameplatePreview
                    HStack {
                        Text("Plate size")
                        Slider(value: $plateScale, in: 0.5...2, step: 0.05)
                            .onChange(of: plateScale) { _, value in
                                NameplatePreset.plateScale = value
                                onChange()
                            }
                        Text("\(Int((plateScale * 100).rounded()))%")
                            .monospacedDigit()
                            .frame(width: 48, alignment: .trailing)
                        Button("Reset") { plateScale = 1 }
                            .disabled(plateScale == 1)
                    }
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
                                preset.previewPlate("Window title", compact: true)
                                    .frame(width: 150, alignment: .leading)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(preset.name).fontWeight(.medium)
                                    Text(preset.description).font(.caption).foregroundStyle(
                                        .secondary)
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
                        if selectedPreset == preset && preset != .licensePlate {
                            VStack(alignment: .leading, spacing: 12) {
                                styleControls(for: preset)
                            }
                            .padding(.horizontal, 12)
                            .padding(.bottom, 16)
                        }
                        if preset != NameplatePreset.allCases.last { Divider() }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func styleControls(for preset: NameplatePreset) -> some View {
        switch preset {
        case .basic:
            HStack {
                Text("Opacity")
                Slider(value: $basicOpacity, in: 0.2...1)
                    .onChange(of: basicOpacity) { _, value in
                        NameplatePreset.basicOpacity = value
                        onChange()
                    }
                Text("\(Int(basicOpacity * 100))%")
                    .monospacedDigit()
                    .frame(width: 42, alignment: .trailing)
            }
            ColorPicker("Text color", selection: $basicTextColor, supportsOpacity: false)
                .onChange(of: basicTextColor) { _, value in
                    NameplatePreset.basicTextColor = NSColor(value)
                    onChange()
                }
        case .accentRail:
            ColorPicker("Accent color", selection: $accentRailColor, supportsOpacity: false)
                .onChange(of: accentRailColor) { _, value in
                    NameplatePreset.accentRailColor = NSColor(value)
                    onChange()
                }
        case .stickyNote:
            Text("Paper colors")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                ForEach(NameplatePreset.stickyNotePaperColors) { paper in
                    let isSelected = paper.matches(NSColor(stickyNoteColor))
                    Button {
                        stickyNoteColor = Color(nsColor: paper.color)
                    } label: {
                        Circle()
                            .fill(Color(nsColor: paper.color))
                            .frame(width: 28, height: 28)
                            .overlay(Circle().strokeBorder(Color.black.opacity(0.12), lineWidth: 1))
                            .padding(3)
                            .overlay(Circle().strokeBorder(isSelected ? Color.accentColor : .clear,
                                                           lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    .help(paper.id)
                    .accessibilityLabel("\(paper.id) sticky note")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            ColorPicker("Paper color", selection: $stickyNoteColor, supportsOpacity: false)
                .onChange(of: stickyNoteColor) { _, value in
                    NameplatePreset.stickyNoteColor = NSColor(value)
                    onChange()
                }
        case .licensePlate:
            EmptyView()
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
            selectedPreset.previewPlate("Example window")
                .scaleEffect(plateScale)
        }
        .frame(height: 190)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1))
    }

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(nsColor: .controlBackgroundColor),
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
        let identifier = manualIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !identifier.isEmpty else { return }
        if titleRulesByApp[identifier] == nil {
            titleRulesByApp[identifier] = []
            persistTitleRules()
        }
        add(identifier)
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
