import Foundation
import SwiftData

/// One mood check-in.
///
/// Enums are stored as their raw `String` so the on-disk schema stays simple and
/// readable; the typed `emotion` and `factors` properties wrap them.
/// Every stored property has a default so future lightweight migrations are safe.
@Model
final class MoodEntry {
    var id: UUID = UUID()
    var timestamp: Date = Date.now
    var emotionRaw: String = Emotion.okay.rawValue
    var intensity: Int = 3
    var note: String = ""
    var factorsRaw: [String] = []
    /// Records created by "Load sample data". Only these are removed by "Remove sample data".
    var isSample: Bool = false

    init(timestamp: Date = .now, emotion: Emotion, intensity: Int, note: String = "",
         factors: [MoodFactor] = [], isSample: Bool = false) {
        self.id = UUID()
        self.timestamp = timestamp
        self.emotionRaw = emotion.rawValue
        self.intensity = InputValidator.clampIntensity(intensity)
        self.note = InputValidator.sanitized(note, maxLength: InputValidator.maxNoteLength)
        self.factorsRaw = factors.map(\.rawValue)
        self.isSample = isSample
    }

    var emotion: Emotion {
        get { Emotion(rawValue: emotionRaw) ?? .okay }
        set { emotionRaw = newValue.rawValue }
    }

    var factors: [MoodFactor] {
        factorsRaw.compactMap(MoodFactor.init(rawValue:))
    }
}

extension MoodEntry: MoodRecord {}
