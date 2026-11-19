import SwiftUI

@MainActor
struct AccessibilitySettingsCard: View {
    @ObservedObject private var accessibility = AccessibilityAccess.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Accessibility Access").fontWeight(.medium)
                Spacer()
                Label(
                    accessibility.isGranted ? "Granted" : "Action required",
                    systemImage: accessibility.isGranted
                        ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
                )
                .foregroundStyle(accessibility.isGranted ? Color.green : Color.orange)
                .font(.caption)
            }

            Text(
                accessibility.isGranted
                    ? "Nameplate can read window titles in Mission Control"
                    : "Nameplate needs Accessibility access to read window titles and place nameplates in Mission Control. Nameplates cannot appear until you allow access."
            )
            .font(.callout)
            .foregroundStyle(.secondary)

            if !accessibility.isGranted {
                VStack(alignment: .leading, spacing: 8) {
                    Text("1. Open System Settings using the button below.")
                    Text(
                        "2. Turn on Nameplate in Privacy & Security → \(AccessibilityAccess.settingsPaneName)."
                    )
                    Text("3. Return here. Nameplate checks access automatically.")
                }
                .font(.callout)

                Button("Open \(AccessibilityAccess.settingsPaneName) Settings") {
                    accessibility.request()
                }
                .buttonStyle(.borderedProminent)

            }
        }
        .onAppear { accessibility.refresh() }
    }
}
