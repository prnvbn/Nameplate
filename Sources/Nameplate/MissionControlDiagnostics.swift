import AppKit
import SwiftUI

@MainActor
struct MissionControlDiagnosticsRow: View {
    @State private var capturing = false
    @State private var status = ""

    var body: some View {
        LabeledContent {
            VStack(alignment: .trailing, spacing: 6) {
                gatherButton
                if !status.isEmpty {
                    HStack(spacing: 6) {
                        if capturing { ProgressView().controlSize(.mini) }
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } label: {
            Text("Diagnostics")
        }
    }

    private var gatherButton: some View {
        Button("Gather Diagnostics", action: gather)
            .buttonStyle(.link)
            .disabled(capturing)
            .help(
                "Briefly opens Mission Control and saves a diagnostic ZIP in Downloads. Accessibility access is needed to inspect thumbnails. No window titles or screenshots are included, and nothing is uploaded."
            )
    }

    private func gather() {
        capturing = true
        status = "Gathering diagnostics…"
        Task { @MainActor in
            defer { capturing = false }
            let identifiers = SelectedApplications.bundleIdentifiers
            var sections = [
                "Nameplate Mission Control diagnostics",
                "Captured: \(Date().ISO8601Format())",
                "OS: \(ProcessInfo.processInfo.operatingSystemVersionString)",
                "Version: \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development")",
                "Selected apps: \(identifiers)",
                "Before capture:\n\(missionControlDiagnosticReport(for: identifiers))",
            ]
            let monitor = MissionControlMonitor()
            let wasVisible = monitor.missionControlSurfacePresent() == true
            var opened = false
            do {
                if !wasVisible {
                    let configuration = NSWorkspace.OpenConfiguration()
                    _ = try await NSWorkspace.shared.openApplication(
                        at: URL(fileURLWithPath: "/System/Applications/Mission Control.app"),
                        configuration: configuration)
                    opened = true
                }
                for sample in 1...2 {
                    try await Task.sleep(for: .seconds(2))
                    sections.append(
                        "Sample \(sample): surfacePresent=\(String(describing: monitor.missionControlSurfacePresent()))\n\(missionControlDiagnosticReport(for: identifiers))"
                    )
                    sections.append(
                        "Matched thumbnails: \(missionControlThumbnails(for: identifiers).count)")
                }
            } catch {
                sections.append("Capture error: \(error.localizedDescription)")
            }
            if opened && monitor.missionControlSurfacePresent() == true {
                CGEvent(keyboardEventSource: nil, virtualKey: 53, keyDown: true)?.post(
                    tap: .cghidEventTap)
                CGEvent(keyboardEventSource: nil, virtualKey: 53, keyDown: false)?.post(
                    tap: .cghidEventTap)
                try? await Task.sleep(for: .milliseconds(500))
            }
            do {
                let bundle = try save(sections.joined(separator: "\n\n"))
                status = "Diagnostic bundle saved in Downloads."
                NSWorkspace.shared.activateFileViewerSelecting([bundle])
            } catch {
                status = "Could not save diagnostics: \(error.localizedDescription)"
            }
        }
    }

    private func save(_ report: String) throws -> URL {
        let files = FileManager.default
        let name = "Nameplate-Diagnostics-\(UUID().uuidString)"
        let temporary = files.temporaryDirectory.appendingPathComponent(name, isDirectory: true)
        try files.createDirectory(at: temporary, withIntermediateDirectories: false)
        defer { try? files.removeItem(at: temporary) }
        try report.write(
            to: temporary.appendingPathComponent("diagnostics.txt"), atomically: true,
            encoding: .utf8)
        let downloads = try files.url(
            for: .downloadsDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let destination = downloads.appendingPathComponent(name + ".zip")
        let archive = Process()
        archive.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        archive.arguments = ["-c", "-k", "--keepParent", temporary.path, destination.path]
        try archive.run()
        archive.waitUntilExit()
        guard archive.terminationStatus == 0 else {
            try? files.removeItem(at: destination)
            throw CocoaError(.fileWriteUnknown)
        }
        return destination
    }
}
