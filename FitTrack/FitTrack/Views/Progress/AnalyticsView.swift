import Charts
import SwiftData
import SwiftUI

/// Fortschrittsanalyse: Körpergewicht, Kraft, Trainingsvolumen und Kalorien.
struct AnalyticsView: View {
    @State private var range: TimeRange = .quarter

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("Zeitraum", selection: $range) {
                        ForEach(TimeRange.allCases) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)

                    WeightProgressCard(range: range)
                    StrengthProgressCard(range: range)
                    TrainingVolumeCard()
                    CalorieHistoryCard(days: 14)
                }
                .padding()
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Fortschritt")
        }
    }
}

// MARK: - Körpergewicht

struct WeightProgressCard: View {
    let range: TimeRange

    @Query(sort: \BodyWeightEntry.date) private var allEntries: [BodyWeightEntry]
    @Query private var profiles: [UserProfile]
    @State private var showAddWeight = false
    @State private var selectedDate: Date?

    private var entries: [BodyWeightEntry] { allEntries.filter { range.contains($0.date) } }

    private var targetWeight: Double? {
        guard let target = profiles.first?.targetWeightKg, target > 0 else { return nil }
        return target
    }

    private var yDomain: ClosedRange<Double> {
        var values = entries.map(\.weightKg)
        if let targetWeight { values.append(targetWeight) }
        let low = (values.min() ?? 60) - 1
        let high = (values.max() ?? 90) + 1
        return low.rounded(.down)...high.rounded(.up)
    }

    private var selectedEntry: BodyWeightEntry? {
        guard let selectedDate else { return nil }
        return entries.min {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                CardHeader(title: "Körpergewicht", symbol: "scalemass.fill", color: Theme.weight)
                Spacer()
                Button {
                    showAddWeight = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                .accessibilityLabel("Gewicht eintragen")
            }

            if entries.isEmpty {
                ContentUnavailableView(
                    "Keine Einträge",
                    systemImage: "scalemass",
                    description: Text("Trage dein Gewicht ein, um deinen Verlauf zu sehen.")
                )
            } else {
                stats
                chart
                NavigationLink {
                    WeightHistoryView()
                } label: {
                    HStack {
                        Text("Alle Einträge")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(.subheadline.weight(.medium))
                }
            }
        }
        .cardStyle()
        .sheet(isPresented: $showAddWeight) {
            AddWeightView()
        }
    }

    private var stats: some View {
        let current = entries.last?.weightKg ?? 0
        let change = current - (entries.first?.weightKg ?? current)
        return HStack(spacing: 10) {
            StatTile(title: "Aktuell", value: current.oneDecimal, unit: "kg", symbol: "scalemass.fill", color: Theme.weight)
            StatTile(
                title: "Veränderung",
                value: "\(change > 0 ? "+" : "")\(change.oneDecimal)",
                unit: "kg",
                symbol: change <= 0 ? "arrow.down.right" : "arrow.up.right",
                color: Theme.accent
            )
            if let targetWeight {
                StatTile(
                    title: "Bis zum Ziel",
                    value: abs(current - targetWeight).oneDecimal,
                    unit: "kg",
                    symbol: "flag.checkered",
                    color: Theme.training
                )
            }
        }
    }

    private var chart: some View {
        Chart {
            ForEach(entries) { entry in
                LineMark(x: .value("Datum", entry.date), y: .value("Gewicht", entry.weightKg))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Theme.weight)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                if entries.count <= 45 {
                    PointMark(x: .value("Datum", entry.date), y: .value("Gewicht", entry.weightKg))
                        .foregroundStyle(Theme.weight)
                        .symbolSize(20)
                }
            }
            if let targetWeight {
                RuleMark(y: .value("Ziel", targetWeight))
                    .foregroundStyle(Theme.training.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    .annotation(position: .top, alignment: .leading) {
                        Text("Ziel \(targetWeight.oneDecimal) kg")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.training)
                    }
            }
            if let selectedEntry {
                RuleMark(x: .value("Auswahl", selectedEntry.date))
                    .foregroundStyle(Color.gray.opacity(0.35))
                    .annotation(position: .top, spacing: 4, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedEntry.date.formatted(.dateTime.day().month(.abbreviated)))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("\(selectedEntry.weightKg.oneDecimal) kg")
                                .font(.caption.weight(.bold))
                        }
                        .padding(8)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 8))
                        .shadow(color: .black.opacity(0.1), radius: 4)
                    }
            }
        }
        .chartYScale(domain: yDomain)
        .chartXSelection(value: $selectedDate)
        .frame(height: 220)
    }
}

// MARK: - Kraft

struct StrengthProgressCard: View {
    let range: TimeRange

    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var selectedExerciseID: PersistentIdentifier?

    private var trainedExercises: [Exercise] {
        exercises.filter { !$0.completedSets.isEmpty }
    }

    private var selectedExercise: Exercise? {
        if let selectedExerciseID, let match = trainedExercises.first(where: { $0.persistentModelID == selectedExerciseID }) {
            return match
        }
        return trainedExercises.max { $0.completedSets.count < $1.completedSets.count }
    }

