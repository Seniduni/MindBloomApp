import SwiftUI
import SwiftData

/// All check-ins, newest first, grouped by day. Swipe to delete.
struct MoodHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppNavigation.self) private var navigation
    @Query(sort: \MoodEntry.timestamp, order: .reverse) private var moods: [MoodEntry]

    @State private var filter: Emotion?

    private var filtered: [MoodEntry] {
        guard let filter else { return moods }
        return moods.filter { $0.emotion == filter }
    }

    private struct DayGroup: Identifiable {
        let day: Date
        let entries: [MoodEntry]
        var id: Date { day }
    }

    private var groupedDays: [DayGroup] {
        let groups = Dictionary(grouping: filtered) { Calendar.current.startOfDay(for: $0.timestamp) }
        return groups.keys.sorted(by: >).map { DayGroup(day: $0, entries: groups[$0] ?? []) }
    }

    var body: some View {
        Group {
            if moods.isEmpty {
                ScrollView {
                    EmptyStateView(symbol: "face.smiling", title: "No check-ins yet",
                                   message: "Your mood history will appear here.",
                                   actionTitle: "Check in now") { navigation.open(.moodCheckIn) }
                        .padding(Theme.screenPadding)
                }
            } else {
                List {
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ChipToggle(title: "All", isSelected: filter == nil) { filter = nil }
                                ForEach(Emotion.allCases) { emotion in
                                    ChipToggle(title: emotion.displayName, isSelected: filter == emotion,
                                               tint: emotion.tint) { filter = emotion }
                                }
                            }
                        }
                        .listRowBackground(Color.clear)
                    }
                    ForEach(groupedDays) { group in
                        Section(group.day.formatted(.dateTime.weekday(.wide).day().month())) {
                            ForEach(group.entries) { entry in
                                MoodRow(entry: entry)
                            }
                            .onDelete { offsets in
                                let repository = WellnessRepository(context: modelContext)
                                offsets.map { group.entries[$0] }.forEach { try? repository.delete($0) }
                            }
                        }
                    }
                    if filtered.isEmpty {
                        Text("No check-ins match this filter.")
                            .foregroundStyle(Theme.inkSecondary)
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .bloomBackground()
        .navigationTitle("Mood history")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    navigation.open(.moodCheckIn)
                } label: {
                    Label("New check-in", systemImage: "plus")
                }
            }
        }
    }
}

struct MoodRow: View {
    let entry: MoodEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: entry.emotion.symbolName)
                .foregroundStyle(entry.emotion.tint)
                .frame(width: 36, height: 36)
                .background(Circle().fill(entry.emotion.tint.opacity(0.15)))
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.emotion.displayName).font(.bloomHeadline)
                    Spacer()
                    Text(entry.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.bloomCaption).foregroundStyle(Theme.inkSecondary)
                }
                Text("Intensity \(entry.intensity)/5").font(.bloomCaption).foregroundStyle(Theme.inkSecondary)
                if !entry.factors.isEmpty {
                    Text(entry.factors.map(\.displayName).joined(separator: " · "))
                        .font(.bloomCaption).foregroundStyle(Theme.teal)
                }
                if !entry.note.isEmpty {
                    Text(entry.note).font(.bloomBody).foregroundStyle(Theme.ink)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
