import SwiftUI

#if os(iOS)
/// Internal consent sheet for anonymous activity tracking.
/// Presented via ``CutiE/requestAnalyticsConsent(from:completion:)``.
@available(iOS 15.0, *)
internal struct CutiEAnalyticsConsentView: View {

    let appName: String
    let onDecision: (Bool) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "chart.bar.xaxis.ascending")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("Help Improve \(appName)")
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)

            Text("Allow anonymous usage data to help us understand how the app is used. No personal information is collected — only a one-time daily activity signal.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    onDecision(true)
                    dismiss()
                } label: {
                    Text("Allow")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    onDecision(false)
                    dismiss()
                } label: {
                    Text("Not Now")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .padding()
    }
}
#endif
