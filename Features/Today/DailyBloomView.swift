import SwiftUI

/// Four petals — check in, breathe, focus, care — that open as rituals are completed.
struct DailyBloomView: View {
    let status: DailyRitualStatus
    @Environment(\.bloomReduceMotion) private var reduceMotion

    private var petals: [(done: Bool, color: Color, name: String)] {
        [(status.checkedIn, Theme.teal, "Check in"),
         (status.breathed, Theme.lavender, "Breathe"),
         (status.focused, Theme.sky, "Focus"),
         (status.habitsDone, Theme.mint, "Care")]
    }

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            ZStack {
                ForEach(Array(petals.enumerated()), id: \.offset) { index, petal in
                    PetalShape(fullness: petal.done ? 0.75 : 0.45)
                        .fill(petal.done ? AnyShapeStyle(petal.color.gradient) : AnyShapeStyle(Theme.surfaceSunken))
                        .overlay {
                            PetalShape(fullness: petal.done ? 0.75 : 0.45)
                                .stroke(petal.color.opacity(petal.done ? 0 : 0.5),
                                        style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        }
                        .frame(width: size * 0.36, height: size * 0.48)
                        .scaleEffect(petal.done ? 1 : 0.86, anchor: .bottom)
                        .offset(y: -size * 0.24)
                        .rotationEffect(.degrees(Double(index) * 90 + 45))
                }
                Circle()
                    .fill(Theme.surface)
                    .frame(width: size * 0.34, height: size * 0.34)
                    .shadow(color: .black.opacity(0.08), radius: 4)
                Text("\(status.completedCount)/4")
                    .font(.system(.headline, design: .rounded).monospacedDigit())
                    .foregroundStyle(Theme.ink)
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(reduceMotion ? nil : .spring(duration: 0.7, bounce: 0.3), value: status)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Daily bloom")
        .accessibilityValue(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        let done = petals.filter { $0.done }.map { $0.name }
        return done.isEmpty
            ? "No rituals completed yet today"
            : "\(done.count) of 4 rituals completed: \(done.joined(separator: ", "))"
    }
}

#Preview {
    DailyBloomView(status: DailyRitualStatus(checkedIn: true, breathed: false, focused: true, habitsDone: false))
        .frame(width: 160, height: 160)
        .padding()
}
