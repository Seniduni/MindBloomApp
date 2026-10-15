import SwiftUI
import SwiftData

struct JournalListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var entries: [JournalEntry]

    @State private var searchText = ""
    @State private var favoritesOnly = false
    @State private var showingNewEntry = false
    @State private var pendingDelete: JournalEntry?

    private var visibleEntries: [JournalEntry] {
        entries.filter { entry in
            (!favoritesOnly || entry.isFavorite) &&
            (searchText.isEmpty
             || entry.title.localizedCaseInsensitiveContains(searchText)
             || entry.body.localizedCaseInsensitiveContains(searchText))
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    ScrollView {
                        EmptyStateView(symbol: "book.pages",
                                       title: "Your journal is empty",
                                       message: "Writing a few lines can help untangle a busy day. Entries stay private on this device.",
                                       actionTitle: "Write your first entry") { showingNewEntry = true }
                            .padding(Theme.screenPadding)
                            .readableWidth()
                    }
                } else {
                    List {
                        Picker("Show", selection: $favoritesOnly) {
                            Text("All entries").tag(false)
                            Text("Favourites").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(Color.clear)
                        .accessibilityIdentifier("journal.filter")

                        ForEach(visibleEntries) { entry in
                            NavigationLink(value: entry) {
                                JournalRow(entry: entry)
                            }
                            .swipeActions(edge: .trailing) {
                                Button { pendingDelete = entry } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .tint(.red)
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    try? WellnessRepository(context: modelContext).toggleFavorite(entry)
                                } label: {
                                    Label(entry.isFavorite ? "Unfavourite" : "Favourite",
                                          systemImage: entry.isFavorite ? "star.slash" : "star")
                                }
                                .tint(Theme.sun)
                            }
                        }

                        if visibleEntries.isEmpty {
                            Text(searchText.isEmpty ? "No favourites yet. Swipe right on an entry to add one."
                                                    : "No entries match “\(searchText)”.")
                                .font(.bloomBody)
                                .foregroundStyle(Theme.inkSecondary)
                                .listRowBackground(Color.clear)
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .searchable(text: $searchText, prompt: "Search your entries")
                }
            }
            .bloomBackground()
            .navigationTitle("Journal")
            .navigationDestination(for: JournalEntry.self) { entry in
                JournalDetailView(entry: entry)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingNewEntry = true } label: {
                        Label("New entry", systemImage: "square.and.pencil")
                    }
                    .accessibilityIdentifier("journal.add")
                }
            }
            .sheet(isPresented: $showingNewEntry) {
                NavigationStack { JournalEditorView(entry: nil) }
            }
            .confirmationDialog("Delete this entry?",
                                isPresented: Binding(get: { pendingDelete != nil },
                                                     set: { if !$0 { pendingDelete = nil } }),
                                titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let entry = pendingDelete { try? WellnessRepository(context: modelContext).delete(entry) }
                    pendingDelete = nil
                }
            } message: {
                Text("This can't be undone.")
            }
        }
    }
}

struct JournalRow: View {
    let entry: JournalEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.title)
                    .font(.bloomHeadline)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                if entry.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundStyle(Theme.sun)
                        .imageScale(.small)
                        .accessibilityLabel("Favourite")
                }
            }
            Text(entry.preview)
                .font(.bloomBody)
                .foregroundStyle(Theme.inkSecondary)
                .lineLimit(2)
            Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.bloomCaption)
                .foregroundStyle(Theme.inkSecondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
