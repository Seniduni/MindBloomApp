import SwiftUI
import SwiftData

struct FocusTimerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FocusSession.startedAt, order: .reverse) private var sessions: [FocusSession]

    @State private var model = FocusTimerModel()
    @State private var confirmingReset = false
    @State private var completionCount = 0
    @State private var stateChangeCount = 0
    @State private var customMinutes = 25
    @FocusState private var intentionFocused: Bool

    private var todaysSessions: [FocusSession] {
        sessions.filter { Calendar.current.isDateInToday($0.startedAt) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                timerRing
                if model.state == .idle { durationPicker }
                intentionField
                controls
                todaySummary
            }
            .padding(Theme.screenPadding)
            .readableWidth()
        }
        .scrollDismissesKeyboard(.interactively)
        .bloomBackground()
        .navigationTitle("Focus")
        .toolbarTitleDisplayMode(.inline)
        .sensoryFeedback(.success, trigger: completionCount)
        .sensoryFeedback(.impact(weight: .light), trigger: stateChangeCount)
        .task {
            customMinutes = model.plannedMinutes
            // Refresh four times a second while the screen is visible.
            while !Task.isCancelled {
                if model.refresh() { saveSession(completed: true) }
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
        .confirmationDialog("Reset this session?", isPresented: $confirmingReset, titleVisibility: .visible) {
            Button("Reset without saving", role: .destructive) { model.reset(); stateChangeCount += 1 }
            Button("Save what I've done", action: { saveSession(completed: false) })
        } message: {
            Text("You've focused for \(FocusTimerEngine.format(Double(model.elapsedSeconds))).")
        }
    }

    // MARK: Pieces

    private var timerRing: some View {
        ProgressRing(progress: model.progress, lineWidth: 16) {
            VStack(spacing: 6) {
                Text(model.remainingText)
                    .font(.bloomTimer)
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText(countsDown: true))
                    .accessibilityIdentifier("focus.time")
                Text(stateLabel)
                    .font(.bloomCaption)
                    .foregroundStyle(Theme.inkSecondary)
                    .accessibilityIdentifier("focus.state")
            }
            .minimumScaleFactor(0.5)
            .padding(28)
        }
        .frame(width: 270, height: 270)
        .padding(.top, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Focus timer")
        .accessibilityValue("\(model.remainingText) remaining, \(stateLabel)")
    }

    private var stateLabel: String {
        switch model.state {
        case .idle: "Ready · \(model.plannedMinutes) min"
        case .running: "Focusing"
        case .paused: "Paused"
        case .finished: "Complete — take a break"
        }
    }

    private var durationPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session length").font(.bloomHeadline).foregroundStyle(Theme.ink)
            FlowLayout(spacing: 8) {
                ForEach(FocusTimerEngine.presetMinutes, id: \.self) { minutes in
                    ChipToggle(title: "\(minutes) min", isSelected: model.plannedMinutes == minutes, tint: Theme.sky) {
                        customMinutes = minutes
                        model.setPlannedMinutes(minutes)
                    }
                    .accessibilityIdentifier("focus.duration.\(minutes)")
                }
            }
            Stepper("Custom: \(customMinutes) min", value: $customMinutes, in: FocusTimerEngine.allowedMinutes)
                .font(.bloomBody)
                .onChange(of: customMinutes) { _, value in model.setPlannedMinutes(value) }
                .accessibilityIdentifier("focus.stepper")
        }
        .bloomCard()
    }

    private var intentionField: some View {
        TextField("What will you focus on? (optional)", text: $model.intention)
            .font(.bloomBody)
            .focused($intentionFocused)
            .submitLabel(.done)
            .onSubmit { model.saveIntention() }
            .onChange(of: intentionFocused) { _, focused in if !focused { model.saveIntention() } }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.hairline))
            .disabled(model.state == .finished)
    }

    @ViewBuilder
    private var controls: some View {
        switch model.state {
        case .idle:
            Button("Start focus") { model.start(); stateChangeCount += 1 }
                .buttonStyle(.bloomPrimary)
                .accessibilityIdentifier("focus.start")
        case .running:
            HStack(spacing: 12) {
                Button("Pause") { model.pause(); stateChangeCount += 1 }
                    .buttonStyle(.bloomPrimary)
                    .accessibilityIdentifier("focus.pause")
                resetButton
            }
            finishEarlyButton
        case .paused:
            HStack(spacing: 12) {
                Button("Resume") { model.resume(); stateChangeCount += 1 }
                    .buttonStyle(.bloomPrimary)
                    .accessibilityIdentifier("focus.resume")
                resetButton
            }
            finishEarlyButton
        case .finished:
            Button("Start another") { model.reset(); stateChangeCount += 1 }
                .buttonStyle(.bloomPrimary)
                .accessibilityIdentifier("focus.again")
        }
    }

    private var resetButton: some View {
        Button("Reset") {
            if model.engine.isRecordable(at: .now) { confirmingReset = true } else { model.reset(); stateChangeCount += 1 }
        }
        .buttonStyle(.bloomSecondary)
        .accessibilityIdentifier("focus.reset")
    }

    @ViewBuilder
    private var finishEarlyButton: some View {
        if model.canFinishEarly {
            Button("Finish & save") { saveSession(completed: false) }
                .font(.bloomCaption)
                .accessibilityIdentifier("focus.finishEarly")
        }
    }

    private var todaySummary: some View {
        let minutes = todaysSessions.reduce(0) { $0 + $1.durationSeconds } / 60
        return VStack(alignment: .leading, spacing: 10) {
            Text("Today").font(.bloomHeadline).foregroundStyle(Theme.ink)
            if todaysSessions.isEmpty {
                Text("No focus sessions yet today.")
                    .font(.bloomBody)
                    .foregroundStyle(Theme.inkSecondary)
            } else {
                Text("\(todaysSessions.count) sessions · \(minutes) minutes")
                    .font(.bloomBody)
                    .foregroundStyle(Theme.ink)
                ForEach(todaysSessions.prefix(4)) { session in
                    HStack {
                        Image(systemName: session.wasCompleted ? "checkmark.circle.fill" : "circle.lefthalf.filled")
                            .foregroundStyle(Theme.sky)
                        Text(session.intention.isEmpty ? "Focus session" : session.intention)
                            .font(.bloomBody)
                        Spacer()
                        Text("\(session.durationSeconds / 60) min")
                            .font(.bloomCaption)
                            .foregroundStyle(Theme.inkSecondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .bloomCard()
    }

    // MARK: Saving

    private func saveSession(completed: Bool) {
        guard let snapshot = model.sessionSnapshot() else { return }
        if completed || snapshot.focusedSeconds >= Int(FocusTimerEngine.minimumRecordableSeconds) {
            try? WellnessRepository(context: modelContext)
                .recordFocusSession(startedAt: snapshot.start,
                                    endedAt: snapshot.start.addingTimeInterval(TimeInterval(snapshot.focusedSeconds)),
                                    plannedMinutes: snapshot.planned,
                                    focusedSeconds: snapshot.focusedSeconds,
                                    completed: completed,
                                    intention: model.intention)
        }
        if completed {
            completionCount += 1   // stays on the "finished" state until the student starts another
        } else {
            model.reset()
            stateChangeCount += 1
        }
    }
}
