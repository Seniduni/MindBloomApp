import SwiftUI

/// Plain-language explanation of what MIND BLOOM stores, what it does not do,
/// and where to find real support.
struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                BloomLogo(size: 56)
                block("What's stored", symbol: "internaldrive",
                      text: "Mood check-ins, journal entries, habits and session history are saved in a private database on this device using Apple's SwiftData. Small preferences (like your theme) are saved in the app's settings.")
                block("What's never collected", symbol: "eye.slash",
                      text: "There are no accounts, analytics, advertising identifiers or third-party SDKs. The app makes no network requests with your data.")
                block("Journal observations", symbol: "text.magnifyingglass",
                      text: "If turned on, Apple's NaturalLanguage framework estimates the tone of your wording and picks out repeated words — on this device only. Results are approximate, are recalculated when you open an entry, and are never stored or uploaded. No machine-learning model is trained by MIND BLOOM.")
                block("Your control", symbol: "slider.horizontal.3",
                      text: "You can export everything as a JSON file, remove sample data, or permanently delete all data from Settings → Your data. Deleting the app also deletes its data.")
                block("Not a medical service", symbol: "stethoscope",
                      text: "MIND BLOOM is a self-reflection and routine tool. It does not diagnose, treat or monitor any health condition, and it cannot respond to emergencies.")
                block("Getting support", symbol: "person.2.wave.2",
                      text: "If you are struggling, talk to someone you trust, your university's student counselling or wellbeing service, or a doctor. If you are in immediate danger, contact your local emergency number.")
            }
            .padding(Theme.screenPadding)
            .readableWidth()
        }
        .bloomBackground()
        .navigationTitle("Privacy & wellbeing")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func block(_ title: String, symbol: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.bloomHeadline)
                .foregroundStyle(Theme.ink)
            Text(text)
                .font(.bloomBody)
                .foregroundStyle(Theme.inkSecondary)
        }
        .bloomCard()
        .accessibilityElement(children: .combine)
    }
}
