import SwiftUI
import SwiftData
import UIKit

/// Guided breathing. Visuals are drawn from the clock with `TimelineView`, so the
/// animation never drifts. A separate task plays haptics, announces phases for
/// VoiceOver, and ends the session when time is up.
struct BreathingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.bloomReduceMotion) private var reduceMotion
    @AppStorage(SettingsKey.hapticsEnabled) private var hapticsEnabled = true

    @State private var pattern: BreathingPattern = .balanced
    @State private var durationSeconds = 180
    @State private var sessionStart: Date?
    @State private var result: SessionResult?
    @State private var completionCount = 0

    struct SessionResult: Equatable {
        let seconds: Int
        let cycles: Int
        let completed: Bool
        let saved: Bool
    }

    /// UI tests get a 12-second option so "complete a session" can be tested quickly.
    private var durationOptions: [Int] {
        var options = BreathingPattern.durationOptions.map { $0 * 60 }
        if ProcessInfo.processInfo.arguments.contains(LaunchArgument.uiTesting) { options.insert(12, at: 0) }
        return options
    }

    private var isRunning: Bool { sessionStart != nil }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                orbArea
                    .frame(height: 320)
                if let result {
                    resultCard(result)
                } else if !isRunning {
                    setupCard
                }
                controls
                if !isRunning {
                    Text("Breathe gently and comfortably. If you feel light-headed, stop and breathe normally.")
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(Theme.screenPadding)
            .readableWidth()
        }
        .bloomBackground()
        .navigationTitle("Breathe")
        .toolbarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isRunning)
        .sensoryFeedback(.success, trigger: completionCount)
        .task(id: sessionStart) { await runSessionLoop() }
        .onDisappear {
            if isRunning { finish(completed: false) }
        }
    }

    // MARK: Orb

    private var orbArea: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !isRunning)) { context in
            let elapsed = sessionStart.map { context.date.timeIntervalSince($0) } ?? 0
            let progress = pattern.progress(atElapsed: elapsed)
            VStack(spacing: 16) {
                BreathingOrbView(scale: isRunning ? BreathingPattern.orbScale(for: progress) : 0.7,
                                 phase: isRunning ? progress.phase : nil,
                                 phaseFraction: progress.phaseFraction,
                                 reduceMotion: reduceMotion)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                if isRunning {
                    Text(progress.phase.instruction)
                        .font(.bloomTitle)
                        .foregroundStyle(Theme.ink)
                        .contentTransition(.opacity)
                        .accessibilityIdentifier("breathing.phase")
                    Text("\(Int(progress.secondsLeftInPhase.rounded(.up)))  ·  \(FocusTimerEngine.format(max(0, Double(durationSeconds) - elapsed))) left")
                        .font(.system(.body, design: .rounded).monospacedDigit())
                        .foregroundStyle(Theme.inkSecondary)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: Setup

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Rhythm", selection: $pattern) {
                ForEach(BreathingPattern.allCases) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("breathing.pattern")
            Text(pattern.summary)
                .font(.bloomBody)
                .foregroundStyle(Theme.inkSecondary)

            Text("Length").font(.bloomHeadline).foregroundStyle(Theme.ink)
            FlowLayout(spacing: 8) {
                ForEach(durationOptions, id: \.self) { seconds in
                    ChipToggle(title: seconds < 60 ? "\(seconds) sec" : "\(seconds / 60) min",
                               isSelected: durationSeconds == seconds) { durationSeconds = seconds }
                        .accessibilityIdentifier("breathing.duration.\(seconds)")
                }
            }

            if HapticsService.shared.isSupported {
                Toggle("Gentle haptics", isOn: $hapticsEnabled)
                    .font(.bloomBody)
            } else {
                Label("Haptic guidance isn't available on this device.", systemImage: "iphone.slash")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSecondary)
            }
        }
        .bloomCard()
    }

    private func resultCard(_ result: SessionResult) -> some View {
        VStack(spacing: 8) {
            Image(systemName: result.completed ? "checkmark.seal.fill" : "pause.circle")
                .font(.largeTitle)
                .foregroundStyle(Theme.bloomGradient)
            Text(result.completed ? "Session complete" : "Session ended early")
                .font(.bloomTitle)
                .foregroundStyle(Theme.ink)
                .accessibilityIdentifier("breathing.result")
            Text("\(FocusTimerEngine.format(Double(result.seconds))) · \(result.cycles) breath cycles")
                .font(.bloomBody)
                .foregroundStyle(Theme.inkSecondary)
            Text(result.saved ? "Saved to your insights." : "Sessions under 30 seconds aren't saved.")
                .font(.bloomCaption)
                .foregroundStyle(Theme.inkSecondary)
        }
        .frame(maxWidth: .infinity)
        .bloomCard(tint: Theme.lavender)
    }

    @ViewBuilder
    private var controls: some View {
        if isRunning {
            Button("End session") { finish(completed: false) }
                .buttonStyle(.bloomSecondary)
                .accessibilityIdentifier("breathing.end")
        } else {
            Button(result == nil ? "Begin" : "Breathe again") {
                result = nil
                sessionStart = .now
            }
            .buttonStyle(.bloomPrimary)
            .accessibilityIdentifier("breathing.start")
        }
    }

    // MARK: Session logic

    private func runSessionLoop() async {
        guard let start = sessionStart else { return }
        if hapticsEnabled { HapticsService.shared.prepare() }
        var lastPhaseKey = -1
        while !Task.isCancelled {
            let elapsed = Date.now.timeIntervalSince(start)
            if elapsed >= Double(durationSeconds) {
                finish(completed: true)
                return
            }
            let progress = pattern.progress(atElapsed: elapsed)
            let key = progress.completedCycles * 10 + progress.phaseIndex
            if key != lastPhaseKey {
                lastPhaseKey = key
                if hapticsEnabled {
                    HapticsService.shared.playBreathPhase(progress.phase, duration: progress.secondsLeftInPhase)
                }
                if UIAccessibility.isVoiceOverRunning {
                    UIAccessibility.post(notification: .announcement, argument: progress.phase.instruction)
                }
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    private func finish(completed: Bool) {
        guard let start = sessionStart else { return }
        let elapsed = min(Date.now.timeIntervalSince(start), Double(durationSeconds))
        let cycles = Int(elapsed / pattern.cycleDuration)
        let shouldSave = completed || elapsed >= BreathingPattern.minimumRecordableSeconds
        if shouldSave {
            try? WellnessRepository(context: modelContext)
                .recordBreathingSession(startedAt: start, seconds: Int(elapsed), pattern: pattern,
                                        cycles: cycles, completed: completed)
        }
        sessionStart = nil
        HapticsService.shared.stop()
        result = SessionResult(seconds: Int(elapsed), cycles: cycles, completed: completed, saved: shouldSave)
        if completed { completionCount += 1 }
    }
}

/// The breathing visual: a soft orb ringed by petals that swells and settles.
/// With reduced motion it stays still and shows a progress ring instead.
struct BreathingOrbView: View {
    let scale: Double
    let phase: BreathPhaseKind?
    let phaseFraction: Double
    let reduceMotion: Bool

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            ZStack {
                if reduceMotion {
                    Circle()
                        .fill(phaseColor.opacity(0.25))
                        .frame(width: size * 0.8)
                    ProgressRing(progress: phase == nil ? 0 : phaseFraction, lineWidth: 10)
                        .frame(width: size * 0.8)
                    Image(systemName: phase == .exhale ? "arrow.down" : (phase == nil ? "wind" : "arrow.up"))
                        .font(.largeTitle)
                        .foregroundStyle(phaseColor)
                } else {
                    Circle()
                        .fill(Theme.lavender.opacity(0.25))
                        .frame(width: size * scale)
                        .blur(radius: 30)
                    ForEach(0..<8, id: \.self) { index in
                        PetalShape(fullness: 0.5)
                            .fill(index.isMultiple(of: 2) ? Theme.mint.opacity(0.45) : Theme.lavender.opacity(0.4))
                            .frame(width: size * 0.18, height: size * 0.3)
                            .offset(y: -size * 0.27 * scale)
                            .rotationEffect(.degrees(Double(index) * 45 + scale * 30))
                    }
                    Circle()
                        .fill(RadialGradient(colors: [Theme.mint, Theme.teal], center: .center,
                                             startRadius: 4, endRadius: size * 0.35))
                        .frame(width: size * 0.5 * scale, height: size * 0.5 * scale)
                        .shadow(color: Theme.teal.opacity(0.35), radius: 24)
                }
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityHidden(true)
    }

    private var phaseColor: Color {
        switch phase {
        case .inhale: Theme.teal
        case .exhale: Theme.lavender
        case .holdIn, .holdOut: Theme.sky
        case nil: Theme.mint
        }
    }
}
