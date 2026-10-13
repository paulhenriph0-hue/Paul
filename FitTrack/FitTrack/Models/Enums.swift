import SwiftUI

/// Muskelgruppen zur Kategorisierung von Übungen.
enum MuscleGroup: String, CaseIterable, Identifiable, Codable {
    case chest, back, shoulders, biceps, triceps, legs, glutes, core, fullBody

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chest: "Brust"
        case .back: "Rücken"
        case .shoulders: "Schultern"
        case .biceps: "Bizeps"
        case .triceps: "Trizeps"
        case .legs: "Beine"
        case .glutes: "Gesäß"
        case .core: "Rumpf"
        case .fullBody: "Ganzkörper"
        }
    }

    var symbol: String {
        switch self {
        case .chest: "figure.strengthtraining.traditional"
        case .back: "figure.rower"
        case .shoulders: "figure.arms.open"
        case .biceps: "dumbbell.fill"
        case .triceps: "dumbbell"
        case .legs: "figure.step.training"
        case .glutes: "figure.cross.training"
        case .core: "figure.core.training"
        case .fullBody: "figure.mixed.cardio"
        }
    }
}

/// Mahlzeiten eines Tages.
enum MealType: String, CaseIterable, Identifiable, Codable {
    case breakfast, lunch, dinner, snack

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .breakfast: "Frühstück"
        case .lunch: "Mittagessen"
        case .dinner: "Abendessen"
        case .snack: "Snacks"
        }
    }

    var symbol: String {
        switch self {
        case .breakfast: "sunrise.fill"
        case .lunch: "sun.max.fill"
        case .dinner: "moon.stars.fill"
        case .snack: "carrot.fill"
        }
    }

    var color: Color {
        switch self {
        case .breakfast: .orange
        case .lunch: .yellow
        case .dinner: .indigo
        case .snack: .green
        }
    }

    /// Schlägt anhand der Uhrzeit eine passende Mahlzeit vor.
    static func suggested(for date: Date = .now) -> MealType {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case ..<11: return .breakfast
        case 11..<15: return .lunch
        case 15..<18: return .snack
        default: return .dinner
        }
    }
}

enum BiologicalSex: String, CaseIterable, Identifiable, Codable {
    case male, female

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .male: "Männlich"
        case .female: "Weiblich"
        }
    }
}

enum ActivityLevel: String, CaseIterable, Identifiable, Codable {
    case sedentary, light, moderate, active, veryActive

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sedentary: "Kaum aktiv"
        case .light: "Leicht aktiv"
        case .moderate: "Mäßig aktiv"
        case .active: "Sehr aktiv"
        case .veryActive: "Extrem aktiv"
        }
    }

    /// PAL-Faktor zur Berechnung des Gesamtumsatzes.
    var factor: Double {
        switch self {
        case .sedentary: 1.2
        case .light: 1.375
        case .moderate: 1.55
        case .active: 1.725
        case .veryActive: 1.9
        }
    }
}

enum FitnessGoal: String, CaseIterable, Identifiable, Codable {
    case lose, maintain, gain

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .lose: "Abnehmen"
        case .maintain: "Gewicht halten"
        case .gain: "Muskelaufbau"
        }
    }

    var calorieAdjustment: Double {
        switch self {
        case .lose: -500
        case .maintain: 0
        case .gain: 300
        }
    }

    /// Empfohlene Proteinmenge in Gramm pro kg Körpergewicht.
    var proteinPerKg: Double {
        switch self {
        case .lose: 2.0
        case .maintain: 1.6
        case .gain: 1.8
        }
    }
}
