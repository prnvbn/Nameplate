import SwiftUI

@MainActor
struct AccessibilitySettingsCard: View {
    @ObservedObject private var accessibility = AccessibilityAccess.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LabeledContent {
                Label(
                    accessibility.isGranted ? "Granted" : "Action required",
                    systemImage: accessibility.isGranted
                        ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
                )
                .foregroundStyle(accessibility.isGranted ? Color.green : Color.orange)
            } label: {
                Text("Accessibility Access")
                Text(
                    accessibility.isGranted
                        ? "Read window titles in Mission Control."
                        : "Allow access to read window titles and place nameplates in Mission Control."
                )
            }

            if !accessibility.isGranted {
                Button("Open \(AccessibilityAccess.settingsPaneName) Settings") {
                    accessibility.request()
                }
            }
        }
        .onAppear { accessibility.refresh() }
    }
}
