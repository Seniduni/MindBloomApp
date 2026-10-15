import SwiftUI

/// Shows Apple NaturalLanguage observations for one entry, clearly labelled as
/// approximate and computed on this device.
struct ReflectionInsightCard: View {
    let text: String

    @State private var observation: JournalObservation?
    @State private var showingAbout = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Reflection observations", systemImage: "text.magnifyingglass")
                    .font(.bloomHeadline)
                    .foregroundStyle(Theme.ink)
                Spacer()
                Button { showingAbout.toggle() } label: {
                    Image(systemName: "info.circle")
                }
                .accessibilityLabel("About these observations")
            }

            if let observation {
                if !observation.hasEnoughText {
                    Text("Write at least \(JournalAnalyzer.minimumWords) words for an observation.")
                        .font(.bloomBody)
                        .foregroundStyle(Theme.inkSecondary)
                } else {
                    if let score = observation.sentimentScore, let tone = observation.tone {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(tone.label).font(.bloomBody).foregroundStyle(Theme.ink)
                            ToneBar(score: score)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(tone.label)
                        .accessibilityValue(String(format: "Score %.1f on a scale from minus 1 to plus 1", score))
                    } else {
                        Text("Tone isn't available for this language, so only keywords are shown.")
                            .font(.bloomBody)
                            .foregroundStyle(Theme.inkSecondary)
                    }
                    if !observation.keywords.isEmpty {
                        Text("Words that stood out").font(.bloomCaption).foregroundStyle(Theme.inkSecondary)
                        FlowLayout(spacing: 6) {
                            ForEach(observation.keywords, id: \.self) { word in
                                Text(word)
                                    .font(.bloomCaption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(Theme.lavenderMist))
                            }
                        }
                    }
                    Text("\(observation.wordCount) words")
                        .font(.bloomCaption)
                        .foregroundStyle(Theme.inkSecondary)
                }
            } else {
                ProgressView()
            }

            if showingAbout {
                Text("These observations come from Apple's built-in NaturalLanguage framework, running entirely on this device. The tone score reflects the wording only — it can misread sarcasm, mixed feelings, slang or context, and it is not an assessment of your mental health. Nothing is uploaded, stored or used to train a model.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSecondary)
                    .transition(.opacity)
            }
        }
        .bloomCard(tint: Theme.lavender)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("journal.reflection")
        .task(id: text) {
            observation = JournalAnalyzer().analyze(text)
        }
    }
}

/// A horizontal scale from heavy (left) to positive (right) with a marker.
struct ToneBar: View {
    let score: Double

    var body: some View {
        GeometryReader { proxy in
            let x = (score + 1) / 2 * proxy.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(LinearGradient(colors: [Theme.lavender, Theme.sun, Theme.teal],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(height: 8)
                    .opacity(0.6)
                Circle()
                    .fill(Theme.surface)
                    .overlay(Circle().stroke(Theme.ink, lineWidth: 2))
                    .frame(width: 18, height: 18)
                    .offset(x: min(max(0, x - 9), proxy.size.width - 18))
            }
            .frame(height: proxy.size.height)
        }
        .frame(height: 20)
    }
}
