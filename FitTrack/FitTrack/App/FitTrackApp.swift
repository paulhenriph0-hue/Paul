import SwiftData
import SwiftUI

@main
struct FitTrackApp: App {
    private let container: ModelContainer

    init() {
        do {
            container = try PersistenceController.makeContainer()
        } catch {
            fatalError("Der lokale Datenspeicher konnte nicht geöffnet werden: \(error)")
        }
        // Beim ersten Start Profil, Übungen, Lebensmittel und Pläne anlegen.
        SeedData.seedIfNeeded(in: ModelContext(container))
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .preferredColorScheme(.light)
                .tint(Theme.accent)
        }
        .modelContainer(container)
    }
}
