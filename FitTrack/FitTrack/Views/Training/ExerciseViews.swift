import Charts
import SwiftData
import SwiftUI

/// Übungsbibliothek, gruppiert nach Muskelgruppen.
struct ExerciseLibraryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var searchText = ""
    @State private var showNewExercise = false

    private var filtered: [Exercise] {
        guard !searchText.isEmpty else { return exercises }
        return exercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        List {
            ForEach(MuscleGroup.allCases) { group in
                let items = filtered.filter { $0.muscleGroup == group }
                if !items.isEmpty {
                    Section(group.displayName) {
                        ForEach(items) { exercise in
                            NavigationLink {
                                ExerciseDetailView(exercise: exercise)
                            } label: {
                                ExerciseRow(exercise: exercise)
                            }
                            .swipeActions(edge: .trailing) {
                                if exercise.isCustom {
                                    Button(role: .destructive) {
                                        context.delete(exercise)
                                        context.saveIfNeeded()
                                    } label: {
                                        Label("Löschen", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .overlay {
            if filtered.isEmpty && !searchText.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .searchable(text: $searchText, prompt: "Übung suchen")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showNewExercise = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Neue Übung")
            }
        }
        .sheet(isPresented: $showNewExercise) {
            NavigationStack {
                ExerciseEditorView(exercise: nil)
            }
        }
    }
}

struct ExerciseRow: View {
    let exercise: Exercise

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: exercise.muscleGroup.symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.training)
                .frame(width: 38, height: 38)
                .background(Theme.training.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .foregroundStyle(.primary)
                HStack(spacing: 6) {
                    Text(exercise.muscleGroup.displayName)
                    if exercise.isCustom {
                        Text("· Eigene")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }
}

/// Auswahl einer Übung (z. B. für Training oder Plan).
struct ExercisePickerView: View {
    let onSelect: (Exercise) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var searchText = ""
    @State private var filter: MuscleGroup?

    private var filtered: [Exercise] {
        exercises.filter { exercise in
            (filter == nil || exercise.muscleGroup == filter)
                && (searchText.isEmpty || exercise.name.localizedCaseInsensitiveContains(searchText))
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filtered) { exercise in
                    Button {
                        onSelect(exercise)
                        dismiss()
                    } label: {
                        ExerciseRow(exercise: exercise)
                    }
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                filterChips
            }
            .overlay {
                if filtered.isEmpty {
                    ContentUnavailableView("Keine Übung gefunden", systemImage: "magnifyingglass")
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Übung suchen")
            .navigationTitle("Übung wählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        ExerciseEditorView(exercise: nil, initialName: searchText) { created in
                            onSelect(created)
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Neue Übung")
                }
            }
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "Alle", isSelected: filter == nil) { filter = nil }
                ForEach(MuscleGroup.allCases) { group in
                    chip(title: group.displayName, isSelected: filter == group) { filter = group }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }

    private func chip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? Theme.accent : Theme.fieldBackground, in: Capsule())
                .foregroundStyle(isSelected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }
}

/// Neue Übung anlegen oder bestehende bearbeiten.
struct ExerciseEditorView: View {
    let exercise: Exercise?
    var onCreated: ((Exercise) -> Void)?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var muscleGroup: MuscleGroup
    @State private var notes: String

    init(exercise: Exercise?, initialName: String = "", onCreated: ((Exercise) -> Void)? = nil) {
        self.exercise = exercise
        self.onCreated = onCreated
        _name = State(initialValue: exercise?.name ?? initialName)
        _muscleGroup = State(initialValue: exercise?.muscleGroup ?? .chest)
        _notes = State(initialValue: exercise?.notes ?? "")
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        Form {
            Section("Übung") {
                TextField("Name, z. B. Bankdrücken", text: $name)
                Picker("Muskelgruppe", selection: $muscleGroup) {
                    ForEach(MuscleGroup.allCases) { group in
                        Label(group.displayName, systemImage: group.symbol).tag(group)
                    }
                }
            }
            Section("Notizen") {
                TextField("Ausführung, Einstellungen am Gerät …", text: $notes, axis: .vertical)
                    .lineLimit(3...8)
            }
        }
        .navigationTitle(exercise == nil ? "Neue Übung" : "Übung bearbeiten")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Sichern") { save() }
                    .disabled(trimmedName.isEmpty)
            }
        }
    }

    private func save() {
        if let exercise {
            exercise.name = trimmedName
            exercise.muscleGroup = muscleGroup
            exercise.notes = notes
            context.saveIfNeeded()
            dismiss()
        } else {
            let created = Exercise(name: trimmedName, muscleGroup: muscleGroup, notes: notes, isCustom: true)
            context.insert(created)
            context.saveIfNeeded()
            if let onCreated {
                onCreated(created)
            } else {
                dismiss()
            }
        }
    }
}

/// Details einer Übung mit Kraftverlauf und Historie.
struct ExerciseDetailView: View {
    let exercise: Exercise
    @State private var showEditor = false

    private var strengthPoints: [StrengthPoint] { Analytics.strengthPoints(for: exercise) }

    var body: some View {
        let points = strengthPoints
        ScrollView {
            VStack(spacing: 16) {
                HStack(spacing: 10) {
                    StatTile(title: "Bestes 1RM", value: exercise.bestEstimatedOneRepMax.oneDecimal, unit: "kg", symbol: "trophy.fill", color: Theme.fat)
                    StatTile(title: "Max. Gewicht", value: exercise.heaviestWeight.oneDecimal, unit: "kg", symbol: "scalemass.fill", color: Theme.training)
                    StatTile(title: "Einheiten", value: "\(points.count)", symbol: "calendar", color: Theme.accent)
                }

                VStack(alignment: .leading, spacing: 12) {
                    CardHeader(title: "Kraftentwicklung", symbol: "chart.line.uptrend.xyaxis", color: Theme.training)
                    if points.isEmpty {
                        Text("Sobald du diese Übung trainierst, siehst du hier deinen Verlauf.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        StrengthChart(points: points)
                    }
                }
                .cardStyle()

                if !points.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        CardHeader(title: "Verlauf", symbol: "clock.arrow.circlepath", color: Theme.accent)
                        ForEach(Array(points.reversed().prefix(15))) { point in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(point.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Text("1RM ≈ \(point.estimatedOneRepMax.oneDecimal) kg")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text(point.sets.map { Formatters.setDescription(weight: $0.weight, reps: $0.reps) }.joined(separator: "  ·  "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Divider()
                        }
                    }
                    .cardStyle()
                }

                if !exercise.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        CardHeader(title: "Notizen", symbol: "note.text", color: .secondary)
                        Text(exercise.notes)
                    }
                    .cardStyle()
                }
            }
            .padding()
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Bearbeiten") { showEditor = true }
            }
        }
        .sheet(isPresented: $showEditor) {
            NavigationStack {
                ExerciseEditorView(exercise: exercise)
            }
        }
    }
}

/// Diagramm: geschätztes 1RM und Top-Satz-Gewicht über die Zeit.
struct StrengthChart: View {
    let points: [StrengthPoint]
    @State private var selectedDate: Date?

    private var selectedPoint: StrengthPoint? {
        guard let selectedDate else { return nil }
        return points.min {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        }
    }

    var body: some View {
        Chart {
            ForEach(points) { point in
                LineMark(x: .value("Datum", point.date), y: .value("Gewicht", point.estimatedOneRepMax))
                    .foregroundStyle(by: .value("Wert", "Geschätztes 1RM"))
                    .interpolationMethod(.catmullRom)
                    .symbol(.circle)
                LineMark(x: .value("Datum", point.date), y: .value("Gewicht", point.topWeight))
                    .foregroundStyle(by: .value("Wert", "Top-Satz"))
                    .interpolationMethod(.catmullRom)
                    .symbol(.square)
            }
            if let selectedPoint {
                RuleMark(x: .value("Auswahl", selectedPoint.date))
                    .foregroundStyle(Color.gray.opacity(0.35))
                    .annotation(position: .top, spacing: 4, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedPoint.date.formatted(.dateTime.day().month(.abbreviated)))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("1RM \(selectedPoint.estimatedOneRepMax.oneDecimal) kg")
                                .font(.caption.weight(.bold))
                            Text("Top \(selectedPoint.topWeight.oneDecimal) kg")
                                .font(.caption2)
                        }
                        .padding(8)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 8))
                        .shadow(color: .black.opacity(0.1), radius: 4)
                    }
            }
        }
        .chartForegroundStyleScale(["Geschätztes 1RM": Theme.training, "Top-Satz": Theme.accent])
        .chartYScale(domain: .automatic(includesZero: false))
        .chartXSelection(value: $selectedDate)
        .chartLegend(position: .bottom, alignment: .leading)
        .frame(height: 220)
    }
}
