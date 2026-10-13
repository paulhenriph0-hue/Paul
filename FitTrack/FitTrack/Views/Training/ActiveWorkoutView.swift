import SwiftData
import SwiftUI

/// Laufendes Training: Sätze erfassen, abhaken, Pausen-Timer, Übungen hinzufügen.
struct ActiveWorkoutView: View {
    @Bindable var session: WorkoutSession

    @Environment(\.modelContext) private var context
    @Environment(WorkoutCoordinator.self) private var coordinator
    @Query private var profiles: [UserProfile]

    @State private var showExercisePicker = false
    @State private var showFinishDialog = false
    @State private var showDiscardDialog = false
    @State private var restEndDate: Date?
    @State private var completionCount = 0

    private var restDuration: TimeInterval {
        TimeInterval(profiles.first?.defaultRestSeconds ?? 90)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    header
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                }

                ForEach(session.exerciseGroups) { group in
                    let previous = group.exercise.previousSets(excluding: session)
                    Section {
                        SetColumnHeader()
                        ForEach(Array(group.sets.enumerated()), id: \.element.persistentModelID) { index, set in
                            SetRow(
                                set: set,
                                number: index + 1,
                                previous: previous.indices.contains(index)
                                    ? Formatters.setDescription(weight: previous[index].weight, reps: previous[index].reps)
                                    : "–"
                            ) { completed in
                                if completed { startRestTimer() }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    delete(set)
                                } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                            }
                        }
                        Button {
                            addSet(to: group)
                        } label: {
                            Label("Satz hinzufügen", systemImage: "plus")
                                .font(.subheadline.weight(.semibold))
                        }
                    } header: {
                        HStack {
                            Text(group.exercise.name)
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .textCase(nil)
                            Spacer()
                            Text(group.exercise.muscleGroup.displayName)
                                .font(.caption)
                                .textCase(nil)
                        }
                    }
                }

                Section {
                    Button {
                        showExercisePicker = true
                    } label: {
                        Label("Übung hinzufügen", systemImage: "plus.circle.fill")
                            .font(.headline)
                    }
                    Button(role: .destructive) {
                        showDiscardDialog = true
                    } label: {
                        Label("Training verwerfen", systemImage: "trash")
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Training")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        hideKeyboard()
                        context.saveIfNeeded()
                        coordinator.presentedSession = nil
                    } label: {
                        Image(systemName: "chevron.down")
                            .fontWeight(.semibold)
                    }
                    .accessibilityLabel("Minimieren")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Beenden") {
                        hideKeyboard()
                        showFinishDialog = true
                    }
                    .fontWeight(.semibold)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Fertig") { hideKeyboard() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let restEndDate {
                    RestTimerBar(
                        endDate: restEndDate,
                        onAdjust: { self.restEndDate = restEndDate.addingTimeInterval($0) },
                        onSkip: { self.restEndDate = nil }
                    )
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.3), value: restEndDate)
            .sheet(isPresented: $showExercisePicker) {
                ExercisePickerView { exercise in
                    addExercise(exercise)
                }
            }
            .confirmationDialog("Training beenden?", isPresented: $showFinishDialog, titleVisibility: .visible) {
                Button("Training speichern") { finish() }
                Button("Weiter trainieren", role: .cancel) {}
            } message: {
                Text(finishMessage)
            }
            .confirmationDialog("Training verwerfen?", isPresented: $showDiscardDialog, titleVisibility: .visible) {
                Button("Verwerfen", role: .destructive) { discard() }
            } message: {
                Text("Alle Sätze dieses Trainings werden gelöscht.")
            }
            .sensoryFeedback(.success, trigger: completionCount)
        }
    }

    // MARK: - Kopfbereich

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Name des Trainings", text: $session.name)
                .font(.title2.weight(.bold))
            HStack(spacing: 10) {
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    StatTile(
                        title: "Dauer",
                        value: Formatters.duration(timeline.date.timeIntervalSince(session.startDate)),
                        symbol: "timer",
                        color: Theme.training
                    )
                }
                StatTile(title: "Volumen", value: session.totalVolume.noDecimal, unit: "kg", symbol: "scalemass.fill", color: Theme.accent)
                StatTile(
                    title: "Sätze",
                    value: "\(session.completedSets.count)/\(session.sets.count)",
                    symbol: "checkmark.circle.fill",
                    color: Theme.protein
                )
            }
        }
    }

    private var finishMessage: String {
        let open = session.sets.filter { !$0.isCompleted }.count
        if session.completedSets.isEmpty {
            return "Es wurde noch kein Satz abgehakt – das Training wird nicht gespeichert."
        }
        if open > 0 {
            return "\(open) nicht abgehakte Sätze werden verworfen."
        }
        return "Super Training! Alle Sätze sind erledigt."
    }

    // MARK: - Aktionen

    private func startRestTimer() {
        completionCount += 1
        restEndDate = Date().addingTimeInterval(restDuration)
    }

    private func addSet(to group: ExerciseGroup) {
        let last = group.sets.last
        let set = WorkoutSet(sortIndex: session.nextSortIndex, reps: last?.reps ?? 10, weight: last?.weight ?? 0)
        context.insert(set)
        set.exercise = group.exercise
        session.sets.append(set)
        context.saveIfNeeded()
    }

    private func addExercise(_ exercise: Exercise) {
        let previous = exercise.previousSets(excluding: session)
        let count = previous.isEmpty ? 3 : min(previous.count, 6)
        var index = session.nextSortIndex
        for setNumber in 0..<count {
            let template = previous.indices.contains(setNumber) ? previous[setNumber] : nil
            let set = WorkoutSet(sortIndex: index, reps: template?.reps ?? 10, weight: template?.weight ?? 0)
            context.insert(set)
            set.exercise = exercise
            session.sets.append(set)
            index += 1
        }
        context.saveIfNeeded()
    }

    private func delete(_ set: WorkoutSet) {
        context.delete(set)
        context.saveIfNeeded()
    }

    private func finish() {
        let open = session.sets.filter { !$0.isCompleted }
        guard open.count < session.sets.count else {
            discard()
            return
        }
        open.forEach { context.delete($0) }
        session.endDate = .now
        context.saveIfNeeded()
        coordinator.presentedSession = nil
    }

    private func discard() {
        let sessionToDelete = session
        coordinator.presentedSession = nil
        // Erst nach dem Schließen löschen, damit keine View mehr auf das Objekt zugreift.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            context.delete(sessionToDelete)
            context.saveIfNeeded()
        }
    }
}

