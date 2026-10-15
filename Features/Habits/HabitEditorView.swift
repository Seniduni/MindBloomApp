import SwiftUI
import SwiftData

/// Create or edit a habit. Validation (empty, too long, duplicate) comes from `InputValidator`.
struct HabitEditorView: View {
    let habit: Habit?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var symbol: String
    @State private var tint: HabitTint
    @State private var errorMessage: String?

    init(habit: Habit?) {
        self.habit = habit
        _name = State(initialValue: habit?.name ?? "")
        _symbol = State(initialValue: habit?.symbolName ?? HabitSymbols.options[0])
        _tint = State(initialValue: habit?.tint ?? .teal)
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Image(systemName: symbol)
                        .font(.title2)
                        .foregroundStyle(tint.color)
                        .frame(width: 52, height: 52)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(tint.color.opacity(0.15)))
                        .accessibilityHidden(true)
                    TextField("Habit name", text: $name)
                        .font(.bloomHeadline)
                        .accessibilityIdentifier("habit.name")
                }
                Text("\(name.count)/\(InputValidator.maxHabitNameLength)")
                    .font(.bloomCaption)
                    .foregroundStyle(name.count > InputValidator.maxHabitNameLength ? Theme.peach : Theme.inkSecondary)
            } footer: {
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(Theme.peach)
                        .accessibilityIdentifier("habit.error")
                }
            }

            Section("Icon") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 48), spacing: 10)], spacing: 10) {
                    ForEach(HabitSymbols.options, id: \.self) { option in
                        Button { symbol = option } label: {
                            Image(systemName: option)
                                .font(.title3)
                                .frame(width: 48, height: 48)
                                .foregroundStyle(symbol == option ? Theme.onAccent : Theme.ink)
                                .background(Circle().fill(symbol == option ? tint.color : Theme.surfaceSunken))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(option.replacingOccurrences(of: ".", with: " "))
                        .accessibilityAddTraits(symbol == option ? [.isButton, .isSelected] : .isButton)
                    }
                }
                .padding(.vertical, 6)
            }

            Section("Colour") {
                HStack(spacing: 12) {
                    ForEach(HabitTint.allCases) { option in
                        Button { tint = option } label: {
                            Circle()
                                .fill(option.color)
                                .frame(width: 36, height: 36)
                                .overlay {
                                    if tint == option {
                                        Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(Theme.onAccent)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(option.name)
                        .accessibilityAddTraits(tint == option ? [.isButton, .isSelected] : .isButton)
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .navigationTitle(habit == nil ? "New habit" : "Edit habit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .accessibilityIdentifier("habit.save")
            }
        }
    }

    private func save() {
        let repository = WellnessRepository(context: modelContext)
        do {
            if let habit {
                try repository.updateHabit(habit, name: name, symbolName: symbol, tint: tint)
            } else {
                try repository.addHabit(name: name, symbolName: symbol, tint: tint)
            }
            dismiss()
        } catch {
            withAnimation { errorMessage = error.localizedDescription }
        }
    }
}
