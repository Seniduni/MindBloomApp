import Foundation
import Observation

/// View-facing wrapper around `FocusTimerEngine`.
///
/// After every change the engine is saved to `UserDefaults` as JSON. When the
/// app is relaunched the timer is restored exactly: a running timer keeps
/// counting from its original start, and one that ran out while the app was
/// closed is detected on the first refresh and recorded as completed.
@Observable
@MainActor
final class FocusTimerModel {
    private(set) var engine: FocusTimerEngine
    var intention: String
    /// Updated by the view's refresh loop; drives the displayed time.
    private(set) var now: Date = .now

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: SettingsKey.focusTimerState),
           let saved = try? JSONDecoder().decode(FocusTimerEngine.self, from: data) {
            engine = saved
        } else {
            engine = FocusTimerEngine(plannedMinutes: 25)
        }
        intention = defaults.string(forKey: SettingsKey.focusIntention) ?? ""
    }

    var state: FocusTimerEngine.State { engine.state }
    var remainingText: String { FocusTimerEngine.format(engine.remaining(at: now)) }
    var progress: Double { engine.progress(at: now) }
    var plannedMinutes: Int { engine.plannedMinutes }
    var elapsedSeconds: Int { Int(engine.elapsed(at: now)) }
    var canFinishEarly: Bool { (state == .running || state == .paused) && engine.isRecordable(at: now) }

    func setPlannedMinutes(_ minutes: Int) { engine.setPlannedMinutes(minutes); persist() }

    func start() {
        now = .now
        engine.start(at: now)
        persist()
        scheduleNotification()
    }

    func pause() {
        now = .now
        engine.pause(at: now)
        persist()
        ReminderService.cancelFocusFinished()
    }

    func resume() {
        now = .now
        engine.resume(at: now)
        persist()
        scheduleNotification()
    }

    func reset() {
        engine.reset()
        persist()
        ReminderService.cancelFocusFinished()
    }

    /// Advances the clock. Returns true once, when the session has just finished.
    @discardableResult
    func refresh(at date: Date = .now) -> Bool {
        now = date
        let finished = engine.tick(at: date)
        if finished { persist() }
        return finished
    }

    /// Details needed to save the current session to SwiftData.
    func sessionSnapshot() -> (start: Date, focusedSeconds: Int, planned: Int)? {
        guard let start = engine.sessionStart else { return nil }
        return (start, Int(engine.elapsed(at: now)), engine.plannedMinutes)
    }

    func saveIntention() {
        defaults.set(intention, forKey: SettingsKey.focusIntention)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(engine) {
            defaults.set(data, forKey: SettingsKey.focusTimerState)
        }
    }

    private func scheduleNotification() {
        guard let end = engine.projectedEnd(from: now) else { return }
        Task { await ReminderService.scheduleFocusFinished(at: end) }
    }
}
