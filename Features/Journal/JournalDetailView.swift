import SwiftUI
import SwiftData

struct JournalDetailView: View {
    let entry: JournalEntry

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.journalInsightsEnabled) private var insightsEnabled = true

    @State private var editing = false
    @State private var confirmingDelete = false

    var body: some View {
        // After deletion the model can no longer be read safely, so show a placeholder
        // for the brief moment before the navigation stack pops.
        if entry.isDeleted || entry.modelContext == nil {
            ContentUnavailableView("Entry deleted", systemImage: "trash")
        } else {
            content
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(entry.createdAt.formatted(.dateTime.weekday(.wide).day().month(.wide).hour().minute()))
                    .font(.bloomCaption)
                    .foregroundStyle(Theme.inkSecondary)
                Text(entry.title)
                    .font(.bloomDisplay)
                    .foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(.isHeader)
                if !entry.prompt.isEmpty {
                    Label(entry.prompt, systemImage: "quote.opening")
                        .font(.bloomBody.italic())
                        .foregroundStyle(Theme.lavender)
                }
                Text(entry.body)
                    .font(.bloomBody)
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(5)
                    .textSelection(.enabled)
                if entry.updatedAt.timeIntervalSince(entry.createdAt) > 60 {
                    Text("Edited \(entry.updatedAt.formatted(.relative(presentation: .named)))")
                        .font(.bloomCaption)
                        .foregroundStyle(Theme.inkSecondary)
                }

                if insightsEnabled {
                    ReflectionInsightCard(text: entry.body)
                } else {
                    Label("On-device reflection observations are turned off in Settings.", systemImage: "eye.slash")
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSecondary)
                }
            }
            .padding(Theme.screenPadding)
            .readableWidth()
        }
        .bloomBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    try? WellnessRepository(context: modelContext).toggleFavorite(entry)
                } label: {
                    Label(entry.isFavorite ? "Remove favourite" : "Favourite",
                          systemImage: entry.isFavorite ? "star.fill" : "star")
                }
                Menu {
                    Button { editing = true } label: { Label("Edit", systemImage: "pencil") }
                    Button(role: .destructive) { confirmingDelete = true } label: { Label("Delete", systemImage: "trash") }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
                .accessibilityIdentifier("journal.more")
            }
        }
        .sheet(isPresented: $editing) {
            NavigationStack { JournalEditorView(entry: entry) }
        }
        .confirmationDialog("Delete this entry?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                try? WellnessRepository(context: modelContext).delete(entry)
                dismiss()
            }
        } message: { Text("This can't be undone.") }
    }
}
