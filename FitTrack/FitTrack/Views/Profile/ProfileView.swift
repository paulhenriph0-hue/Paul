import SwiftData
import SwiftUI

/// Profil, Ziele und Datenverwaltung.
struct ProfileView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \UserProfile.createdAt) private var profiles: [UserProfile]

    var body: some View {
        NavigationStack {
            Group {
                if let profile = profiles.first {
                    ProfileForm(profile: profile)
                } else {
                    ProgressView()
                        .task {
                            SeedData.seedIfNeeded(in: context)
                        }
                }
            }
            .navigationTitle("Profil")
        }
    }
}

struct ProfileForm: View {
    @Bindable var profile: UserProfile

    @Environment(\.modelContext) private var context
    @Environment(WorkoutCoordinator.self) private var coordinator
    @Query(sort: \BodyWeightEntry.date, order: .reverse) private var weights: [BodyWeightEntry]

    @State private var showDemoConfirm = false
    @State private var showResetConfirm = false
    @State private var statusMessage: String?

    private var currentWeight: Double { weights.first?.weightKg ?? 75 }

    private var recommendedCalories: Int {
        FitnessMath.recommendedCalories(
            weightKg: currentWeight,
            heightCm: profile.heightCm,
            age: profile.age,
            sex: profile.sex,
            activity: profile.activityLevel,
            goal: profile.goal
        )
    }

    private var macroCalories: Int {
        profile.proteinGoal * 4 + profile.carbsGoal * 4 + profile.fatGoal * 9
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        Form {
            Section("Persönliche Daten") {
                TextField("Dein Name", text: $profile.name)
                Picker("Geschlecht", selection: $profile.sex) {
                    ForEach(BiologicalSex.allCases) { sex in
                        Text(sex.displayName).tag(sex)
                    }
                }
                Stepper("Geburtsjahr: \(String(profile.birthYear))", value: $profile.birthYear, in: 1930...2015)
                NumberInputRow(title: "Größe", value: $profile.heightCm, unit: "cm")
                LabeledContent("Aktuelles Gewicht", value: weights.isEmpty ? "–" : "\(currentWeight.oneDecimal) kg")
                if !weights.isEmpty && profile.heightCm > 0 {
                    LabeledContent("BMI", value: FitnessMath.bodyMassIndex(weightKg: currentWeight, heightCm: profile.heightCm).oneDecimal)
                }
            }

            Section("Ziele") {
                Picker("Ziel", selection: $profile.goal) {
                    ForEach(FitnessGoal.allCases) { goal in
                        Text(goal.displayName).tag(goal)
                    }
                }
                Picker("Aktivität", selection: $profile.activityLevel) {
                    ForEach(ActivityLevel.allCases) { level in
                        Text(level.displayName).tag(level)
                    }
                }
                NumberInputRow(title: "Zielgewicht", value: $profile.targetWeightKg, unit: "kg")
            }

            Section {
                IntegerInputRow(title: "Kalorien", value: $profile.calorieGoal, unit: "kcal")
                IntegerInputRow(title: "Protein", value: $profile.proteinGoal, unit: "g")
                IntegerInputRow(title: "Kohlenhydrate", value: $profile.carbsGoal, unit: "g")
                IntegerInputRow(title: "Fett", value: $profile.fatGoal, unit: "g")
                Button {
                    applyRecommendation()
                } label: {
                    Label("Empfehlung übernehmen (\(recommendedCalories) kcal)", systemImage: "wand.and.stars")
                }
            } header: {
                Text("Tägliche Ernährungsziele")
            } footer: {
                Text("Makros ergeben \(macroCalories) kcal. Die Empfehlung basiert auf der Mifflin-St.-Jeor-Formel, deinem Aktivitätslevel und Ziel sowie deinem aktuellen Gewicht (\(currentWeight.oneDecimal) kg).")
            }

            Section("Training") {
                Stepper("Wochenziel: \(profile.weeklyWorkoutGoal) Trainings", value: $profile.weeklyWorkoutGoal, in: 1...14)
                Stepper("Satzpause: \(Formatters.duration(TimeInterval(profile.defaultRestSeconds)))", value: $profile.defaultRestSeconds, in: 30...300, step: 15)
            }

            Section {
                Button {
                    showDemoConfirm = true
                } label: {
                    Label("Demo-Daten laden", systemImage: "sparkles")
                }
                Button(role: .destructive) {
                    showResetConfirm = true
                } label: {
                    Label("Alle Daten zurücksetzen", systemImage: "arrow.counterclockwise")
                }
            } header: {
                Text("Daten")
            } footer: {
                Text("Alle Daten werden ausschließlich lokal auf diesem iPhone gespeichert – ohne Benutzerkonto und ohne Cloud.")
            }

            Section("Info") {
                LabeledContent("Version", value: appVersion)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .onDisappear { context.saveIfNeeded() }
        .confirmationDialog("Demo-Daten laden?", isPresented: $showDemoConfirm, titleVisibility: .visible) {
            Button("Demo-Daten laden") {
                coordinator.presentedSession = nil
                SeedData.loadDemoData(in: context)
                statusMessage = "Demo-Daten für Gewicht, Training und Ernährung wurden erstellt."
            }
        } message: {
            Text("Vorhandene Trainings, Gewichts- und Ernährungseinträge werden durch Beispieldaten ersetzt.")
        }
        .confirmationDialog("Alle Daten zurücksetzen?", isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("Alles löschen", role: .destructive) {
                coordinator.presentedSession = nil
                SeedData.resetAllData(in: context)
                statusMessage = "Alle Daten wurden zurückgesetzt."
            }
        } message: {
            Text("Trainings, Pläne, eigene Übungen, Lebensmittel und Einträge werden gelöscht. Das kann nicht rückgängig gemacht werden.")
        }
        .alert("Fertig", isPresented: Binding(
            get: { statusMessage != nil },
            set: { if !$0 { statusMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(statusMessage ?? "")
        }
    }

    private func applyRecommendation() {
        let calories = recommendedCalories
        let macros = FitnessMath.recommendedMacros(calories: calories, weightKg: currentWeight, goal: profile.goal)
        profile.calorieGoal = calories
        profile.proteinGoal = macros.protein
        profile.carbsGoal = macros.carbs
        profile.fatGoal = macros.fat
        context.saveIfNeeded()
    }
}

#Preview {
    ProfileView()
        .environment(WorkoutCoordinator())
        .modelContainer(PreviewData.container)
}
