import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext

    @AppStorage(SettingsKey.appearance) private var appearance = AppearancePreference.system.rawValue
    @AppStorage(SettingsKey.hapticsEnabled) private var hapticsEnabled = true
    @AppStorage(SettingsKey.calmMotion) private var calmMotion = false
    @AppStorage(SettingsKey.journalInsightsEnabled) private var journalInsightsEnabled = true
    @AppStorage(SettingsKey.dailyReminderEnabled) private var reminderEnabled = false
    @AppStorage(SettingsKey.dailyReminderMinutes) private var reminderMinutes = 20 * 60
    @AppStorage(SettingsKey.hasCompletedOnboarding) private var hasCompletedOnboarding = true

    @Query private var moods: [MoodEntry]
    @Query private var journal: [JournalEntry]
    @Query private var habits: [Habit]
    @Query private var focusSessions: [FocusSession]
    @Query private var breathingSessions: [BreathingSession]

    @State private var exportURL: URL?
    @State private var confirmingDeleteAll = false
    @State private var confirmingLoadSamples = false
    @State private var message: String?

    private var hasSampleData: Bool {
        moods.contains { $0.isSample } || habits.contains { $0.isSample } || journal.contains { $0.isSample }
    }

    private var reminderTime: Binding<Date> {
        Binding {
            Calendar.current.date(bySettingHour: reminderMinutes / 60, minute: reminderMinutes % 60, second: 0, of: .now) ?? .now
        } set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            reminderMinutes = (parts.hour ?? 20) * 60 + (parts.minute ?? 0)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                appearanceSection
                experienceSection
                reminderSection
                dataSection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .bloomBackground()
            .navigationTitle("Settings")
            .alert("MIND BLOOM", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(message ?? "") }
        }
    }

    // MARK: Sections

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Theme", selection: $appearance) {
                ForEach(AppearancePreference.allCases) { Text($0.label).tag($0.rawValue) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("settings.appearance")
        }
    }

    private var experienceSection: some View {
        Section {
            Toggle("Haptic feedback", isOn: $hapticsEnabled)
                .accessibilityHint("Gentle vibrations during breathing exercises")
            Toggle("Calmer motion", isOn: $calmMotion)
                .accessibilityIdentifier("settings.calmMotion")
            Toggle("Journal reflection observations", isOn: $journalInsightsEnabled)
                .accessibilityIdentifier("settings.journalInsights")
        } header: {
            Text("Experience & accessibility")
        } footer: {
            Text("Calmer motion reduces animations in MIND BLOOM. Your system Reduce Motion setting is always respected too. Text sizes follow your Dynamic Type setting. Reflection observations run on this device only.")
        }
    }

    private var reminderSection: some View {
        Section {
            Toggle("Daily check-in reminder", isOn: $reminderEnabled)
                .onChange(of: reminderEnabled) { _, enabled in
                    Task { await updateReminder(enabled: enabled) }
                }
            if reminderEnabled {
                DatePicker("Time", selection: reminderTime, displayedComponents: .hourAndMinute)
                    .onChange(of: reminderMinutes) { _, _ in
                        Task { await updateReminder(enabled: true) }
                    }
            }
        } header: {
            Text("Reminders")
        } footer: {
            Text("A single, gentle local notification. No streak pressure, no server.")
        }
    }

    private var dataSection: some View {
        Section {
            LabeledContent("Mood check-ins", value: "\(moods.count)")
            LabeledContent("Journal entries", value: "\(journal.count)")
            LabeledContent("Habits", value: "\(habits.count)")
            LabeledContent("Focus & breathing sessions", value: "\(focusSessions.count + breathingSessions.count)")

            Button {
                if hasSampleData { confirmingLoadSamples = true } else { loadSamples() }
            } label: {
                Label("Load sample data", systemImage: "sparkles")
            }
            .accessibilityIdentifier("settings.loadSample")
            .confirmationDialog("Reload sample data?", isPresented: $confirmingLoadSamples, titleVisibility: .visible) {
                Button("Reload sample data") { loadSamples() }
            } message: {
                Text("Existing sample records will be replaced. Your own entries are not affected.")
            }

            Button {
                do {
                    try DemoDataService.removeSampleData(from: modelContext)
                    message = "Sample data removed. Your own entries were kept."
                } catch {
                    message = error.localizedDescription
                }
            } label: {
                Label("Remove sample data", systemImage: "wand.and.rays.inverse")
            }
            .disabled(!hasSampleData)
            .accessibilityIdentifier("settings.removeSample")

            if let exportURL {
                ShareLink(item: exportURL) {
                    Label("Share export file", systemImage: "square.and.arrow.up")
                }
            } else {
                Button {
                    do { exportURL = try DataExportService.writeExportFile(from: modelContext) }
                    catch { message = "Export failed: \(error.localizedDescription)" }
                } label: {
                    Label("Export my data (JSON)", systemImage: "doc.badge.arrow.up")
                }
            }

            Button(role: .destructive) {
                confirmingDeleteAll = true
            } label: {
                Label("Delete all my data", systemImage: "trash")
            }
            .accessibilityIdentifier("settings.deleteAll")
            .confirmationDialog("Delete everything?", isPresented: $confirmingDeleteAll, titleVisibility: .visible) {
                Button("Delete all data permanently", role: .destructive) { deleteAll() }
            } message: {
                Text("All check-ins, journal entries, habits and sessions will be permanently removed from this device.")
            }
        } header: {
            Text("Your data")
        } footer: {
            Text("Everything is stored on this device with SwiftData. Sample records are labelled internally, so removing them never touches your own entries.")
        }
    }

    private var aboutSection: some View {
        Section("About") {
            NavigationLink {
                PrivacyView()
            } label: {
                Label("Privacy & wellbeing", systemImage: "hand.raised")
            }
            Button {
                hasCompletedOnboarding = false
            } label: {
                Label("Show welcome screens again", systemImage: "arrow.counterclockwise")
            }
            .accessibilityIdentifier("settings.replayOnboarding")
            LabeledContent("Version", value: Bundle.main.appVersion)
            LabeledContent("Built with", value: "SwiftUI · SwiftData · Swift Charts · NaturalLanguage · Core Haptics")
                .font(.footnote)
        }
    }

    // MARK: Actions

    private func loadSamples() {
        do {
            try DemoDataService.loadSampleData(into: modelContext)
            message = "Two weeks of sample data loaded."
        } catch {
            message = error.localizedDescription
        }
    }

    private func deleteAll() {
        do {
            try WellnessRepository(context: modelContext).deleteAllData()
            UserDefaults.standard.removeObject(forKey: SettingsKey.focusTimerState)
            exportURL = nil
            message = "All data deleted."
        } catch {
            message = error.localizedDescription
        }
    }

    private func updateReminder(enabled: Bool) async {
        guard enabled else {
            ReminderService.cancelDailyCheckIn()
            return
        }
        if await ReminderService.requestAuthorization() {
            await ReminderService.scheduleDailyCheckIn(hour: reminderMinutes / 60, minute: reminderMinutes % 60)
        } else {
            reminderEnabled = false
            message = "Notifications are turned off for MIND BLOOM. You can allow them in the Settings app."
        }
    }
}

extension Bundle {
    var appVersion: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
