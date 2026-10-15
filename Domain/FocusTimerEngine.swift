import Foundation

/// The focus timer as a small, deterministic state machine.
///
/// It never counts ticks. Instead it stores *when* the current running segment
/// began and how much time had already elapsed before it. Elapsed time is always
/// recomputed from the clock, so the timer stays accurate if the app is
/// backgrounded, and the whole engine can be saved (Codable) and restored after
/// the app is relaunched. Every method takes `now` so tests can control time.
struct FocusTimerEngine: Codable, Equatable, Sendable {
    enum State: String, Codable, Sendable {
        case idle, running, paused, finished
    }

    static let allowedMinutes = 1...180
    static let presetMinutes = [15, 25, 45, 60]
    /// Sessions ended early are only recorded once they reach this length.
    static let minimumRecordableSeconds: TimeInterval = 60

    private(set) var state: State = .idle
    private(set) var plannedDuration: TimeInterval
    private(set) var accumulated: TimeInterval = 0
    private(set) var segmentStart: Date?
    private(set) var sessionStart: Date?

    init(plannedMinutes: Int = 25) {
        plannedDuration = TimeInterval(Self.clamp(plannedMinutes) * 60)
    }

    static func clamp(_ minutes: Int) -> Int {
        min(max(minutes, allowedMinutes.lowerBound), allowedMinutes.upperBound)
    }

    var plannedMinutes: Int { Int(plannedDuration / 60) }

    func elapsed(at now: Date) -> TimeInterval {
        var total = accumulated
        if state == .running, let segmentStart {
            total += max(0, now.timeIntervalSince(segmentStart))
        }
        return min(total, plannedDuration)
    }

    func remaining(at now: Date) -> TimeInterval {
        max(0, plannedDuration - elapsed(at: now))
    }

    /// 0 at the start, 1 when the planned time has elapsed.
    func progress(at now: Date) -> Double {
        guard plannedDuration > 0 else { return 0 }
        return elapsed(at: now) / plannedDuration
    }

    /// The wall-clock moment the session will finish if it keeps running.
    func projectedEnd(from now: Date) -> Date? {
        state == .running ? now.addingTimeInterval(remaining(at: now)) : nil
    }

    // MARK: Transitions — each is ignored unless the current state allows it.

    mutating func setPlannedMinutes(_ minutes: Int) {
        guard state == .idle else { return }
        plannedDuration = TimeInterval(Self.clamp(minutes) * 60)
    }

    mutating func start(at now: Date) {
        guard state == .idle else { return }
        state = .running
        accumulated = 0
        sessionStart = now
        segmentStart = now
    }

    mutating func pause(at now: Date) {
        guard state == .running else { return }
        accumulated = elapsed(at: now)
        segmentStart = nil
        state = .paused
    }

    mutating func resume(at now: Date) {
        guard state == .paused else { return }
        segmentStart = now
        state = .running
    }

    mutating func reset() {
        state = .idle
        accumulated = 0
        segmentStart = nil
        sessionStart = nil
    }

    /// Call periodically while visible. Returns `true` exactly once: on the tick
    /// that moves the timer from running to finished.
    @discardableResult
    mutating func tick(at now: Date) -> Bool {
        guard state == .running, elapsed(at: now) >= plannedDuration else { return false }
        accumulated = plannedDuration
        segmentStart = nil
        state = .finished
        return true
    }

    /// Whether ending now would produce a session worth saving.
    func isRecordable(at now: Date) -> Bool {
        elapsed(at: now) >= Self.minimumRecordableSeconds
    }

    /// "25:00", or "1:05:00" for an hour or more. Rounds up so the display
    /// shows the full duration at the start and 0:00 only when time is up.
    static func format(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }
}
