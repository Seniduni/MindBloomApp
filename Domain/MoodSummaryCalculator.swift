import Foundation

/// Anything that looks like a mood check-in. `MoodEntry` (SwiftData) conforms,
/// and unit tests use a lightweight struct, so the maths never needs a database.
protocol MoodRecord {
    var timestamp: Date { get }
    var emotion: Emotion { get }
    var intensity: Int { get }
}

enum MoodTrend: Equatable, Sendable {
    case improving, steady, dipping, insufficientData

    var description: String {
        switch self {
        case .improving: "Trending brighter"
        case .steady: "Fairly steady"
        case .dipping: "A heavier stretch"
        case .insufficientData: "Not enough check-ins yet"
        }
    }
}

struct MoodSummary: Equatable, Sendable {
    let checkInCount: Int
    let daysWithCheckIns: Int
    /// Average mood score (1–5) across all check-ins in the period, or nil if none.
    let averageScore: Double?
    /// Average intensity (1–5), or nil if none.
    let averageIntensity: Double?
    let mostFrequentEmotion: Emotion?
    let emotionCounts: [Emotion: Int]
    /// One point per day that has at least one check-in (days without data are omitted, not zero-filled).
    let dailyAverages: [DailyValue]
    let trend: MoodTrend

    static let empty = MoodSummary(checkInCount: 0, daysWithCheckIns: 0, averageScore: nil,
                                   averageIntensity: nil, mostFrequentEmotion: nil,
                                   emotionCounts: [:], dailyAverages: [], trend: .insufficientData)
}

/// Turns stored check-ins into the numbers shown on the Today and Insights screens.
enum MoodSummaryCalculator {
    /// Minimum number of distinct days before the app describes a trend.
    static let minimumDaysForTrend = 4
    /// Difference in mood score between the two halves of the period that counts as a change.
    static let trendThreshold = 0.5

    static func summary<R: MoodRecord>(for records: [R],
                                       lastDays days: Int,
                                       endingOn end: Date,
                                       calendar: Calendar = .current) -> MoodSummary {
        let window = calendar.interval(lastDays: days, endingOn: end)
        let inWindow = records.filter { window.containsHalfOpen($0.timestamp) }
        guard !inWindow.isEmpty else { return .empty }

        let scores = inWindow.map { $0.emotion.moodScore }
        let averageScore = scores.reduce(0, +) / Double(scores.count)
        let averageIntensity = Double(inWindow.map(\.intensity).reduce(0, +)) / Double(inWindow.count)

        var counts: [Emotion: Int] = [:]
        for record in inWindow { counts[record.emotion, default: 0] += 1 }

        let grouped = Dictionary(grouping: inWindow) { calendar.startOfDay(for: $0.timestamp) }
        let daily = grouped
            .map { day, items in
                DailyValue(day: day, value: items.map { $0.emotion.moodScore }.reduce(0, +) / Double(items.count))
            }
            .sorted { $0.day < $1.day }

        return MoodSummary(checkInCount: inWindow.count,
                           daysWithCheckIns: daily.count,
                           averageScore: averageScore,
                           averageIntensity: averageIntensity,
                           mostFrequentEmotion: mostFrequent(in: counts),
                           emotionCounts: counts,
                           dailyAverages: daily,
                           trend: trend(for: daily))
    }

    /// Highest count wins; ties are broken by the order emotions are declared, so results are deterministic.
    static func mostFrequent(in counts: [Emotion: Int]) -> Emotion? {
        var best: Emotion?
        var bestCount = 0
        for emotion in Emotion.allCases {
            let count = counts[emotion, default: 0]
            if count > bestCount {
                best = emotion
                bestCount = count
            }
        }
        return best
    }

    /// Compares the average of the earlier half of the days with data against the later half.
    static func trend(for daily: [DailyValue]) -> MoodTrend {
        guard daily.count >= minimumDaysForTrend else { return .insufficientData }
        let middle = daily.count / 2
        let earlier = daily[..<middle].map(\.value)
        let later = daily[middle...].map(\.value)
        let delta = later.reduce(0, +) / Double(later.count) - earlier.reduce(0, +) / Double(earlier.count)
        if delta >= trendThreshold { return .improving }
        if delta <= -trendThreshold { return .dipping }
        return .steady
    }

    /// A friendly word for a 1–5 score, used beside numbers so they are not read as a grade.
    static func label(forScore score: Double) -> String {
        switch score {
        case ..<1.8: "Heavy"
        case ..<2.6: "Low"
        case ..<3.4: "Balanced"
        case ..<4.2: "Good"
        default: "Bright"
        }
    }
}
