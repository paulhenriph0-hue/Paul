import SwiftData
import SwiftUI

enum AppTab: Hashable {
    case dashboard, training, nutrition, progress, profile
}

struct RootTabView: View {
    @State private var selection: AppTab = .dashboard
    @State private var coordinator = WorkoutCoordinator()

    var body: some View {
        TabView(selection: $selection) {
            DashboardView(selectedTab: $selection)
                .tabItem { Label("Übersicht", systemImage: "square.grid.2x2.fill") }
                .tag(AppTab.dashboard)

            TrainingView()
                .tabItem { Label("Training", systemImage: "dumbbell.fill") }
                .tag(AppTab.training)

            NutritionView()
                .tabItem { Label("Ernährung", systemImage: "fork.knife") }
                .tag(AppTab.nutrition)

            AnalyticsView()
                .tabItem { Label("Fortschritt", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(AppTab.progress)

            ProfileView()
                .tabItem { Label("Profil", systemImage: "person.crop.circle.fill") }
                .tag(AppTab.profile)
        }
        .environment(coordinator)
        .fullScreenCover(item: $coordinator.presentedSession) { session in
            ActiveWorkoutView(session: session)
                .environment(coordinator)
        }
    }
}

#Preview {
    RootTabView()
        .modelContainer(PreviewData.container)
}
