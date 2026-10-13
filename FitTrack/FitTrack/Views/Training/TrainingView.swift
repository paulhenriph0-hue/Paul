import SwiftData
import SwiftUI

/// Trainingsbereich mit Workouts, Plänen und Übungsbibliothek.
struct TrainingView: View {
    enum Segment: String, CaseIterable, Identifiable {
        case workouts = "Workouts"
        case plans = "Pläne"
        case exercises = "Übungen"

        var id: Self { self }
    }

    @State private var segment: Segment = .workouts

    var body: some View {
        NavigationStack {
            Group {
                switch segment {
                case .workouts: WorkoutHomeView()
                case .plans: PlanListView()
                case .exercises: ExerciseLibraryView()
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                Picker("Bereich", selection: $segment) {
                    ForEach(Segment.allCases) { segment in
                        Text(segment.rawValue).tag(segment)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.bar)
            }
            .navigationTitle("Training")
        }
    }
}

/// Schnellstart und Trainingsverlauf.
struct WorkoutHomeView: View {
    @Environment(\.modelContext) private var context
    @Environment(WorkoutCoordinator.self) private var coordinator

    @Query(sort: \WorkoutSession.startDate, order: .reverse) private var sessions: [WorkoutSession]
    @Query(sort: \WorkoutPlan.createdAt) private var plans: [WorkoutPlan]

    private var activeSession: WorkoutSession? { sessions.first(where: \.isActive) }
    private var finished: [WorkoutSession] { sessions.filter { !$0.isActive } }

    var body: some View {
        List {
            if let activeSession {
                Section {
                    ActiveWorkoutBanner(session: activeSession) {
                        coordinator.resume(activeSession)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }

            Section("Schnellstart") {
                Button {
                    coordinator.startWorkout(plan: nil, in: context)
                } label: {
                    Label("Freies Training starten", systemImage: "play.circle.fill")
                        .font(.headline)
                }

                ForEach(plans) { plan in
                    Button {
                        coordinator.startWorkout(plan: plan, in: context)
                    } label: {
                        HStack {
                            Label(plan.name, systemImage: "list.bullet.clipboard")
                            Spacer()
                            Text("\(plan.entries.count) Übungen")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .disabled(activeSession != nil)

            Section("Verlauf") {
                if finished.isEmpty {
                    Text("Noch keine abgeschlossenen Trainings. Starte dein erstes Workout!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ForEach(finished) { session in
                    NavigationLink {
                        WorkoutDetailView(session: session)
                    } label: {
                        WorkoutRow(session: session)
                    }
                }
                .onDelete { offsets in
                    let items = offsets.map { finished[$0] }
                    items.forEach { context.delete($0) }
                    context.saveIfNeeded()
                }
            }
        }
    }
}

struct WorkoutRow: View {
    let session: WorkoutSession

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.name)
                    .font(.headline)
                Spacer()
                Text(session.startDate.formatted(.dateTime.day().month(.abbreviated).year()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                Label(Formatters.shortDuration(session.duration), systemImage: "timer")
                Label("\(session.completedSets.count) Sätze", systemImage: "checkmark.circle")
                Label("\(session.totalVolume.noDecimal) kg", systemImage: "scalemass")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    TrainingView()
        .environment(WorkoutCoordinator())
        .modelContainer(PreviewData.container)
}
