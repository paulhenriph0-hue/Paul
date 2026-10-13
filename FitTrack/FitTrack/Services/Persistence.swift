import Foundation
import SwiftData

/// Erstellt den lokalen SwiftData-Speicher. Alle Daten bleiben auf dem Gerät – kein Konto, keine Cloud.
enum PersistenceController {
    static let models: [any PersistentModel.Type] = [
        UserProfile.self,
        Exercise.self,
        WorkoutPlan.self,
        PlanExercise.self,
        WorkoutSession.self,
        WorkoutSet.self,
        FoodItem.self,
        FoodEntry.self,
        BodyWeightEntry.self
    ]

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(models)
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}

extension ModelContext {
    /// Speichert, falls es Änderungen gibt. Fehler werden protokolliert.
    func saveIfNeeded() {
        guard hasChanges else { return }
        do {
            try save()
        } catch {
            print("FitTrack: Speichern fehlgeschlagen – \(error)")
        }
    }

    /// Löscht alle Objekte eines Typs einzeln (berücksichtigt Löschregeln der Beziehungen).
    func deleteAll<T: PersistentModel>(_ type: T.Type) {
        let items = (try? fetch(FetchDescriptor<T>())) ?? []
        for item in items {
            delete(item)
        }
    }
}

/// In-Memory-Container mit Beispieldaten für SwiftUI-Previews.
@MainActor
enum PreviewData {
    static let container: ModelContainer = {
        do {
            let container = try PersistenceController.makeContainer(inMemory: true)
            let context = container.mainContext
            SeedData.seedIfNeeded(in: context)
            SeedData.loadDemoData(in: context)
            return container
        } catch {
            fatalError("Preview-Container konnte nicht erstellt werden: \(error)")
        }
    }()
}
