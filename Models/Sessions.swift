import Foundation
import SwiftData

/// A focus-timer session that was completed, or ended early after at least one minute.
@Model
final class FocusSession {
    var id: UUID = UUID()
    var startedAt: Date = Date.now
    var endedAt: Date = Date.now
    var plannedMinutes: Int = 25
    /// Time actually spent focusing (pauses excluded).
    var durationSeconds: Int = 0
    var wasCompleted: Bool = false
    /// Optional "what am I working on" note.
    var intention: String = ""
    var isSample: Bool = false

    init(startedAt: Date, endedAt: Date, plannedMinutes: Int, durationSeconds: Int,
         wasCompleted: Bool, intention: String = "", isSample: Bool = false) {
        self.id = UUID()
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.plannedMinutes = FocusTimerEngine.clamp(plannedMinutes)
        self.durationSeconds = max(0, durationSeconds)
        self.wasCompleted = wasCompleted
        self.intention = InputValidator.sanitized(intention, maxLength: 60)
        self.isSample = isSample
    }
}

extension FocusSession: TimedSessionRecord {}

/// A guided-breathing session.
@Model
final class BreathingSession {
    var id: UUID = UUID()
    var startedAt: Date = Date.now
    var durationSeconds: Int = 0
    var patternRaw: String = BreathingPattern.balanced.rawValue
    var cyclesCompleted: Int = 0
    var wasCompleted: Bool = false
    var isSample: Bool = false

    init(startedAt: Date, durationSeconds: Int, pattern: BreathingPattern, cyclesCompleted: Int,
         wasCompleted: Bool, isSample: Bool = false) {
        self.id = UUID()
        self.startedAt = startedAt
        self.durationSeconds = max(0, durationSeconds)
        self.patternRaw = pattern.rawValue
        self.cyclesCompleted = max(0, cyclesCompleted)
        self.wasCompleted = wasCompleted
        self.isSample = isSample
    }

    var pattern: BreathingPattern { BreathingPattern(rawValue: patternRaw) ?? .balanced }
}

extension BreathingSession: TimedSessionRecord {}
