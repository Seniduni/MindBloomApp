import CoreHaptics
import UIKit

/// Gentle breathing haptics with Core Haptics.
///
/// Inhale: a soft continuous vibration that slowly swells. Exhale: one that slowly
/// fades. Holds: a single light tap. Devices without a Taptic Engine — and the
/// iOS Simulator — report no haptic support, so every call safely does nothing.
/// Simple "success" moments elsewhere in the app use SwiftUI's `.sensoryFeedback`.
@MainActor
final class HapticsService {
    static let shared = HapticsService()

    private var engine: CHHapticEngine?

    var isSupported: Bool {
        CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }

    private init() {}

    func prepare() {
        guard isSupported, engine == nil else { return }
        do {
            let engine = try CHHapticEngine()
            engine.isAutoShutdownEnabled = true
            // If the system stops the engine (e.g. audio interruption) restart on next use.
            engine.resetHandler = { [weak engine] in try? engine?.start() }
            try engine.start()
            self.engine = engine
        } catch {
            engine = nil
        }
    }

    func playBreathPhase(_ kind: BreathPhaseKind, duration: Double) {
        guard isSupported else { return }
        prepare()
        guard let engine else { return }
        do {
            let pattern: CHHapticPattern
            switch kind {
            case .inhale, .exhale:
                let rising = kind == .inhale
                let event = CHHapticEvent(eventType: .hapticContinuous,
                                          parameters: [
                                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.45),
                                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.05)
                                          ],
                                          relativeTime: 0,
                                          duration: duration)
                let curve = CHHapticParameterCurve(parameterID: .hapticIntensityControl,
                                                   controlPoints: [
                                                    .init(relativeTime: 0, value: rising ? 0.15 : 0.9),
                                                    .init(relativeTime: duration, value: rising ? 0.9 : 0.1)
                                                   ],
                                                   relativeTime: 0)
                pattern = try CHHapticPattern(events: [event], parameterCurves: [curve])
            case .holdIn, .holdOut:
                let tap = CHHapticEvent(eventType: .hapticTransient,
                                        parameters: [
                                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
                                        ],
                                        relativeTime: 0)
                pattern = try CHHapticPattern(events: [tap], parameters: [])
            }
            try engine.start()
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            // Haptics are an enhancement only; failures are ignored on purpose.
        }
    }

    func stop() {
        engine?.stop(completionHandler: nil)
        engine = nil
    }
}
