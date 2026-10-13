import Foundation
import SwiftData

/// Ein Trainingsplan als Vorlage, z. B. „Push“ oder „Ganzkörper A“.
@Model
final class WorkoutPlan {
    var name: String
    var notes: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \PlanExercise.plan)
    var entries: [PlanExercise] = []

    @Relationship(deleteRule: .nullify, inverse: \WorkoutSession.plan)
    var sessions: [WorkoutSession] = []

    init(name: String, notes: String = "") {
        self.name = name
        self.notes = notes
        self.createdAt = .now
    }

    var sortedEntries: [PlanExercise] {
        entries.sorted { $0.sortIndex < $1.sortIndex }
    }
}

/// Eine Übung innerhalb eines Trainingsplans mit Zielvorgaben.
@Model
final class PlanExercise {
    var sortIndex: Int
    var targetSets: Int
    var targetReps: Int
    /// Zielgewicht in kg, 0 = letztes Gewicht übernehmen.
    var targetWeight: Double
    var exercise: Exercise?
    var plan: WorkoutPlan?

    init(sortIndex: Int, targetSets: Int = 3, targetReps: Int = 10, targetWeight: Double = 0) {
        self.sortIndex = sortIndex
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.targetWeight = targetWeight
    }
}

/// Eine konkrete Trainingseinheit. `endDate == nil` bedeutet: Training läuft gerade.
@Model
final class WorkoutSession {
    var name: String
    var startDate: Date
    var endDate: Date?
    var notes: String
    var plan: WorkoutPlan?

    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.session)
    var sets: [WorkoutSet] = []

    init(name: String, startDate: Date = .now, endDate: Date? = nil, notes: String = "") {
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
    }

    var isActive: Bool { endDate == nil }

    var duration: TimeInterval {
        (endDate ?? .now).timeIntervalSince(startDate)
    }

    var completedSets: [WorkoutSet] {
        sets.filter(\.isCompleted)
    }

    /// Trainingsvolumen (Gewicht × Wiederholungen) aller abgeschlossenen Sätze.
    var totalVolume: Double {
        completedSets.reduce(0) { $0 + $1.volume }
    }

    var nextSortIndex: Int {
        (sets.map(\.sortIndex).max() ?? -1) + 1
    }

    /// Sätze nach Übung gruppiert – in der Reihenfolge, in der die Übungen hinzugefügt wurden.
    var exerciseGroups: [ExerciseGroup] {
        var order: [PersistentIdentifier] = []
        var groups: [PersistentIdentifier: (exercise: Exercise, sets: [WorkoutSet])] = [:]
        for set in sets.sorted(by: { $0.sortIndex < $1.sortIndex }) {
            guard let exercise = set.exercise else { continue }
            let id = exercise.persistentModelID
            if groups[id] == nil {
                order.append(id)
                groups[id] = (exercise, [])
            }
            groups[id]?.sets.append(set)
        }
        return order.compactMap { id in
            groups[id].map { ExerciseGroup(exercise: $0.exercise, sets: $0.sets) }
        }
    }
}

/// Ein einzelner Satz (Gewicht × Wiederholungen) innerhalb einer Trainingseinheit.
@Model
final class WorkoutSet {
    var sortIndex: Int
    var reps: Int
    var weight: Double
    var isCompleted: Bool
    var completedAt: Date?
    var exercise: Exercise?
    var session: WorkoutSession?

    init(sortIndex: Int, reps: Int, weight: Double, isCompleted: Bool = false, completedAt: Date? = nil) {
        self.sortIndex = sortIndex
        self.reps = reps
        self.weight = weight
        self.isCompleted = isCompleted
        self.completedAt = completedAt
    }

    var volume: Double { Double(reps) * weight }

    var estimatedOneRepMax: Double {
        FitnessMath.estimatedOneRepMax(weight: weight, reps: reps)
    }
}

/// Hilfstyp für die Darstellung: alle Sätze einer Übung innerhalb einer Einheit.
struct ExerciseGroup: Identifiable {
    let exercise: Exercise
    let sets: [WorkoutSet]

    var id: PersistentIdentifier { exercise.persistentModelID }
}
