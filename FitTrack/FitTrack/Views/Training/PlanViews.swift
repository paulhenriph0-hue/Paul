import SwiftData
import SwiftUI

/// Liste aller Trainingspläne.
struct PlanListView: View {
    @Environment(\.modelContext) private var context
    @Environment(WorkoutCoordinator.self) private var coordinator
    @Query(sort: \WorkoutPlan.createdAt) private var plans: [WorkoutPlan]
    @State private var newPlan: WorkoutPlan?

    var body: some View {
        List {
            if plans.isEmpty {
                ContentUnavailableView(
                    "Keine Trainingspläne",
                    systemImage: "list.bullet.clipboard",
                    description: Text("Erstelle einen Plan mit deinen Lieblingsübungen.")
                )
            }
            ForEach(plans) { plan in
                NavigationLink {
                    PlanEditorView(plan: plan)
                } label: {
                    PlanRow(plan: plan)
                }
                .swipeActions(edge: .leading) {
                    Button {
                        coordinator.startWorkout(plan: plan, in: context)
                    } label: {
                        Label("Starten", systemImage: "play.fill")
                    }
                    .tint(Theme.accent)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        context.delete(plan)
                        context.saveIfNeeded()
                    } label: {
                        Label("Löschen", systemImage: "trash")
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    createPlan()
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Neuer Plan")
            }
        }
        .navigationDestination(item: $newPlan) { plan in
            PlanEditorView(plan: plan)
        }
    }

    private func createPlan() {
        let plan = WorkoutPlan(name: "Neuer Plan")
        context.insert(plan)
        context.saveIfNeeded()
        newPlan = plan
    }
}

struct PlanRow: View {
    let plan: WorkoutPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(plan.name)
                .font(.headline)
            Text(plan.sortedEntries.compactMap { $0.exercise?.name }.joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Text("\(plan.entries.count) Übungen · \(plan.entries.reduce(0) { $0 + $1.targetSets }) Sätze")
                .font(.caption2.weight(.medium))
                .foregroundStyle(Theme.training)
        }
        .padding(.vertical, 2)
    }
}

/// Plan bearbeiten: Name, Übungen, Zielsätze/-wiederholungen/-gewicht, Reihenfolge.
struct PlanEditorView: View {
    @Bindable var plan: WorkoutPlan
    @Environment(\.modelContext) private var context
    @Environment(WorkoutCoordinator.self) private var coordinator
    @State private var showExercisePicker = false

    var body: some View {
        Form {
            Section("Allgemein") {
                TextField("Name", text: $plan.name)
                    .font(.headline)
                TextField("Notizen", text: $plan.notes, axis: .vertical)
                    .lineLimit(1...4)
            }

            Section {
                ForEach(plan.sortedEntries) { entry in
                    PlanEntryRow(entry: entry)
                }
                .onDelete(perform: deleteEntries)
                .onMove(perform: moveEntries)

                Button {
                    showExercisePicker = true
                } label: {
                    Label("Übung hinzufügen", systemImage: "plus.circle.fill")
                }
            } header: {
                Text("Übungen")
            } footer: {
                Text("Gewicht 0 bedeutet: Das zuletzt verwendete Gewicht wird übernommen. Über „Bearbeiten“ kannst du die Reihenfolge ändern.")
            }

            Section {
                Button {
                    coordinator.startWorkout(plan: plan, in: context)
                } label: {
                    Label("Training mit diesem Plan starten", systemImage: "play.fill")
                        .font(.headline)
                }
                .disabled(plan.entries.isEmpty)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(plan.name.isEmpty ? "Plan" : plan.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Fertig") { hideKeyboard() }
            }
        }
        .sheet(isPresented: $showExercisePicker) {
            ExercisePickerView { exercise in
                addExercise(exercise)
            }
        }
        .onDisappear { context.saveIfNeeded() }
    }

    private func addExercise(_ exercise: Exercise) {
        let nextIndex = (plan.entries.map(\.sortIndex).max() ?? -1) + 1
        let entry = PlanExercise(sortIndex: nextIndex)
        context.insert(entry)
        entry.exercise = exercise
        plan.entries.append(entry)
        context.saveIfNeeded()
    }

    private func deleteEntries(at offsets: IndexSet) {
        let sorted = plan.sortedEntries
        for index in offsets {
            context.delete(sorted[index])
        }
        context.saveIfNeeded()
    }

    private func moveEntries(from source: IndexSet, to destination: Int) {
        var sorted = plan.sortedEntries
        sorted.move(fromOffsets: source, toOffset: destination)
        for (index, entry) in sorted.enumerated() {
            entry.sortIndex = index
        }
        context.saveIfNeeded()
    }
}

struct PlanEntryRow: View {
    @Bindable var entry: PlanExercise

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: entry.exercise?.muscleGroup.symbol ?? "dumbbell")
                    .foregroundStyle(Theme.training)
                Text(entry.exercise?.name ?? "Unbekannte Übung")
                    .font(.headline)
            }
            Stepper("\(entry.targetSets) Sätze", value: $entry.targetSets, in: 1...10)
            Stepper("\(entry.targetReps) Wiederholungen", value: $entry.targetReps, in: 1...50)
            HStack {
                Text("Zielgewicht")
                Spacer()
                DecimalField("0", value: $entry.targetWeight, alignment: .trailing)
                    .frame(width: 80)
                    .fieldBox()
                Text("kg")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
