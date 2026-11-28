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

    static let selectionDidChange = Notification.Name("NameplateApplicationSelectionDidChange")

    static func hasSavedSelection(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: selectedApplicationsDefaultsKey) != nil
            || defaults.object(forKey: "targetBundleIdentifier") != nil
    }

    static func save(_ identifiers: [String]) {
        UserDefaults.standard.set(identifiers, forKey: selectedApplicationsDefaultsKey)
        NotificationCenter.default.post(name: selectionDidChange, object: nil)
    }
}

@MainActor
final class SettingsWindow: NSWindowController {
    static let accessibilitySetupRequested = Notification.Name(
        "NameplateAccessibilitySetupRequested")

    static let applicationsSetupRequested = Notification.Name("NameplateApplicationsSetupRequested")

    init(showApplications: Bool = false, onChange: @escaping () -> Void) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1080, height: 740),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Nameplate Settings"
        window.minSize = NSSize(width: 720, height: 520)
        window.center()
        window.contentView = NSHostingView(
            rootView: ApplicationSettingsView(
                showApplications: showApplications, onChange: onChange))
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

        var symbol: String {
            switch self {
            case .general: "gearshape"
            case .applications: "square.stack.3d.up"
            case .appearance: "paintpalette"
            }
        }
    }

    let onChange: () -> Void
    @AppStorage(Nameplate.showMenuBarIconKey) private var showMenuBarIcon = true
    @ObservedObject private var accessibility = AccessibilityAccess.shared
    @State private var installedApps = InstalledApplications.scan()
    @State private var selectedIdentifiers = SelectedApplications.bundleIdentifiers
    @State private var titleRulesByApp = WindowTitleProcessing.rulesByApp
    @State private var sampleTitles: [String: String] = [:]
    @State private var openWindowSamples: [String: String] = [:]
    @State private var expandedTitleProcessing: Set<String> = []
    @State private var search = ""
    @State private var showingApplicationPicker = false
    @State private var manualIdentifier = ""
    @State private var selectedPreset = NameplatePreset.selected
    @State private var plateScale = NameplatePreset.plateScale
    @State private var basicTextColor = Color(nsColor: NameplatePreset.basicTextColor)
    @State private var accentRailColor = Color(nsColor: NameplatePreset.accentRailColor)
    @State private var stickyNoteColor = Color(nsColor: NameplatePreset.stickyNoteColor)
    @State private var page: Page? = .general
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var launchAtLoginError: String?

    init(showApplications: Bool = false, onChange: @escaping () -> Void) {
        self.onChange = onChange
        _page = State(initialValue: showApplications ? .applications : .general)
    }

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
            VStack(alignment: .leading, spacing: 0) {
                Text((page ?? .general).rawValue)
                    .font(.title.bold())
                    .padding(.horizontal, 28)
                    .padding(.top, 28)
                    .padding(.bottom, 8)

                switch page ?? .general {
                case .general:
                    generalPage
                case .applications, .appearance:
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            if page == .applications {
                                applicationsPage
                            } else {
                                appearancePage
                            }
                        }
                        .frame(maxWidth: page == .applications ? 1000 : 680, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(28)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 720, minHeight: 520)
        .onAppear {
            selectedIdentifiers = SelectedApplications.bundleIdentifiers
        }
        .onReceive(
            NotificationCenter.default.publisher(for: SelectedApplications.selectionDidChange)
        ) { _ in
            selectedIdentifiers = SelectedApplications.bundleIdentifiers
        }
        .onReceive(
            NotificationCenter.default.publisher(for: SettingsWindow.accessibilitySetupRequested)
        ) { _ in
            page = .general
        }
        .onReceive(
            NotificationCenter.default.publisher(for: SettingsWindow.applicationsSetupRequested)
        ) { _ in
            page = .applications
        }
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
        Form {
            Section {
                AccessibilitySettingsCard()

                LabeledContent {
                    VStack(alignment: .trailing, spacing: 8) {
                        Label(
                            selectedIdentifiers.isEmpty
                                ? "Action required" : "\(selectedIdentifiers.count) selected",
                            systemImage: selectedIdentifiers.isEmpty
                                ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
                        )
                        .foregroundStyle(selectedIdentifiers.isEmpty ? Color.orange : Color.green)
                        Button("Choose Applications…") { page = .applications }
                    }
                } label: {
                    Text("Applications")
                    Text(
                        selectedIdentifiers.isEmpty
                            ? "Select at least one application to show window titles in Mission Control."
                            : "Nameplates appear only for selected applications."
                    )
                }

                Toggle(
                    isOn: Binding(
                        get: { launchAtLogin },
                        set: { updateLaunchAtLogin($0) }
                    )
                ) {
                    Text("Launch at Login")
                    Text(
                        LaunchAtLogin.isPackagedApp
                            ? "Start Nameplate when you sign in to your Mac."
                            : "Available when you open the built Nameplate application."
                    )
                }
                .disabled(!LaunchAtLogin.isPackagedApp)

                Toggle(isOn: $showMenuBarIcon) {
                    Text("Show Menu Bar Icon")
                    Text("If hidden, open the Nameplate app again to return to Settings.")
                }

                if LaunchAtLogin.isPackagedApp && LaunchAtLogin.requiresApproval {
                    LabeledContent {
                        Button("Open Login Items") { LaunchAtLogin.openSystemSettings() }
                    } label: {
                        Text("Approval required")
                        Text("Allow Nameplate in macOS Login Items to finish setup.")
                    }
                }
            }

            Section {
                LabeledContent("Version") {
                    Text(appVersion)
                        .textSelection(.enabled)
                }
                LabeledContent("Updates") {
                    CheckForUpdatesButton()
                }
                LabeledContent("GitHub") {
                    Link(
                        "Nameplate on GitHub",
                        destination: URL(string: "https://github.com/prnvbn/Nameplate")!
                    )
                    .help("Enjoying Nameplate? Drop a star on GitHub.")
                }
                LabeledContent("Feedback") {
                    Link(
                        "Report an Issue",
                        destination: URL(string: "https://github.com/prnvbn/Nameplate/issues")!
                    )
                    .help("Report a bug or request a feature on GitHub.")
                }
                MissionControlDiagnosticsRow()
            } header: {
                Text("About Nameplate")
            } footer: {
                Text("See window titles at a glance in Mission Control.")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .frame(maxWidth: 736)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            launchAtLogin = LaunchAtLogin.isEnabled
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

    private var configuredIdentifiers: [String] {
        Set(selectedIdentifiers).union(titleRulesByApp.keys).sorted { first, second in
            let firstName = installedApps.first { $0.bundleIdentifier == first }?.name ?? first
            let secondName = installedApps.first { $0.bundleIdentifier == second }?.name ?? second
            return firstName.localizedStandardCompare(secondName) == .orderedAscending
        }
    }

    private var applicationsPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center) {
                Text("Choose where nameplates appear. Expand an app to edit its title.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    search = ""
                    installedApps = InstalledApplications.scan()
                    showingApplicationPicker = true
                } label: {
                    Label("Add application", systemImage: "plus")
                }
            }
            if configuredIdentifiers.isEmpty {
                ContentUnavailableView(
                    "No applications yet", systemImage: "app.badge",
                    description: Text(
                        "Add an application to show its window titles in Mission Control.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                VStack(spacing: 12) {
                    ForEach(configuredIdentifiers, id: \.self) { identifier in
                        applicationAccordionRow(for: identifier)
                    }
                }
            }
        }
        .sheet(isPresented: $showingApplicationPicker) {
            applicationPicker
        }
    }

    private var applicationPicker: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Add application").font(.title2.weight(.semibold))
                Spacer()
                Button("Done") { showingApplicationPicker = false }
                    .keyboardShortcut(.cancelAction)
            }
            ApplicationSearchField(text: $search)
            List(filteredIdentifiers, id: \.self) { identifier in
                HStack {
                    if let app = installedApps.first(where: { $0.bundleIdentifier == identifier }) {
                        applicationRow(app)
                    } else {
                        Label(identifier, systemImage: "app")
                    }
                    Spacer()
                    if configuredIdentifiers.contains(identifier) {
                        Text("Added").font(.caption).foregroundStyle(.secondary)
                    } else {
                        Button("Add") {
                            add(identifier)
                            expandedTitleProcessing = [identifier]
                            refreshOpenWindowSample(for: identifier)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .overlay {
                if filteredIdentifiers.isEmpty {
                    Text("No matching applications").foregroundStyle(.secondary)
                }
            }
            DisclosureGroup("Add by bundle identifier") {
                HStack {
                    TextField("com.example.app", text: $manualIdentifier)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { addManualIdentifier() }
                    Button("Add") { addManualIdentifier() }
                        .disabled(
                            manualIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        )
                }
                .padding(.top, 8)
            }
            .font(.callout)
        }
        .padding(24)
        .frame(width: 480, height: 480)
    }

    private func applicationAccordionRow(for identifier: String) -> some View {
        let app = installedApps.first { $0.bundleIdentifier == identifier }
        let name =
            app.flatMap {
                $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0.name
            } ?? identifier
        let isExpanded = expandedTitleProcessing.contains(identifier)
        let ruleCount = titleRulesByApp[identifier]?.count ?? 0
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                Button {
                    if isExpanded {
                        expandedTitleProcessing.remove(identifier)
                    } else {
                        expandedTitleProcessing = [identifier]
                        refreshOpenWindowSample(for: identifier)
                    }
                } label: {
                    HStack(spacing: 12) {
                        if let app {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: app.url.path))
                                .resizable()
                                .frame(width: 26, height: 26)
                        } else {
                            Image(systemName: "app")
                                .frame(width: 26, height: 26)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(name).fontWeight(.medium)
                            if ruleCount > 0 {
                                Text("\(ruleCount) \(ruleCount == 1 ? "rule" : "rules")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 0)
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(identifier)
                .accessibilityLabel("\(isExpanded ? "Hide" : "Edit") rules for \(name)")
                Toggle(
                    "Enabled",
                    isOn: Binding(
                        get: { selectedIdentifiers.contains(identifier) },
                        set: { enabled in
                            if enabled { add(identifier) } else { remove(identifier) }
                        }
                    )
                )
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.small)
                .fixedSize()
                .accessibilityLabel("Enable nameplates for \(name)")
                Button(role: .destructive) {
                    removeApplication(identifier)
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Remove \(name) and its title rules")
                .accessibilityLabel("Remove \(name)")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            if isExpanded {
                Divider().padding(.horizontal, 20)
                titleRuleEditor(for: identifier)
                    .padding(20)
            }
        }
        .background(
            Color.primary.opacity(0.055),
            in: RoundedRectangle(cornerRadius: 12))
    }

    private func titleRuleEditor(for identifier: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 28) {
                titleRuleControls(for: identifier)
                    .frame(minWidth: 300, maxWidth: .infinity)
                titleRulePreview(for: identifier)
                    .frame(minWidth: 240, maxWidth: .infinity)
            }
            VStack(alignment: .leading, spacing: 20) {
                titleRuleControls(for: identifier)
                titleRulePreview(for: identifier)
            }
        }
    }

    private func titleRuleControls(for identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Title rules").font(.headline)
            if (titleRulesByApp[identifier] ?? []).isEmpty {
                Text("Add a rule to simplify this application's window titles.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            titleRuleList(for: identifier)
            Button {
                addRule(identifier)
            } label: {
                Label("Add rule", systemImage: "plus")
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
        }
    }

    private func titleRuleList(for identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            let rules = titleRulesByApp[identifier] ?? []
            ForEach(Array(rules.enumerated()), id: \.element.id) { index, rule in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Toggle(
                            "Enable rule \(index + 1)",
                            isOn: ruleBinding(identifier, rule.id, \.isEnabled)
                        )
                        .labelsHidden()
                        Text("Rule \(index + 1)").fontWeight(.medium)
                        Spacer()
                        Button {
                            moveRule(identifier, from: index, by: -1)
                        } label: {
                            Image(systemName: "arrow.up")
                        }.disabled(index == 0)
                            .help("Move rule up")
                        Button {
                            moveRule(identifier, from: index, by: 1)
                        } label: {
                            Image(systemName: "arrow.down")
                        }.disabled(index == rules.count - 1)
                            .help("Move rule down")
                        Button(role: .destructive) {
                            removeRule(identifier, id: rule.id)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .help("Delete rule")
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    Divider().padding(.vertical, 2)
                    HStack {
                        Text("Action")
                        Spacer(minLength: 12)
                        Picker("Action", selection: ruleBinding(identifier, rule.id, \.kind)) {
                            ForEach(WindowTitleRule.Kind.allCases, id: \.self) { kind in
                                Text(kind.editorLabel)
                                    .tag(kind)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .fixedSize()
                    }
                    .padding(.vertical, 4)
                    Divider().padding(.vertical, 2)
                    HStack(spacing: 16) {
                        Text(rule.kind.patternLabel)
                        Spacer(minLength: 0)
                        TextField(
                            rule.kind.patternPlaceholder,
                            text: ruleBinding(identifier, rule.id, \.pattern)
                        )
                        .modifier(TitleEditorFieldStyle())
                        .frame(maxWidth: rule.kind.patternFieldWidth)
                    }
                    if let explanation = rule.kind.explanation {
                        Text(explanation)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 4)
                    }
                    if let sample = sampleTitles[identifier],
                        let separator = rule.suggestedSeparator(for: sample)
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
                    if rule.kind.usesReplacement {
                        TextField(
                            "Replace with (empty removes it)",
                            text: ruleBinding(identifier, rule.id, \.replacement)
                        )
                        .modifier(TitleEditorFieldStyle())
                    }
                    if let error = rule.validationError {
                        Text(error).font(.caption).foregroundStyle(.red)
                    }
                }
                if index < rules.count - 1 {
                    Divider().padding(.vertical, 8)
                }
            }
        }
    }

    private func titleRulePreview(for identifier: String) -> some View {
        let sample = sampleTitles[identifier] ?? ""
        let result = WindowTitleProcessing.process(sample, using: titleRulesByApp[identifier] ?? [])
        return VStack(alignment: .leading, spacing: 16) {
            Text("Preview").font(.headline)
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Original title")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Refresh") { refreshOpenWindowSample(for: identifier) }
                            .buttonStyle(.link)
                    }
                    .font(.caption)
                    TextField(
                        "Try a window title",
                        text: Binding(
                            get: { sampleTitles[identifier] ?? "" },
                            set: { sampleTitles[identifier] = $0 }
                        )
                    )
                    .modifier(TitleEditorFieldStyle())
                    .accessibilityLabel("Original title")
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Displayed title")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(
                        sample.isEmpty
                            ? "Enter a title to preview" : result.isEmpty ? "Empty title" : result
                    )
                    .font(.body)
                    .foregroundStyle(sample.isEmpty || result.isEmpty ? .secondary : .primary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        Color.primary.opacity(0.035),
                        in: RoundedRectangle(cornerRadius: 6)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                            .allowsHitTesting(false)
                    }
                }
            }

            if sample.isEmpty {
                Text(
                    accessibility.isGranted
                        ? "Enter a sample title, or open a window in this application and refresh."
                        : "Enter a sample title, or allow Accessibility access in General to read an open window."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
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
                        Text("Nameplate size")
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
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(preset.name).fontWeight(.medium)
                                    Text(preset.description).font(.caption).foregroundStyle(
                                        .secondary)
                                }
                                Spacer()
                                Circle()
                                    .strokeBorder(
                                        selectedPreset == preset
                                            ? Color.accentColor : Color.secondary,
                                        lineWidth: 1.5
                                    )
                                    .background {
                                        if selectedPreset == preset {
                                            Circle()
                                                .fill(Color.accentColor)
                                                .padding(3.5)
                                        }
                                    }
                                    .frame(width: 14, height: 14)
                                    .accessibilityHidden(true)
                            }
                            .padding(.vertical, 14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(preset.name)
                        .accessibilityHint(preset.description)
                        .accessibilityAddTraits(selectedPreset == preset ? .isSelected : [])
                        .accessibilityValue(selectedPreset == preset ? "Selected" : "Not selected")
                        .help("Use \(preset.name)")
                        if selectedPreset == preset && preset != .licensePlate {
                            VStack(alignment: .leading, spacing: 12) {
                                styleControls(for: preset)
                                HStack {
                                    Spacer()
                                    Button("Reset preset") {
                                        preset.resetAppearance()
                                        basicTextColor = Color(
                                            nsColor: NameplatePreset.basicTextColor)
                                        accentRailColor = Color(
                                            nsColor: NameplatePreset.accentRailColor)
                                        stickyNoteColor = Color(
                                            nsColor: NameplatePreset.stickyNoteColor)
                                        onChange()
                                    }
                                    .controlSize(.small)
                                    .help("Restore this preset's default colors")
                                }
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
            ColorPicker("Window title color", selection: $basicTextColor, supportsOpacity: false)
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
                            .overlay(
                                Circle().strokeBorder(
                                    isSelected ? Color.accentColor : .clear,
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
        if titleRulesByApp[identifier] == nil {
            titleRulesByApp[identifier] = []
            persistTitleRules()
        }
        persist()
    }

    private func removeApplication(_ identifier: String) {
        selectedIdentifiers.removeAll { $0 == identifier }
        titleRulesByApp.removeValue(forKey: identifier)
        expandedTitleProcessing.remove(identifier)
        sampleTitles.removeValue(forKey: identifier)
        openWindowSamples.removeValue(forKey: identifier)
        // Save both values before notifying observers so removed apps cannot reappear.
        WindowTitleProcessing.rulesByApp = titleRulesByApp
        SelectedApplications.save(selectedIdentifiers)
        onChange()
    }

    private func remove(_ identifier: String) {
        if titleRulesByApp[identifier] == nil {
            titleRulesByApp[identifier] = []
            persistTitleRules()
        }
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

private struct TitleEditorFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .font(.body)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color.primary.opacity(0.035),
                in: RoundedRectangle(cornerRadius: 6)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                    .allowsHitTesting(false)
            }
    }
}
