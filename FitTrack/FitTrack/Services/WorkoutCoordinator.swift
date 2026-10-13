import Foundation
import Observation
import SwiftData

/// Steuert das laufende Training: Starten, Fortsetzen und Anzeigen im Vollbild.
@Observable
final class WorkoutCoordinator {
    /// Die aktuell im Vollbild angezeigte Trainingseinheit.
    var presentedSession: WorkoutSession?

    /// Startet ein neues Training (leer oder aus einem Plan).
    /// Läuft bereits ein Training, wird stattdessen dieses geöffnet.
    func startWorkout(plan: WorkoutPlan?, in context: ModelContext) {
        if let active = Self.activeSession(in: context) {
            presentedSession = active
            return
        }

        let session = WorkoutSession(name: plan?.name ?? "Freies Training")
        context.insert(session)
        session.plan = plan

        if let plan {
            var index = 0
            for entry in plan.sortedEntries {
                guard let exercise = entry.exercise else { continue }
                let previous = exercise.previousSets(excluding: nil)
                for setNumber in 0..<max(entry.targetSets, 1) {
                    let previousWeight = previous.indices.contains(setNumber) ? previous[setNumber].weight : previous.last?.weight
                    let weight = entry.targetWeight > 0 ? entry.targetWeight : (previousWeight ?? 0)
                    let set = WorkoutSet(sortIndex: index, reps: entry.targetReps, weight: weight)
                    context.insert(set)
                    set.exercise = exercise
                    session.sets.append(set)
                    index += 1
                }
            }
        }

        // Sofort speichern, damit die Objekte stabile IDs erhalten.
        context.saveIfNeeded()
        presentedSession = session
    }

    func resume(_ session: WorkoutSession) {
        presentedSession = session
    }

    static func activeSession(in context: ModelContext) -> WorkoutSession? {
        var descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.endDate == nil },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}
