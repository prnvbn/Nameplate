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
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 650),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Nameplate Settings"
        window.minSize = NSSize(width: 500, height: 500)
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
    let onChange: () -> Void
    @State private var installedApps = InstalledApplications.scan()
    @State private var selectedIdentifiers = SelectedApplications.bundleIdentifiers
    @State private var search = ""
    @State private var manualIdentifier = ""
    @State private var selectedPreset = NameplatePreset.selected

    private var filteredApps: [InstalledApplication] {
        guard !search.isEmpty else { return installedApps }
        return installedApps.filter {
            $0.name.localizedCaseInsensitiveContains(search)
                || $0.bundleIdentifier.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Applications").font(.title2.bold())
                Text("Show window titles for these apps in Mission Control.")
                    .foregroundStyle(.secondary)
            }

            TextField("Search installed apps", text: $search)
                .textFieldStyle(.roundedBorder)

            List(filteredApps, id: \.bundleIdentifier) { app in
                Button {
                    add(app.bundleIdentifier)
                } label: {
                    applicationRow(app)
                }
                .buttonStyle(.plain)
            }
            .frame(height: 160)
            .overlay {
                if filteredApps.isEmpty {
                    Text("No matching applications")
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                TextField("Or enter a bundle identifier", text: $manualIdentifier)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addManualIdentifier() }
                Button("Add App") { addManualIdentifier() }
                    .disabled(manualIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Text("Selected applications").font(.headline)
            List {
                ForEach(selectedIdentifiers, id: \.self) { identifier in
                    HStack {
                        if let app = installedApps.first(where: { $0.bundleIdentifier == identifier }) {
                            applicationRow(app)
                        } else {
                            Label(identifier, systemImage: "app")
                        }
                        Spacer()
                        Button {
                            remove(identifier)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.borderless)
                        .help("Remove \(identifier)")
                    }
                }
            }
            .frame(height: 110)

            Divider()
            Text("Nameplate style").font(.title2.bold())
            Text("Choose a preset. More styling controls can be added here later.")
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                ForEach(NameplatePreset.allCases) { preset in
                    Button {
                        selectedPreset = preset
                        NameplatePreset.selected = preset
                        onChange()
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Window title")
                                .font(Font(preset.font))
                                .foregroundStyle(Color(nsColor: preset.textColor))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color(nsColor: preset.backgroundColor),
                                            in: RoundedRectangle(cornerRadius: preset.cornerRadius))
                            Text(preset.name).fontWeight(.semibold)
                            Text(preset.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, minHeight: 105, alignment: .leading)
                        .padding(12)
                        .background(selectedPreset == preset ? Color.accentColor.opacity(0.12) : Color(nsColor: .controlBackgroundColor),
                                    in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(selectedPreset == preset ? Color.accentColor : .clear, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(24)
        .frame(minWidth: 500)
        }
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

    private func persist() {
        SelectedApplications.save(selectedIdentifiers)
        onChange()
    }
}
