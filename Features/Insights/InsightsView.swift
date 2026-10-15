import SwiftUI
import SwiftData
import Charts

/// Weekly / monthly trends. Every number and chart is calculated from records
/// stored on the device — nothing is estimated or invented.
struct InsightsView: View {
    @Query(sort: \MoodEntry.timestamp) private var moods: [MoodEntry]
    @Query(sort: \Habit.sortOrder) private var habits: [Habit]
    @Query private var completions: [HabitCompletion]
    @Query(sort: \FocusSession.startedAt) private var focusSessions: [FocusSession]
    @Query(sort: \BreathingSession.startedAt) private var breathingSessions: [BreathingSession]

    @State private var range: InsightRange = .week
    @State private var selectedMoodDay: Date?

    enum InsightRange: Int, CaseIterable, Identifiable {
        case week = 7, month = 30
        var id: Int { rawValue }
        var label: String { self == .week ? "7 days" : "30 days" }
    }

    private var now: Date { .now }
    private var days: Int { range.rawValue }

    private var moodSummary: MoodSummary {
        MoodSummaryCalculator.summary(for: moods, lastDays: days, endingOn: now)
    }

    private var hasAnyData: Bool {
        !moods.isEmpty || !completions.isEmpty || !focusSessions.isEmpty || !breathingSessions.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Picker("Range", selection: $range) {
                        ForEach(InsightRange.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("insights.range")

                    if hasAnyData {
                        summaryTiles
                        moodTrendCard
                        emotionCard
                        calmFocusCard
                        habitCard
                        highlightsCard
                    } else {
                        EmptyStateView(symbol: "chart.line.uptrend.xyaxis",
                                       title: "Insights grow with you",
                                       message: "Check in, breathe, focus or tick off a habit and your trends will appear here. You can also load sample data in Settings.")
                    }
                    WellbeingDisclaimer()
                }
                .padding(Theme.screenPadding)
                .readableWidth()
            }
            .bloomBackground()
            .navigationTitle("Insights")
            .onChange(of: range) { _, _ in selectedMoodDay = nil }
        }
    }

    // MARK: Tiles

    private var summaryTiles: some View {
        let summary = moodSummary
        let habitRatio = averageHabitCompletion
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
            StatTile(symbol: "face.smiling",
                     value: summary.averageScore.map { String(format: "%.1f", $0) } ?? "–",
                     caption: summary.averageScore.map { "avg mood · \(MoodSummaryCalculator.label(forScore: $0))" } ?? "avg mood")
            StatTile(symbol: "calendar", value: "\(summary.daysWithCheckIns)/\(days)",
                     caption: "days checked in", tint: Theme.mint)
            StatTile(symbol: "timer", value: "\(WellnessStats.totalMinutes(focusSessions, lastDays: days, endingOn: now))",
                     caption: "focus minutes", tint: Theme.sky)
            StatTile(symbol: "wind", value: "\(WellnessStats.completedCount(breathingSessions, lastDays: days, endingOn: now))",
                     caption: "breathing sessions", tint: Theme.lavender)
            StatTile(symbol: "checklist", value: habits.isEmpty ? "–" : "\(Int((habitRatio * 100).rounded()))%",
                     caption: "habit completion", tint: Theme.sun)
        }
    }

    // MARK: Mood trend (interactive)

    private var moodTrendCard: some View {
        let summary = moodSummary
        let points = summary.dailyAverages
        let selected = selectedMoodDay.flatMap { day in
            points.first { Calendar.current.isDate($0.day, inSameDayAs: day) }
        }
        return VStack(alignment: .leading, spacing: 12) {
            chartHeader("Mood trend", detail: summary.trend.description)
            if points.isEmpty {
                noDataText("No check-ins in this period.")
            } else {
                Chart {
                    ForEach(points) { point in
                        AreaMark(x: .value("Day", point.day, unit: .day),
                                 yStart: .value("Base", 1),
                                 yEnd: .value("Mood", point.value))
                            .foregroundStyle(LinearGradient(colors: [Theme.teal.opacity(0.25), Theme.teal.opacity(0.02)],
                                                            startPoint: .top, endPoint: .bottom))
                            .interpolationMethod(.catmullRom)
                        LineMark(x: .value("Day", point.day, unit: .day), y: .value("Mood", point.value))
                            .foregroundStyle(Theme.teal)
                            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                            .interpolationMethod(.catmullRom)
                        PointMark(x: .value("Day", point.day, unit: .day), y: .value("Mood", point.value))
                            .foregroundStyle(Theme.teal)
                            .symbolSize(40)
                            .accessibilityLabel(point.day.formatted(.dateTime.weekday(.wide).day().month()))
                            .accessibilityValue(String(format: "Average mood %.1f of 5", point.value))
                    }
                    if let selected {
                        RuleMark(x: .value("Selected", selected.day, unit: .day))
                            .foregroundStyle(Theme.inkSecondary.opacity(0.4))
                            .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                                VStack(spacing: 2) {
                                    Text(selected.day.formatted(.dateTime.weekday(.abbreviated).day()))
                                        .font(.caption2)
                                    Text(String(format: "%.1f · %@", selected.value,
                                                MoodSummaryCalculator.label(forScore: selected.value)))
                                        .font(.caption.bold())
                                }
                                .padding(6)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.surface).shadow(radius: 2))
                            }
                    }
                }
                .chartYScale(domain: 1...5)
                .chartYAxis {
                    AxisMarks(values: [1.0, 3.0, 5.0]) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let score = value.as(Double.self) {
                                Text(score == 1 ? "Heavy" : score == 3 ? "Balanced" : "Bright")
                            }
                        }
                    }
                }
                .chartXSelection(value: $selectedMoodDay)
                .frame(height: 220)
                .accessibilityIdentifier("insights.moodChart")
                Text("Touch and drag across the chart to see each day.")
                    .font(.bloomCaption)
                    .foregroundStyle(Theme.inkSecondary)
            }
        }
        .bloomCard()
    }

    // MARK: Emotion distribution

    private var emotionCard: some View {
        let counts = moodSummary.emotionCounts
        let rows = Emotion.allCases.filter { counts[$0, default: 0] > 0 }
        return VStack(alignment: .leading, spacing: 12) {
            chartHeader("Feelings you named",
                        detail: moodSummary.mostFrequentEmotion.map { "Most often: \($0.displayName)" } ?? "")
            if rows.isEmpty {
                noDataText("No check-ins in this period.")
            } else {
                Chart(rows) { emotion in
                    BarMark(x: .value("Check-ins", counts[emotion, default: 0]),
                            y: .value("Feeling", emotion.displayName))
                        .foregroundStyle(emotion.tint.gradient)
                        .cornerRadius(6)
                        .annotation(position: .trailing) {
                            Text("\(counts[emotion, default: 0])").font(.caption).foregroundStyle(Theme.inkSecondary)
                        }
                }
                .chartXAxis(.hidden)
                .frame(height: CGFloat(rows.count) * 34 + 10)
            }
        }
        .bloomCard()
    }

    // MARK: Focus & breathing

    private struct ActivityPoint: Identifiable {
        let day: Date
        let minutes: Double
        let activity: String
        var id: String { "\(activity)-\(day.timeIntervalSince1970)" }
    }

    private var calmFocusCard: some View {
        let focus = WellnessStats.minutesPerDay(focusSessions, lastDays: days, endingOn: now)
        let breathing = WellnessStats.minutesPerDay(breathingSessions, lastDays: days, endingOn: now)
        let points = focus.map { ActivityPoint(day: $0.day, minutes: $0.value, activity: "Focus") }
            + breathing.map { ActivityPoint(day: $0.day, minutes: $0.value, activity: "Breathing") }
        let total = points.reduce(0) { $0 + $1.minutes }
        return VStack(alignment: .leading, spacing: 12) {
            chartHeader("Focus & calm", detail: "Minutes per day")
            if total == 0 {
                noDataText("No focus or breathing sessions in this period.")
            } else {
                Chart(points) { point in
                    BarMark(x: .value("Day", point.day, unit: .day), y: .value("Minutes", point.minutes))
                        .foregroundStyle(by: .value("Activity", point.activity))
                        .position(by: .value("Activity", point.activity))
                        .cornerRadius(4)
                }
                .chartForegroundStyleScale(["Focus": Theme.sky, "Breathing": Theme.lavender])
                .chartLegend(position: .top, alignment: .leading)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: range == .week ? 1 : 7)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                    }
                }
                .frame(height: 200)
            }
        }
        .bloomCard()
    }

    // MARK: Habits

    private var dailyHabitRatios: [DailyValue] {
        HabitStreakCalculator.dailyCompletionRatio(completionDays: completions.map(\.day),
                                                   habitCount: habits.count, lastDays: days, endingOn: now)
    }

    private var averageHabitCompletion: Double {
        let ratios = dailyHabitRatios
        guard !ratios.isEmpty, !habits.isEmpty else { return 0 }
        return ratios.reduce(0) { $0 + $1.value } / Double(ratios.count)
    }

    private var habitCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            chartHeader("Self-care habits", detail: "Share of habits done each day")
            if habits.isEmpty {
                noDataText("Add habits in the Habits tab to see this chart.")
            } else {
                Chart(dailyHabitRatios) { point in
                    BarMark(x: .value("Day", point.day, unit: .day), y: .value("Done", point.value * 100))
                        .foregroundStyle(Theme.mint.gradient)
                        .cornerRadius(4)
                        .accessibilityValue("\(Int(point.value * 100)) percent")
                }
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(values: [0.0, 50.0, 100.0]) { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: range == .week ? 1 : 7)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                    }
                }
                .frame(height: 180)
            }
        }
        .bloomCard()
    }

    // MARK: Highlights (plain-language facts, no causal claims)

    private var highlights: [String] {
        var lines: [String] = []
        let summary = moodSummary
        if summary.checkInCount > 0 {
            lines.append("You checked in \(summary.checkInCount) times on \(summary.daysWithCheckIns) of the last \(days) days.")
        }
        if let top = summary.mostFrequentEmotion {
            lines.append("The feeling you named most was “\(top.displayName)” (\(summary.emotionCounts[top, default: 0]) times).")
        }
        let window = Calendar.current.interval(lastDays: days, endingOn: now)
        let heavy = moods.filter { window.containsHalfOpen($0.timestamp) && $0.emotion.valence < 0 }
        var factorCounts: [MoodFactor: Int] = [:]
        heavy.forEach { $0.factors.forEach { factorCounts[$0, default: 0] += 1 } }
        if let topFactor = factorCounts.max(by: { $0.value < $1.value }), topFactor.value >= 2 {
            lines.append("On heavier check-ins you most often tagged “\(topFactor.key.displayName)”. That's a pattern to notice, not a cause.")
        }
        let focusDays = WellnessStats.minutesPerDay(focusSessions, lastDays: days, endingOn: now)
        if let best = focusDays.max(by: { $0.value < $1.value }), best.value > 0 {
            lines.append("Your biggest focus day was \(best.day.formatted(.dateTime.weekday(.wide))) with \(Int(best.value)) minutes.")
        }
        if let bestHabit = habits.max(by: { lhs, rhs in
            HabitStreakCalculator.completionRate(completedDays: lhs.completedDays(), lastDays: days, endingOn: now)
            < HabitStreakCalculator.completionRate(completedDays: rhs.completedDays(), lastDays: days, endingOn: now)
        }) {
            let rate = HabitStreakCalculator.completionRate(completedDays: bestHabit.completedDays(), lastDays: days, endingOn: now)
            if rate > 0 {
                lines.append("Your most consistent habit was “\(bestHabit.name)” (\(Int((rate * 100).rounded()))% of days).")
            }
        }
        return lines
    }

    private var highlightsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            chartHeader("Highlights", detail: "Plain facts from your records")
            if highlights.isEmpty {
                noDataText("Highlights appear once you have a few records.")
            } else {
                ForEach(highlights, id: \.self) { line in
                    Label { Text(line).font(.bloomBody) } icon: {
                        Image(systemName: "sparkle").foregroundStyle(Theme.lavender)
                    }
                }
            }
        }
        .bloomCard(tint: Theme.lavender)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("insights.highlights")
    }

    // MARK: Helpers

    private func chartHeader(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.bloomHeadline).foregroundStyle(Theme.ink)
            if !detail.isEmpty {
                Text(detail).font(.bloomCaption).foregroundStyle(Theme.inkSecondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private func noDataText(_ text: String) -> some View {
        Text(text)
            .font(.bloomBody)
            .foregroundStyle(Theme.inkSecondary)
            .frame(maxWidth: .infinity, minHeight: 80)
    }
}
