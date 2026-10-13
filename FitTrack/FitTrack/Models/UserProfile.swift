import Foundation
import SwiftData

/// Lokales Benutzerprofil mit persönlichen Daten und Zielen. Es existiert genau ein Profil.
@Model
final class UserProfile {
    var name: String
    var birthYear: Int
    var sexRaw: String
    var heightCm: Double
    var activityRaw: String
    var goalRaw: String
    var calorieGoal: Int
    var proteinGoal: Int
    var carbsGoal: Int
    var fatGoal: Int
    var weeklyWorkoutGoal: Int
    /// Zielgewicht in kg, 0 = kein Ziel festgelegt.
    var targetWeightKg: Double
    var defaultRestSeconds: Int
    var createdAt: Date

    init(
        name: String = "",
        birthYear: Int = 1995,
        sex: BiologicalSex = .male,
        heightCm: Double = 178,
        activity: ActivityLevel = .moderate,
        goal: FitnessGoal = .maintain,
        calorieGoal: Int = 2400,
        proteinGoal: Int = 150,
        carbsGoal: Int = 270,
        fatGoal: Int = 80,
        weeklyWorkoutGoal: Int = 3,
        targetWeightKg: Double = 0,
        defaultRestSeconds: Int = 90
    ) {
        self.name = name
        self.birthYear = birthYear
        self.sexRaw = sex.rawValue
        self.heightCm = heightCm
        self.activityRaw = activity.rawValue
        self.goalRaw = goal.rawValue
        self.calorieGoal = calorieGoal
        self.proteinGoal = proteinGoal
        self.carbsGoal = carbsGoal
        self.fatGoal = fatGoal
        self.weeklyWorkoutGoal = weeklyWorkoutGoal
        self.targetWeightKg = targetWeightKg
        self.defaultRestSeconds = defaultRestSeconds
        self.createdAt = .now
    }

    var sex: BiologicalSex {
        get { BiologicalSex(rawValue: sexRaw) ?? .male }
        set { sexRaw = newValue.rawValue }
    }

    var activityLevel: ActivityLevel {
        get { ActivityLevel(rawValue: activityRaw) ?? .moderate }
        set { activityRaw = newValue.rawValue }
    }

    var goal: FitnessGoal {
        get { FitnessGoal(rawValue: goalRaw) ?? .maintain }
        set { goalRaw = newValue.rawValue }
    }

    var age: Int {
        max(Calendar.current.component(.year, from: .now) - birthYear, 0)
    }

    /// Setzt alle Werte auf die Standardwerte zurück.
    func resetToDefaults() {
        let defaults = UserProfile()
        name = defaults.name
        birthYear = defaults.birthYear
        sexRaw = defaults.sexRaw
        heightCm = defaults.heightCm
        activityRaw = defaults.activityRaw
        goalRaw = defaults.goalRaw
        calorieGoal = defaults.calorieGoal
        proteinGoal = defaults.proteinGoal
        carbsGoal = defaults.carbsGoal
        fatGoal = defaults.fatGoal
        weeklyWorkoutGoal = defaults.weeklyWorkoutGoal
        targetWeightKg = defaults.targetWeightKg
        defaultRestSeconds = defaults.defaultRestSeconds
    }
}

/// Tägliche Ernährungsziele als einfacher Wertetyp für Views.
struct NutritionGoals: Equatable {
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double

    init(calories: Double, protein: Double, carbs: Double, fat: Double) {
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
    }

    init(profile: UserProfile?) {
        calories = Double(profile?.calorieGoal ?? 2400)
        protein = Double(profile?.proteinGoal ?? 150)
        carbs = Double(profile?.carbsGoal ?? 270)
        fat = Double(profile?.fatGoal ?? 80)
    }
}
