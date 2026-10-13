import Foundation
import SwiftData

/// Ein Lebensmittel aus der Datenbank. Nährwerte immer pro 100 g.
@Model
final class FoodItem {
    var name: String
    var brand: String
    var caloriesPer100g: Double
    var proteinPer100g: Double
    var carbsPer100g: Double
    var fatPer100g: Double
    /// Typische Portionsgröße in Gramm.
    var servingGrams: Double
    var isFavorite: Bool
    var isCustom: Bool
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \FoodEntry.food)
    var entries: [FoodEntry] = []

    init(
        name: String,
        brand: String = "",
        caloriesPer100g: Double,
        proteinPer100g: Double,
        carbsPer100g: Double,
        fatPer100g: Double,
        servingGrams: Double = 100,
        isFavorite: Bool = false,
        isCustom: Bool = false
    ) {
        self.name = name
        self.brand = brand
        self.caloriesPer100g = caloriesPer100g
        self.proteinPer100g = proteinPer100g
        self.carbsPer100g = carbsPer100g
        self.fatPer100g = fatPer100g
        self.servingGrams = servingGrams
        self.isFavorite = isFavorite
        self.isCustom = isCustom
        self.createdAt = .now
    }

    var per100g: MacroTotals {
        MacroTotals(calories: caloriesPer100g, protein: proteinPer100g, carbs: carbsPer100g, fat: fatPer100g)
    }

    func macros(forGrams grams: Double) -> MacroTotals {
        per100g.scaled(toGrams: grams)
    }
}

/// Ein Eintrag im Ernährungstagebuch. Die Nährwerte werden beim Erfassen kopiert,
/// damit der Verlauf erhalten bleibt, auch wenn das Lebensmittel später geändert oder gelöscht wird.
@Model
final class FoodEntry {
    var date: Date
    var mealRaw: String
    var name: String
    var grams: Double
    var caloriesPer100g: Double
    var proteinPer100g: Double
    var carbsPer100g: Double
    var fatPer100g: Double
    /// Schnelleintrag ohne Lebensmittel: Werte gelten für die gesamte Portion (grams = 100).
    var isQuickAdd: Bool
    var food: FoodItem?

    init(
        date: Date,
        meal: MealType,
        name: String,
        grams: Double,
        per100g: MacroTotals,
        isQuickAdd: Bool = false
    ) {
        self.date = date
        self.mealRaw = meal.rawValue
        self.name = name
        self.grams = grams
        self.caloriesPer100g = per100g.calories
        self.proteinPer100g = per100g.protein
        self.carbsPer100g = per100g.carbs
        self.fatPer100g = per100g.fat
        self.isQuickAdd = isQuickAdd
    }

    /// Erstellt einen Eintrag aus einem Lebensmittel. Die Beziehung `food` wird
    /// nach dem Einfügen in den Kontext gesetzt.
    convenience init(food: FoodItem, grams: Double, meal: MealType, date: Date) {
        self.init(date: date, meal: meal, name: food.name, grams: grams, per100g: food.per100g)
    }

    /// Erstellt einen Schnelleintrag mit Gesamtwerten.
    convenience init(quickAddName name: String, totals: MacroTotals, meal: MealType, date: Date) {
        self.init(date: date, meal: meal, name: name, grams: 100, per100g: totals, isQuickAdd: true)
    }

    var meal: MealType {
        get { MealType(rawValue: mealRaw) ?? .snack }
        set { mealRaw = newValue.rawValue }
    }

    var macros: MacroTotals {
        MacroTotals(calories: caloriesPer100g, protein: proteinPer100g, carbs: carbsPer100g, fat: fatPer100g)
            .scaled(toGrams: grams)
    }
}

/// Ein Körpergewichtseintrag.
@Model
final class BodyWeightEntry {
    var date: Date
    var weightKg: Double
    var note: String

    init(date: Date = .now, weightKg: Double, note: String = "") {
        self.date = date
        self.weightKg = weightKg
        self.note = note
    }
}
