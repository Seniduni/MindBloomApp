import SwiftUI
import SwiftData

/// Habit & self-care tracker. Choose a day in the week strip, then tap habits to
/// mark them done for that day (today or earlier — never the future).
struct HabitsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.bloomReduceMotion) private var reduceMotion
    @Query(sort: \Habit.sortOrder) private var habits: [Habit]

    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    @State private var editorTarget: EditorTarget?
    @State private var pendingDelete: Habit?
    @State private var toggleCount = 0
    @State private var errorMessage: String?

    enum EditorTarget: Identifiable {
        case new
        case edit(Habit)
        var id: String {
            switch self {
            case .new: "new"
            case .edit(let habit): habit.id.uuidString
            }
        }
    }

    private var week: [Date] { Calendar.current.lastDays(7, endingOn: .now) }

    private var completedOnSelectedDay: Int {
        habits.filter { $0.isCompleted(on: selectedDay) }.count
    }

    struct Suggestion: Identifiable {
        let name: String
        let symbol: String
        let tint: HabitTint
        var id: String { name }
    }

    static let suggestions: [Suggestion] = [
        Suggestion(name: "Drink water", symbol: "drop.fill", tint: .teal),
        Suggestion(name: "Short walk outside", symbol: "figure.walk", tint: .mint),
        Suggestion(name: "Lights out on time", symbol: "bed.double.fill", tint: .lavender),
        Suggestion(name: "Read for fun", symbol: "book.fill", tint: .sky),
        Suggestion(name: "Eat a proper lunch", symbol: "fork.knife", tint: .sun),
        Suggestion(name: "Message a friend", symbol: "person.2.fill", tint: .peach)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    weekStrip
                    if habits.isEmpty {
                        emptyState
                    } else {
                        dayProgress
                        VStack(spacing: 12) {
                            ForEach(habits) { habit in
                                HabitRow(habit: habit, day: selectedDay, week: week) {
                                    toggle(habit)
                                }
                                .contextMenu {
                                    Button { editorTarget = .edit(habit) } label: { Label("Edit", systemImage: "pencil") }
                                    Button(role: .destructive) { pendingDelete = habit } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        Text("Tip: touch and hold a habit to edit or delete it.")
                            .font(.footnote)
                            .foregroundStyle(Theme.inkSecondary)
                    }
                }
                .padding(Theme.screenPadding)
                .readableWidth()
            }
            .bloomBackground()
            .navigationTitle("Habits")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { editorTarget = .new } label: { Label("Add habit", systemImage: "plus") }
                        .accessibilityIdentifier("habits.add")
                }
            }
            .sheet(item: $editorTarget) { target in
                NavigationStack {
                    switch target {
                    case .new: HabitEditorView(habit: nil)
                    case .edit(let habit): HabitEditorView(habit: habit)
                    }
                }
                .presentationDetents([.large])
            }
            .confirmationDialog("Delete this habit?",
                                isPresented: Binding(get: { pendingDelete != nil },
                                                     set: { if !$0 { pendingDelete = nil } }),
                                titleVisibility: .visible) {
                Button("Delete habit and history", role: .destructive) {
                    if let habit = pendingDelete { try? WellnessRepository(context: modelContext).delete(habit) }
                    pendingDelete = nil
                }
            } message: {
                Text("Its completion history will be removed too.")
            }
            .sensoryFeedback(.selection, trigger: toggleCount)
            .alert("Something went wrong", isPresented: Binding(get: { errorMessage != nil },
                                                                 set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(errorMessage ?? "") }
        }
    }

    // MARK: Sections

    private var weekStrip: some View {
        HStack(spacing: 6) {
            ForEach(week, id: \.self) { day in
                let isSelected = Calendar.current.isDate(day, inSameDayAs: selectedDay)
                Button {
                    withAnimation(reduceMotion ? nil : .snappy) { selectedDay = day }
                } label: {
                    VStack(spacing: 4) {
                        Text(day.formatted(.dateTime.weekday(.narrow)))
                            .font(.bloomCaption)
                        Text(day.formatted(.dateTime.day()))
                            .font(.system(.headline, design: .rounded).monospacedDigit())
                    }
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .foregroundStyle(isSelected ? Theme.onAccent : Theme.ink)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isSelected ? AnyShapeStyle(Theme.bloomGradient) : AnyShapeStyle(Theme.surface)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(day.formatted(.dateTime.weekday(.wide).day().month()))
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
    }

    private var dayProgress: some View {
        let fraction = habits.isEmpty ? 0 : Double(completedOnSelectedDay) / Double(habits.count)
        return HStack(spacing: 16) {
            ProgressRing(progress: fraction, lineWidth: 10) {
                Text("\(Int((fraction * 100).rounded()))%")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold).monospacedDigit())
            }
            .frame(width: 72, height: 72)
            VStack(alignment: .leading, spacing: 4) {
                Text(Calendar.current.isDateInToday(selectedDay) ? "Today"
                     : selectedDay.formatted(.dateTime.weekday(.wide).day().month()))
                    .font(.bloomHeadline)
                    .foregroundStyle(Theme.ink)
                Text("\(completedOnSelectedDay) of \(habits.count) habits done")
                    .font(.bloomBody)
                    .foregroundStyle(Theme.inkSecondary)
            }
        }
        .bloomCard()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("habits.progress")
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            EmptyStateView(symbol: "leaf", title: "No habits yet",
                           message: "Start with one or two small things you'd like to do most days.",
                           actionTitle: "Create a habit") { editorTarget = .new }
            Text("Or add a suggestion").font(.bloomHeadline).foregroundStyle(Theme.ink)
            FlowLayout(spacing: 8) {
                ForEach(Self.suggestions) { suggestion in
                    ChipToggle(title: suggestion.name, symbol: suggestion.symbol, isSelected: false,
                               tint: suggestion.tint.color) {
                        addSuggestion(suggestion)
                    }
                }
            }
        }
    }

    // MARK: Actions

    private func toggle(_ habit: Habit) {
        do {
            try WellnessRepository(context: modelContext).toggleHabit(habit, on: selectedDay)
            toggleCount += 1
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func addSuggestion(_ suggestion: Suggestion) {
        do {
            try WellnessRepository(context: modelContext)
                .addHabit(name: suggestion.name, symbolName: suggestion.symbol, tint: suggestion.tint)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// One habit: icon, name, streak, the last 7 days as dots, and a big check button.
struct HabitRow: View {
    let habit: Habit
    let day: Date
    let week: [Date]
    let onToggle: () -> Void

    var body: some View {
        let done = habit.isCompleted(on: day)
        let completed = habit.completedDays()
        let streak = habit.currentStreak()
        HStack(spacing: 14) {
            Image(systemName: habit.symbolName)
                .font(.title3)
                .foregroundStyle(habit.tint.color)
                .frame(width: 46, height: 46)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(habit.tint.color.opacity(0.15)))
            VStack(alignment: .leading, spacing: 6) {
                Text(habit.name).font(.bloomHeadline).foregroundStyle(Theme.ink)
                HStack(spacing: 5) {
                    ForEach(week, id: \.self) { weekDay in
                        Circle()
                            .fill(completed.contains(weekDay) ? habit.tint.color : Theme.surfaceSunken)
                            .frame(width: 8, height: 8)
                    }
                    if streak > 0 {
                        Text("\(streak)-day streak")
                            .font(.bloomCaption)
                            .foregroundStyle(Theme.inkSecondary)
                            .padding(.leading, 4)
                    }
                }
            }
            Spacer(minLength: 8)
            Button(action: onToggle) {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 30))
                    .foregroundStyle(done ? habit.tint.color : Theme.hairline)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(done ? "Mark \(habit.name) not done" : "Mark \(habit.name) done")
            .accessibilityIdentifier("habit.toggle.\(habit.name)")
        }
        .bloomCard(padding: 14)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(habit.name), \(done ? "done" : "not done"), \(streak) day streak")
    }
}
