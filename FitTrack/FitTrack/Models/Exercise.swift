import Foundation
import SwiftData

/// Eine Übung aus der Übungsbibliothek (z. B. „Bankdrücken“).
@Model
final class Exercise {
    var name: String
    var muscleGroupRaw: String
    var notes: String
    var isCustom: Bool
    var createdAt: Date

    /// Alle jemals absolvierten Sätze dieser Übung.
    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.exercise)
    var sets: [WorkoutSet] = []

    /// Einträge in Trainingsplänen, die diese Übung verwenden.
    @Relationship(deleteRule: .cascade, inverse: \PlanExercise.exercise)
    var planEntries: [PlanExercise] = []

    init(name: String, muscleGroup: MuscleGroup, notes: String = "", isCustom: Bool = false) {
        self.name = name
        self.muscleGroupRaw = muscleGroup.rawValue
        self.notes = notes
        self.isCustom = isCustom
        self.createdAt = .now
    }

    var muscleGroup: MuscleGroup {
        get { MuscleGroup(rawValue: muscleGroupRaw) ?? .fullBody }
        set { muscleGroupRaw = newValue.rawValue }
    }

    var completedSets: [WorkoutSet] {
        sets.filter { $0.isCompleted && $0.session?.endDate != nil }
    }

    /// Die Sätze des letzten abgeschlossenen Trainings mit dieser Übung (für „Vorher“-Werte).
    func previousSets(excluding session: WorkoutSession?) -> [WorkoutSet] {
        let excludedID = session?.persistentModelID
        let candidates = sets.filter { set in
            guard set.isCompleted, let owner = set.session, owner.endDate != nil else { return false }
            return owner.persistentModelID != excludedID
        }
        guard let latest = candidates.compactMap(\.session).max(by: { $0.startDate < $1.startDate }) else {
            return []
        }
        let latestID = latest.persistentModelID
        return candidates
            .filter { $0.session?.persistentModelID == latestID }
            .sorted { $0.sortIndex < $1.sortIndex }
    }

    var bestEstimatedOneRepMax: Double {
        completedSets.map(\.estimatedOneRepMax).max() ?? 0
    }

    var heaviestWeight: Double {
        completedSets.map(\.weight).max() ?? 0
    }
}
