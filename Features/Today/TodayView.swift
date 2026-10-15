import SwiftUI
import SwiftData

/// Home dashboard: today's bloom, quick rituals, today's habits and a weekly glance.
struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppNavigation.self) private var navigation

    @Query(sort: \MoodEntry.timestamp, order: .reverse) private var moods: [MoodEntry]
    @Query(sort: \Habit.sortOrder) private var habits: [Habit]
    @Query(sort: \FocusSession.startedAt, order: .reverse) private var focusSessions: [FocusSession]
    @Query(sort: \BreathingSession.startedAt, order: .reverse) private var breathingSessions: [BreathingSession]

    @State private var errorMessage: String?
    @State private var toggleCount = 0

    private var now: Date { .now }

    private var ritualStatus: DailyRitualStatus {
        DailyRitualStatus.evaluate(moodTimes: moods.map(\.timestamp),
                                   breathingTimes: breathingSessions.map(\.startedAt),
                                   focusTimes: focusSessions.map(\.startedAt),
                                   habitCount: habits.count,
                                   habitsCompletedToday: habits.filter { $0.isCompleted(on: now) }.count,
                                   today: now)
    }

    private var todaysMood: MoodEntry? {
        moods.first { Calendar.current.isDateInToday($0.timestamp) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                bloomSummaryCard
                quickActions
                moodCard
                habitsCard
                weekGlance
            }
            .padding(Theme.screenPadding)
            .readableWidth()
        }
        .bloomBackground()
        .navigationTitle("Today")
        .toolbarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: toggleCount)
        .alert("Something went wrong", isPresented: Binding(get: { errorMessage != nil },
                                                             set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: Sections

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(now.formatted(.dateTime.weekday(.wide).day().month(.wide)).uppercased())
                    .font(.bloomCaption)
                    .tracking(1.2)
                    .foregroundStyle(Theme.inkSecondary)
                Text(Self.greeting(for: now))
                    .font(.bloomDisplay)
                    .foregroundStyle(Theme.ink)
            }
            Spacer()
            BloomLogo(size: 44)
        }
        .accessibilityElement(children: .combine)
    }

    private var bloomSummaryCard: some View {
        let status = ritualStatus
        return HStack(spacing: 20) {
            DailyBloomView(status: status)
                .frame(width: 128, height: 128)
            VStack(alignment: .leading, spacing: 8) {
                Text("Today's bloom")
                    .font(.bloomHeadline)
                    .foregroundStyle(Theme.ink)
                Text(Self.bloomMessage(for: status.completedCount))
                    .font(.bloomBody)
                    .foregroundStyle(Theme.inkSecondary)
                Text("\(status.completedCount) of 4 rituals")
                    .font(.bloomCaption)
                    .foregroundStyle(Theme.teal)
            }
        }
        .bloomCard(tint: Theme.mint)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("today.bloom")
    }

    private var quickActions: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
            QuickActionButton(symbol: "face.smiling", title: "Check in", detail: "How are you?",
                              tint: Theme.teal, done: ritualStatus.checkedIn) {
                navigation.open(.moodCheckIn)
            }
            .accessibilityIdentifier("today.action.checkin")
            QuickActionButton(symbol: "wind", title: "Breathe", detail: "1–5 minutes",
                              tint: Theme.lavender, done: ritualStatus.breathed) {
                navigation.open(.breathing)
            }
            .accessibilityIdentifier("today.action.breathe")
            QuickActionButton(symbol: "timer", title: "Focus", detail: "Study timer",
                              tint: Theme.sky, done: ritualStatus.focused) {
                navigation.open(.focus)
            }
            .accessibilityIdentifier("today.action.focus")
            QuickActionButton(symbol: "square.and.pencil", title: "Journal", detail: "Write it out",
                              tint: Theme.peach, done: false) {
                navigation.selectedTab = .journal
            }
            .accessibilityIdentifier("today.action.journal")
        }
    }

    @ViewBuilder
    private var moodCard: some View {
        if let mood = todaysMood {
            Button {
                navigation.open(.moodHistory)
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: mood.emotion.symbolName)
                        .font(.title2)
                        .foregroundStyle(mood.emotion.tint)
                        .frame(width: 52, height: 52)
                        .background(Circle().fill(mood.emotion.tint.opacity(0.15)))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Latest check-in").font(.bloomCaption).foregroundStyle(Theme.inkSecondary)
                        Text("\(mood.emotion.displayName) · intensity \(mood.intensity)/5")
                            .font(.bloomHeadline).foregroundStyle(Theme.ink)
                        Text(mood.timestamp.formatted(date: .omitted, time: .shortened))
                            .font(.bloomCaption).foregroundStyle(Theme.inkSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(Theme.inkSecondary)
                }
                .bloomCard()
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens your mood history")
        } else {
            EmptyStateView(symbol: "sparkles",
                           title: "No check-in yet today",
                           message: "Naming a feeling is a small first step. It takes about twenty seconds.",
                           actionTitle: "Check in now") { navigation.open(.moodCheckIn) }
        }
    }

    @ViewBuilder
    private var habitsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today's care").font(.bloomHeadline).foregroundStyle(Theme.ink)
                Spacer()
                Button("All habits") { navigation.selectedTab = .habits }
                    .font(.bloomCaption)
            }
            if habits.isEmpty {
                Text("Add a few gentle habits — like drinking water or a short walk — in the Habits tab.")
                    .font(.bloomBody)
                    .foregroundStyle(Theme.inkSecondary)
            } else {
                ForEach(habits.prefix(5)) { habit in
                    let done = habit.isCompleted(on: now)
                    Button {
                        toggle(habit)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: habit.symbolName)
                                .foregroundStyle(habit.tint.color)
                                .frame(width: 30)
                            Text(habit.name)
                                .font(.bloomBody)
                                .foregroundStyle(Theme.ink)
                                .strikethrough(done, color: Theme.inkSecondary)
                            Spacer()
                            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(done ? habit.tint.color : Theme.hairline)
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(habit.name)
                    .accessibilityValue(done ? "Done today" : "Not done yet")
                    .accessibilityHint("Double-tap to toggle")
                }
            }
        }
        .bloomCard()
    }

    private var weekGlance: some View {
        let moodSummary = MoodSummaryCalculator.summary(for: moods, lastDays: 7, endingOn: now)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("This week").font(.bloomHeadline).foregroundStyle(Theme.ink)
                Spacer()
                Button("Insights") { navigation.selectedTab = .insights }
                    .font(.bloomCaption)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
                StatTile(symbol: "face.smiling", value: "\(moodSummary.checkInCount)", caption: "check-ins")
                StatTile(symbol: "timer", value: "\(WellnessStats.totalMinutes(focusSessions, lastDays: 7, endingOn: now))",
                         caption: "focus minutes", tint: Theme.sky)
                StatTile(symbol: "wind", value: "\(WellnessStats.completedCount(breathingSessions, lastDays: 7, endingOn: now))",
                         caption: "breathing sessions", tint: Theme.lavender)
            }
        }
    }

    // MARK: Actions & helpers

    private func toggle(_ habit: Habit) {
        do {
            try WellnessRepository(context: modelContext).toggleHabit(habit, on: now)
            toggleCount += 1
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    static func greeting(for date: Date) -> String {
        switch Calendar.current.component(.hour, from: date) {
        case 5..<12: "Good morning"
        case 12..<17: "Good afternoon"
        case 17..<22: "Good evening"
        default: "Rest well"
        }
    }

    static func bloomMessage(for count: Int) -> String {
        switch count {
        case 0: "A fresh day. Start with whichever ritual feels easiest."
        case 1: "One petal open. Lovely start."
        case 2: "Halfway there — no rush."
        case 3: "Almost in full bloom."
        default: "Full bloom today. Be proud of the small things."
        }
    }
}

/// A large, tappable ritual shortcut.
struct QuickActionButton: View {
    let symbol: String
    let title: String
    let detail: String
    let tint: Color
    let done: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: symbol)
                        .font(.title3)
                        .foregroundStyle(tint)
                    Spacer()
                    if done {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(tint)
                            .accessibilityHidden(true)
                    }
                }
                Text(title).font(.bloomHeadline).foregroundStyle(Theme.ink)
                Text(detail).font(.bloomCaption).foregroundStyle(Theme.inkSecondary)
            }
            .bloomCard(padding: 14, tint: tint)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(done ? "Done today" : "")
        .accessibilityAddTraits(.isButton)
    }
}
