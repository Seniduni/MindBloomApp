import SwiftUI
import SwiftData

/// Create or edit a journal entry. Protects against losing unsaved writing.
struct JournalEditorView: View {
    let entry: JournalEntry?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var bodyText: String
    @State private var prompt: String
    @State private var errorMessage: String?
    @State private var confirmingDiscard = false
    @FocusState private var focusedField: Field?

    private enum Field { case title, body }

    static let prompts = [
        "What is taking up space in your mind?",
        "What went well today, however small?",
        "What would make tomorrow a little easier?",
        "Name three small things you are grateful for.",
        "What drained your energy, and what restored it?",
        "What do you need to hear right now?"
    ]

    init(entry: JournalEntry?) {
        self.entry = entry
        _title = State(initialValue: entry?.title ?? "")
        _bodyText = State(initialValue: entry?.body ?? "")
        _prompt = State(initialValue: entry?.prompt ?? "")
    }

    private var hasChanges: Bool {
        title != (entry?.title ?? "") || bodyText != (entry?.body ?? "") || prompt != (entry?.prompt ?? "")
    }

    private var wordCount: Int {
        bodyText.split { $0.isWhitespace || $0.isNewline }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TextField("Title (optional)", text: $title)
                    .font(.bloomTitle)
                    .focused($focusedField, equals: .title)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .body }
                    .accessibilityIdentifier("journal.title")

                if entry == nil || !prompt.isEmpty {
                    promptPicker
                }

                ZStack(alignment: .topLeading) {
                    if bodyText.isEmpty {
                        Text("Start writing…")
                            .font(.bloomBody)
                            .foregroundStyle(Theme.inkSecondary)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .accessibilityHidden(true)
                    }
                    TextEditor(text: $bodyText)
                        .font(.bloomBody)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 260)
                        .focused($focusedField, equals: .body)
                        .accessibilityLabel("Entry text")
                        .accessibilityIdentifier("journal.body")
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.surface))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.hairline))

                HStack {
                    Label("Stored only on this device", systemImage: "lock.fill")
                    Spacer()
                    Text("\(wordCount) words")
                }
                .font(.bloomCaption)
                .foregroundStyle(Theme.inkSecondary)
            }
            .padding(Theme.screenPadding)
            .readableWidth()
        }
        .bloomBackground()
        .navigationTitle(entry == nil ? "New entry" : "Edit entry")
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(hasChanges)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    if hasChanges { confirmingDiscard = true } else { dismiss() }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("journal.save")
            }
        }
        .confirmationDialog("Discard your changes?", isPresented: $confirmingDiscard, titleVisibility: .visible) {
            Button("Discard", role: .destructive) { dismiss() }
            Button("Keep writing", role: .cancel) {}
        }
        .alert("Couldn't save", isPresented: Binding(get: { errorMessage != nil },
                                                    set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
        .onAppear { if entry == nil { focusedField = .body } }
    }

    private var promptPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !prompt.isEmpty {
                HStack(alignment: .top) {
                    Image(systemName: "quote.opening").foregroundStyle(Theme.lavender)
                    Text(prompt).font(.bloomBody.italic()).foregroundStyle(Theme.ink)
                    Spacer()
                    Button { prompt = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .foregroundStyle(Theme.inkSecondary)
                        .accessibilityLabel("Remove prompt")
                }
                .bloomCard(padding: 12, tint: Theme.lavender)
            } else {
                Text("Need a starting point?").font(.bloomCaption).foregroundStyle(Theme.inkSecondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Self.prompts, id: \.self) { item in
                            ChipToggle(title: item, isSelected: false, tint: Theme.lavender) { prompt = item }
                        }
                    }
                }
            }
        }
    }

    private func save() {
        do {
            try WellnessRepository(context: modelContext)
                .saveJournal(existing: entry, title: title, body: bodyText, prompt: prompt)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