    var body: some View {
        let exercise = selectedExercise
        let points = exercise.map { Analytics.strengthPoints(for: $0).filter { range.contains($0.date) } } ?? []

        VStack(alignment: .leading, spacing: 14) {
            HStack {
                CardHeader(title: "Kraftentwicklung", symbol: "chart.line.uptrend.xyaxis", color: Theme.training)
                Spacer()
                if !trainedExercises.isEmpty {
                    Menu {
                        Picker("Übung", selection: Binding(
                            get: { exercise?.persistentModelID },
                            set: { selectedExerciseID = $0 }
                        )) {
                            ForEach(trainedExercises) { item in
                                Text(item.name).tag(Optional(item.persistentModelID))
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(exercise?.name ?? "Übung")
                                .lineLimit(1)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption)
                        }
                        .font(.subheadline.weight(.medium))
                    }
                }
            }

            if let exercise, points.count >= 1 {
                let first = points.first?.estimatedOneRepMax ?? 0
                let last = points.last?.estimatedOneRepMax ?? 0
                let change = first > 0 ? (last - first) / first * 100 : 0

                HStack(spacing: 10) {
                    StatTile(title: "Bestes 1RM", value: (points.map(\.estimatedOneRepMax).max() ?? 0).oneDecimal, unit: "kg", symbol: "trophy.fill", color: Theme.fat)
                    StatTile(title: "Veränderung", value: "\(change >= 0 ? "+" : "")\(change.noDecimal)", unit: "%", symbol: "arrow.up.right", color: Theme.accent)
                    StatTile(title: "Einheiten", value: "\(points.count)", symbol: "calendar", color: Theme.training)
                }
                StrengthChart(points: points)
                NavigationLink {
                    ExerciseDetailView(exercise: exercise)
                } label: {
                    HStack {
                        Text("Details zu \(exercise.name)")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(.subheadline.weight(.medium))
                }
            } else {
                Text(trainedExercises.isEmpty
                     ? "Schließe dein erstes Training ab, um deine Kraftentwicklung zu sehen."
                     : "Im gewählten Zeitraum gibt es keine Daten für diese Übung.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .cardStyle()
    }
}

// MARK: - Trainingsvolumen

struct TrainingVolumeCard: View {
    @Query(sort: \WorkoutSession.startDate) private var sessions: [WorkoutSession]

    var body: some View {
        let weeks = Analytics.weeklyVolume(sessions, weeks: 8)
        let lastFour = weeks.suffix(4)
        let average = Double(lastFour.reduce(0) { $0 + $1.workouts }) / Double(max(lastFour.count, 1))

        VStack(alignment: .leading, spacing: 14) {
            CardHeader(title: "Trainingsvolumen pro Woche", symbol: "chart.bar.fill", color: Theme.accent)

            HStack(spacing: 10) {
                StatTile(title: "Diese Woche", value: (weeks.last?.volume ?? 0).noDecimal, unit: "kg", symbol: "scalemass.fill", color: Theme.accent)
                StatTile(title: "Ø Trainings/Woche", value: average.oneDecimal, symbol: "figure.strengthtraining.traditional", color: Theme.training)
            }

            Chart(weeks) { week in
                BarMark(
                    x: .value("Woche", week.weekStart, unit: .weekOfYear),
                    y: .value("Volumen", week.volume)
                )
                .foregroundStyle(Theme.accentGradient)
                .cornerRadius(6)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }
            .frame(height: 180)
        }
        .cardStyle()
    }
}

// MARK: - Kalorien

struct CalorieHistoryCard: View {
    let days: Int

    @Query private var entries: [FoodEntry]
    @Query private var profiles: [UserProfile]

    init(days: Int) {
        self.days = days
        let start = Date().startOfDay.adding(days: -(days - 1))
        _entries = Query(filter: #Predicate<FoodEntry> { $0.date >= start }, sort: \FoodEntry.date)
    }

    var body: some View {
        let daily = Analytics.dailyTotals(entries, days: days)
        let loggedDays = daily.filter { $0.totals.calories > 0 }
        let averageCalories = loggedDays.isEmpty ? 0 : loggedDays.reduce(0) { $0 + $1.totals.calories } / Double(loggedDays.count)
        let averageProtein = loggedDays.isEmpty ? 0 : loggedDays.reduce(0) { $0 + $1.totals.protein } / Double(loggedDays.count)
        let goal = Double(profiles.first?.calorieGoal ?? 2400)

        VStack(alignment: .leading, spacing: 14) {
            CardHeader(title: "Kalorien – letzte \(days) Tage", symbol: "flame.fill", color: Theme.calories)

            HStack(spacing: 10) {
                StatTile(title: "Ø Kalorien", value: averageCalories.noDecimal, unit: "kcal", symbol: "flame.fill", color: Theme.calories)
                StatTile(title: "Ø Protein", value: averageProtein.noDecimal, unit: "g", symbol: "fish.fill", color: Theme.protein)
            }

            Chart {
                ForEach(daily) { day in
                    BarMark(
                        x: .value("Tag", day.day, unit: .day),
                        y: .value("Kalorien", day.totals.calories)
                    )
                    .foregroundStyle(day.totals.calories > goal * 1.05 ? Color.red.opacity(0.75) : Theme.calories)
                    .cornerRadius(4)
                }
                RuleMark(y: .value("Ziel", goal))
                    .foregroundStyle(Color.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Ziel \(goal.noDecimal)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 3)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }
            .frame(height: 180)
        }
        .cardStyle()
    }
}

#Preview {
    AnalyticsView()
        .modelContainer(PreviewData.container)
}
