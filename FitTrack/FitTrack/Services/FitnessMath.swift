import Foundation

/// Summe aus Kalorien und Makronährstoffen.
struct MacroTotals: Hashable {
    var calories: Double = 0
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0

    static let zero = MacroTotals()

    static func + (lhs: MacroTotals, rhs: MacroTotals) -> MacroTotals {
        MacroTotals(
            calories: lhs.calories + rhs.calories,
            protein: lhs.protein + rhs.protein,
            carbs: lhs.carbs + rhs.carbs,
            fat: lhs.fat + rhs.fat
        )
    }

    static func += (lhs: inout MacroTotals, rhs: MacroTotals) {
        lhs = lhs + rhs
    }

    /// Rechnet Werte pro 100 g auf eine beliebige Menge um.
    func scaled(toGrams grams: Double) -> MacroTotals {
        let factor = max(grams, 0) / 100
        return MacroTotals(
            calories: calories * factor,
            protein: protein * factor,
            carbs: carbs * factor,
            fat: fat * factor
        )
    }

    /// Kalorien, die sich aus den Makros ergeben (4/4/9 kcal pro Gramm).
    var caloriesFromMacros: Double {
        protein * 4 + carbs * 4 + fat * 9
    }
}

extension Sequence where Element == FoodEntry {
    var totals: MacroTotals {
        reduce(.zero) { $0 + $1.macros }
    }
}

/// Fitness-Berechnungen (1RM, Grundumsatz, Empfehlungen).
enum FitnessMath {
    /// Geschätztes Einwiederholungsmaximum nach der Epley-Formel.
    static func estimatedOneRepMax(weight: Double, reps: Int) -> Double {
        guard weight > 0, reps > 0 else { return 0 }
        if reps == 1 { return weight }
        return weight * (1 + Double(reps) / 30)
    }

    /// Grundumsatz nach Mifflin-St Jeor in kcal.
    static func basalMetabolicRate(weightKg: Double, heightCm: Double, age: Int, sex: BiologicalSex) -> Double {
        let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(age)
        return base + (sex == .male ? 5 : -161)
    }

    /// Empfohlene Tageskalorien, auf 10 kcal gerundet.
    static func recommendedCalories(
        weightKg: Double,
        heightCm: Double,
        age: Int,
        sex: BiologicalSex,
        activity: ActivityLevel,
        goal: FitnessGoal
    ) -> Int {
        let bmr = basalMetabolicRate(weightKg: weightKg, heightCm: heightCm, age: age, sex: sex)
        let total = bmr * activity.factor + goal.calorieAdjustment
        return Int((max(total, 1200) / 10).rounded()) * 10
    }

    /// Makroverteilung: Protein nach Körpergewicht, 25 % Fett, Rest Kohlenhydrate.
    static func recommendedMacros(calories: Int, weightKg: Double, goal: FitnessGoal) -> (protein: Int, carbs: Int, fat: Int) {
        let protein = (weightKg * goal.proteinPerKg).rounded()
        let fat = (Double(calories) * 0.25 / 9).rounded()
        let carbs = max((Double(calories) - protein * 4 - fat * 9) / 4, 0).rounded()
        return (Int(protein), Int(carbs), Int(fat))
    }

    static func bodyMassIndex(weightKg: Double, heightCm: Double) -> Double {
        guard heightCm > 0 else { return 0 }
        let meters = heightCm / 100
        return weightKg / (meters * meters)
    }

    /// Rundet ein Gewicht auf die nächste verfügbare Scheibenabstufung (Standard 2,5 kg).
    static func roundToPlate(_ weight: Double, step: Double = 2.5) -> Double {
        (weight / step).rounded() * step
    }
}
