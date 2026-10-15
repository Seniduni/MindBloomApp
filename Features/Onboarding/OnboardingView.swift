import SwiftUI
import SwiftData

/// Three short pages: welcome, how the app works, and privacy & limits.
/// The student must acknowledge that MIND BLOOM is not medical care before starting.
struct OnboardingView: View {
    @AppStorage(SettingsKey.hasCompletedOnboarding) private var hasCompletedOnboarding = false
    @Environment(\.modelContext) private var modelContext
    @Environment(\.bloomReduceMotion) private var reduceMotion

    @State private var page = 0
    @State private var acknowledged = false
    @State private var startWithSamples = false
    @State private var logoOpenness: CGFloat = 0.2

    private let lastPage = 2

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                welcome.tag(0)
                rituals.tag(1)
                privacy.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            footer
                .padding(.horizontal, Theme.screenPadding)
                .padding(.bottom, 12)
                .readableWidth()
        }
        .bloomBackground()
        .onAppear {
            if reduceMotion {
                logoOpenness = 1
            } else {
                withAnimation(.spring(duration: 1.6, bounce: 0.2).delay(0.2)) { logoOpenness = 1 }
            }
        }
    }

    // MARK: Pages

    private var welcome: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 40)
                BloomLogo(size: 140, openness: logoOpenness)
                Text("MIND BLOOM")
                    .font(.system(.largeTitle, design: .serif).weight(.semibold))
                    .tracking(4)
                    .foregroundStyle(Theme.ink)
                Text("Small, steady rituals for calmer study days.")
                    .font(.bloomTitle)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.ink)
                Text("Check in with how you feel, breathe, focus, and care for the habits that keep you well — all in one quiet place.")
                    .font(.bloomBody)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.inkSecondary)
            }
            .padding(Theme.screenPadding)
            .readableWidth()
        }
        .accessibilityIdentifier("onboarding.page.welcome")
    }

    private var rituals: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Your daily bloom")
                    .font(.bloomDisplay)
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 40)
                Text("Each ritual opens one petal. Four petals make a full bloom — but every small step counts.")
                    .font(.bloomBody)
                    .foregroundStyle(Theme.inkSecondary)
                ritualRow("face.smiling", "Check in", "Name a feeling and how strong it is.", Theme.teal)
                ritualRow("wind", "Breathe", "A guided, paced breathing session.", Theme.lavender)
                ritualRow("timer", "Focus", "A distraction-light study timer.", Theme.sky)
                ritualRow("checklist", "Care", "Tick off the self-care habits you choose.", Theme.mint)
            }
            .padding(Theme.screenPadding)
            .readableWidth()
        }
        .accessibilityIdentifier("onboarding.page.rituals")
    }

    private func ritualRow(_ symbol: String, _ title: String, _ detail: String, _ tint: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 48, height: 48)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(tint.opacity(0.15)))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.bloomHeadline).foregroundStyle(Theme.ink)
                Text(detail).font(.bloomBody).foregroundStyle(Theme.inkSecondary)
            }
        }
        .bloomCard(padding: 14)
        .accessibilityElement(children: .combine)
    }

    private var privacy: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Private by design")
                    .font(.bloomDisplay)
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 40)
                privacyPoint("iphone", "Everything stays on this device. No account, no cloud sync, no ads or trackers.")
                privacyPoint("text.magnifyingglass", "Optional journal observations use Apple's on-device language tools. Your writing is never sent to an AI service.")
                privacyPoint("trash", "You can export or permanently delete your data at any time in Settings.")
                privacyPoint("stethoscope", "MIND BLOOM is for everyday self-reflection. It does not diagnose, treat or replace professional care.")

                checkbox(isOn: $acknowledged,
                         text: "I understand MIND BLOOM is a self-reflection tool, not medical care.",
                         identifier: "onboarding.acknowledge")
                checkbox(isOn: $startWithSamples,
                         text: "Start with two weeks of sample data so I can explore (removable later).",
                         identifier: "onboarding.sampleData")
            }
            .padding(Theme.screenPadding)
            .readableWidth()
        }
        .accessibilityIdentifier("onboarding.page.privacy")
    }

    private func privacyPoint(_ symbol: String, _ text: String) -> some View {
        Label {
            Text(text).font(.bloomBody).foregroundStyle(Theme.ink)
        } icon: {
            Image(systemName: symbol).foregroundStyle(Theme.teal)
        }
    }

    /// A tappable checkbox (more reliable than `Toggle` for large touch targets and UI tests).
    private func checkbox(isOn: Binding<Bool>, text: String, identifier: String) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isOn.wrappedValue ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundStyle(isOn.wrappedValue ? Theme.teal : Theme.inkSecondary)
                Text(text)
                    .font(.bloomBody)
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .bloomCard(padding: 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityValue(isOn.wrappedValue ? "Selected" : "Not selected")
        .accessibilityAddTraits(isOn.wrappedValue ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: Footer

    private var footer: some View {
        Group {
            if page < lastPage {
                Button("Continue") {
                    withAnimation(reduceMotion ? nil : .easeInOut) { page += 1 }
                }
                .buttonStyle(.bloomPrimary)
                .accessibilityIdentifier("onboarding.continue")
            } else {
                Button("Begin") { finish() }
                    .buttonStyle(.bloomPrimary)
                    .disabled(!acknowledged)
                    .accessibilityIdentifier("onboarding.begin")
                    .accessibilityHint(acknowledged ? "" : "Tick the acknowledgement above first.")
            }
        }
    }

    private func finish() {
        if startWithSamples {
            try? DemoDataService.loadSampleData(into: modelContext)
        }
        hasCompletedOnboarding = true
    }
}

#Preview {
    OnboardingView()
        .modelContainer(try! PersistenceController.makeContainer(inMemory: true))
}
