import SwiftUI
import SwiftData

/// Mood check-in: choose a feeling, rate its intensity, optionally add context and a note.
struct MoodCheckInView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.bloomReduceMotion) private var reduceMotion

    @State private var selectedEmotion: Emotion?
    @State private var intensity = 3
    @State private var factors: Set<MoodFactor> = []
    @State private var note = ""
    @State private var savedCount = 0
    @State private var errorMessage: String?
    @FocusState private var noteFocused: Bool

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12),
                           GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SectionHeader(title: "How are you feeling?",
                              subtitle: "Pick the word that fits best right now. There are no wrong answers.")

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Emotion.allCases) { emotion in
                        EmotionTile(emotion: emotion, isSelected: selectedEmotion == emotion) {
                            withAnimation(reduceMotion ? nil : .spring(duration: 0.35)) {
                                selectedEmotion = emotion
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("How strong is it?").font(.bloomHeadline).foregroundStyle(Theme.ink)
                    IntensityPicker(value: $intensity, tint: selectedEmotion?.tint ?? Theme.teal)
                }
                .bloomCard()

                VStack(alignment: .leading, spacing: 10) {
                    Text("What's influencing it? (optional)").font(.bloomHeadline).foregroundStyle(Theme.ink)
                    FlowLayout(spacing: 8) {
                        ForEach(MoodFactor.allCases) { factor in
                            ChipToggle(title: factor.displayName, symbol: factor.symbolName,
                                       isSelected: factors.contains(factor)) {
                                if factors.contains(factor) { factors.remove(factor) } else { factors.insert(factor) }
                            }
                        }
                    }
                }
                .bloomCard()

                VStack(alignment: .leading, spacing: 8) {
                    Text("A note for yourself (optional)").font(.bloomHeadline).foregroundStyle(Theme.ink)
                    TextField("What's on your mind?", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                        .focused($noteFocused)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surfaceSunken))
                        .accessibilityIdentifier("mood.note")
                        .onChange(of: note) { _, newValue in
                            if newValue.count > InputValidator.maxNoteLength {
                                note = String(newValue.prefix(InputValidator.maxNoteLength))
                            }
                        }
                    Text("\(note.count)/\(InputValidator.maxNoteLength)")
                        .font(.bloomCaption)
                        .foregroundStyle(Theme.inkSecondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .accessibilityLabel("\(note.count) of \(InputValidator.maxNoteLength) characters used")
                }
                .bloomCard()

                Button("Save check-in", action: save)
                    .buttonStyle(.bloomPrimary)
                    .disabled(selectedEmotion == nil)
                    .accessibilityIdentifier("mood.save")
                    .accessibilityHint(selectedEmotion == nil ? "Choose a feeling first" : "")
            }
            .padding(Theme.screenPadding)
            .readableWidth()
        }
        .scrollDismissesKeyboard(.interactively)
        .bloomBackground()
        .navigationTitle("Check in")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .keyboard) {
                Button("Done") { noteFocused = false }
            }
        }
        .sensoryFeedback(.success, trigger: savedCount)
        .sensoryFeedback(.selection, trigger: selectedEmotion)
        .alert("Couldn't save", isPresented: Binding(get: { errorMessage != nil },
                                                    set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
    }

    private func save() {
        guard let emotion = selectedEmotion else { return }
        do {
            try WellnessRepository(context: modelContext)
                .addMood(emotion: emotion, intensity: intensity, note: note,
                         factors: MoodFactor.allCases.filter { factors.contains($0) })
            savedCount += 1
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// One selectable feeling in the 3×3 grid.
struct EmotionTile: View {
    let emotion: Emotion
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: emotion.symbolName)
                    .font(.title2)
                    .foregroundStyle(isSelected ? Theme.onAccent : emotion.tint)
                    .symbolEffect(.bounce, value: isSelected)
                Text(emotion.displayName)
                    .font(.bloomCaption)
                    .foregroundStyle(isSelected ? Theme.onAccent : Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 84)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(emotion.tint.gradient) : AnyShapeStyle(Theme.surface))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(isSelected ? .clear : Theme.hairline, lineWidth: 1)
            }
            .scaleEffect(isSelected ? 1.04 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(emotion.displayName)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("emotion.\(emotion.rawValue)")
    }
}

/// Five dots that grow in size; tap a dot or drag across them to set intensity.
/// VoiceOver users swipe up/down to adjust (an "adjustable" element).
struct IntensityPicker: View {
    @Binding var value: Int
    var tint: Color

    private let labels = ["Barely", "Mild", "Moderate", "Strong", "Very strong"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { proxy in
                HStack(spacing: 0) {
                    ForEach(1...5, id: \.self) { level in
                        Circle()
                            .fill(level <= value ? AnyShapeStyle(tint.gradient) : AnyShapeStyle(Theme.surfaceSunken))
                            .frame(width: 14 + CGFloat(level) * 6, height: 14 + CGFloat(level) * 6)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: proxy.size.height)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            let slot = Int(drag.location.x / max(proxy.size.width, 1) * 5) + 1
                            let newValue = InputValidator.clampIntensity(slot)
                            if newValue != value { value = newValue }
                        }
                )
            }
            .frame(height: 50)
            Text(labels[value - 1])
                .font(.bloomCaption)
                .foregroundStyle(Theme.inkSecondary)
        }
        .sensoryFeedback(.selection, trigger: value)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Intensity")
        .accessibilityValue("\(value) of 5, \(labels[value - 1])")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = InputValidator.clampIntensity(value + 1)
            case .decrement: value = InputValidator.clampIntensity(value - 1)
            @unknown default: break
            }
        }
        .accessibilityIdentifier("mood.intensity")
    }
}