// MARK: - Satz-Zeilen

struct SetColumnHeader: View {
    var body: some View {
        HStack(spacing: 10) {
            Text("Satz").frame(width: 30, alignment: .leading)
            Text("Vorher").frame(width: 72, alignment: .leading)
            Text("kg").frame(maxWidth: .infinity)
            Text("Wdh.").frame(maxWidth: .infinity)
            Image(systemName: "checkmark").frame(width: 32)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
    }
}

struct SetRow: View {
    @Bindable var set: WorkoutSet
    let number: Int
    let previous: String
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text("\(number)")
                .font(.subheadline.weight(.bold))
                .frame(width: 26, height: 26)
                .background(Circle().fill(set.isCompleted ? Theme.accent : Theme.fieldBackground))
                .foregroundStyle(set.isCompleted ? Color.white : Color.primary)
                .frame(width: 30, alignment: .leading)

            Text(previous)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 72, alignment: .leading)

            DecimalField("0", value: $set.weight)
                .fieldBox()
                .frame(maxWidth: .infinity)

            IntegerField("0", value: $set.reps)
                .fieldBox()
                .frame(maxWidth: .infinity)

            Button {
                hideKeyboard()
                set.isCompleted.toggle()
                set.completedAt = set.isCompleted ? .now : nil
                onToggle(set.isCompleted)
            } label: {
                Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(set.isCompleted ? Theme.accent : Color.secondary)
            }
            .buttonStyle(.borderless)
            .frame(width: 32)
            .accessibilityLabel(set.isCompleted ? "Satz als offen markieren" : "Satz abhaken")
        }
        .listRowBackground(set.isCompleted ? Theme.accent.opacity(0.10) : Theme.card)
    }
}

/// Pausen-Timer am unteren Bildschirmrand.
struct RestTimerBar: View {
    let endDate: Date
    let onAdjust: (TimeInterval) -> Void
    let onSkip: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { timeline in
            let remaining = max(0, endDate.timeIntervalSince(timeline.date))
            HStack(spacing: 12) {
                Image(systemName: remaining > 0 ? "hourglass" : "bell.and.waves.left.and.right.fill")
                    .font(.title3)
                    .foregroundStyle(remaining > 0 ? Theme.training : Theme.accent)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 0) {
                    Text(remaining > 0 ? "Satzpause" : "Pause vorbei – weiter geht's!")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(Formatters.duration(remaining.rounded(.up)))
                        .font(.title3.weight(.bold).monospacedDigit())
                }
                Spacer()
                Button("−15") { onAdjust(-15) }
                    .buttonStyle(.bordered)
                Button("+15") { onAdjust(15) }
                    .buttonStyle(.bordered)
                Button(action: onSkip) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Pause beenden")
            }
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
            .padding(.horizontal)
        }
    }
}
