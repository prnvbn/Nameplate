import AppKit
import SwiftUI

private let selectedApplicationsDefaultsKey = "selectedApplicationBundleIdentifiers"

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
private struct ApplicationSettingsView: View {
    private enum Page: String, CaseIterable {
        case applications = "Applications"
        case appearance = "Nameplate Style"

        var symbol: String {
            switch self {
            case .applications: "square.stack.3d.up"
            case .appearance: "paintpalette"
            }
        }
    }

    let onChange: () -> Void
    @State private var installedApps = InstalledApplications.scan()
    @State private var selectedIdentifiers = SelectedApplications.bundleIdentifiers
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
                    } else {
                        appearancePage
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
                            if identifier != selectedIdentifiers.last { Divider() }
                        }
                    }
                }
            }
        }
    }

    private var appearancePage: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Choose a nameplate preset. More styling controls can go here later.")
                .foregroundStyle(.secondary)
            settingsCard {
                VStack(alignment: .leading, spacing: 0) {
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
