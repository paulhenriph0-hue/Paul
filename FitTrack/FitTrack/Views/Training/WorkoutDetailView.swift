import SwiftData
import SwiftUI

/// Detailansicht eines abgeschlossenen Trainings.
struct WorkoutDetailView: View {
    @Bindable var session: WorkoutSession
    @Environment(\.modelContext) private var context
    @State private var savedPlanName: String?

    var body: some View {
        List {
            Section {
                HStack(spacing: 10) {
                    StatTile(title: "Dauer", value: Formatters.shortDuration(session.duration), symbol: "timer", color: Theme.training)
                    StatTile(title: "Volumen", value: session.totalVolume.noDecimal, unit: "kg", symbol: "scalemass.fill", color: Theme.accent)
                    StatTile(title: "Sätze", value: "\(session.completedSets.count)", symbol: "checkmark.circle.fill", color: Theme.protein)
                }
                .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))

                LabeledContent("Datum", value: session.startDate.formatted(date: .complete, time: .shortened))
                if let plan = session.plan {
                    LabeledContent("Plan", value: plan.name)
                }
            }

            ForEach(session.exerciseGroups) { group in
                Section {
                    ForEach(Array(group.sets.enumerated()), id: \.element.persistentModelID) { index, set in
                        HStack {
                            Text("\(index + 1)")
                                .font(.subheadline.weight(.bold))
                                .frame(width: 24, height: 24)
                                .background(Circle().fill(Theme.accent.opacity(0.15)))
                            Text(Formatters.setDescription(weight: set.weight, reps: set.reps))
                                .monospacedDigit()
                            Spacer()
                            if set.estimatedOneRepMax > 0 {
                                Text("1RM ≈ \(set.estimatedOneRepMax.oneDecimal) kg")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text(group.exercise.name)
                }
            }

            Section("Notizen") {
                TextField("Wie lief das Training?", text: $session.notes, axis: .vertical)
                    .lineLimit(2...6)
            }

            Section {
                Button {
                    saveAsPlan()
                } label: {
                    Label("Als Trainingsplan speichern", systemImage: "square.and.arrow.down")
                }
            }
        }
        .navigationTitle(session.name)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Plan gespeichert", isPresented: Binding(
            get: { savedPlanName != nil },
            set: { if !$0 { savedPlanName = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("„\(savedPlanName ?? "")“ findest du jetzt unter Pläne.")
        }
        .onDisappear { context.saveIfNeeded() }
    }

    private func saveAsPlan() {
        let plan = WorkoutPlan(name: session.name, notes: "Erstellt aus dem Training vom \(session.startDate.formatted(date: .abbreviated, time: .omitted))")
        context.insert(plan)
        for (index, group) in session.exerciseGroups.enumerated() {
            let entry = PlanExercise(
                sortIndex: index,
                targetSets: group.sets.count,
                targetReps: group.sets.first?.reps ?? 10,
                targetWeight: group.sets.map(\.weight).max() ?? 0
            )
            context.insert(entry)
            entry.exercise = group.exercise
            plan.entries.append(entry)
        }
        context.saveIfNeeded()
        savedPlanName = plan.name
    }
}
