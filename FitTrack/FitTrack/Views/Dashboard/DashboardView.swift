import Charts
import SwiftData
import SwiftUI

/// Startseite: Kalorien, Makros, Trainingswoche und Gewicht auf einen Blick.
struct DashboardView: View {
    @Binding var selectedTab: AppTab

    @Environment(\.modelContext) private var context
    @Environment(WorkoutCoordinator.self) private var coordinator

    @Query private var profiles: [UserProfile]
    @Query(sort: \WorkoutSession.startDate, order: .reverse) private var sessions: [WorkoutSession]
    @Query(sort: \BodyWeightEntry.date, order: .reverse) private var weights: [BodyWeightEntry]

    @State private var addFoodMeal: MealType?
    @State private var showWeightSheet = false

    private var profile: UserProfile? { profiles.first }
    private var activeSession: WorkoutSession? { sessions.first(where: \.isActive) }
    private var finishedSessions: [WorkoutSession] { sessions.filter { !$0.isActive } }

    private var sessionsThisWeek: [WorkoutSession] {
        let start = Date().startOfWeek
        return finishedSessions.filter { $0.startDate >= start }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header

                    if let activeSession {
                        ActiveWorkoutBanner(session: activeSession) {
                            coordinator.resume(activeSession)
                        }
                    }

                    TodayNutritionCard(day: .now, goals: NutritionGoals(profile: profile))
                        .onTapGesture { selectedTab = .nutrition }

                    trainingCard
                    weightCard
                    quickActions
                }
                .padding()
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Übersicht")
            .sheet(item: $addFoodMeal) { meal in
                FoodSearchView(meal: meal, date: .now)
            }
            .sheet(isPresented: $showWeightSheet) {
                AddWeightView()
            }
        }
    }

    // MARK: - Abschnitte

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text(greeting)
                .font(.title2.weight(.bold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let base: String
        switch hour {
        case 5..<11: base = "Guten Morgen"
        case 11..<18: base = "Hallo"
        default: base = "Guten Abend"
        }
        if let name = profile?.name, !name.isEmpty {
            return "\(base), \(name)!"
        }
        return "\(base)!"
    }

    private var trainingCard: some View {
        let goal = max(profile?.weeklyWorkoutGoal ?? 3, 1)
        let count = sessionsThisWeek.count
        let volume = sessionsThisWeek.reduce(0) { $0 + $1.totalVolume }

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                CardHeader(title: "Training diese Woche", symbol: "dumbbell.fill", color: Theme.training)
                Spacer()
                Button("Details") { selectedTab = .training }
                    .font(.subheadline)
            }

            HStack(spacing: 18) {
                ZStack {
                    ProgressRing(progress: Double(count) / Double(goal), color: Theme.training, lineWidth: 10)
                    VStack(spacing: 0) {
                        Text("\(count)/\(goal)")
                            .font(.headline.monospacedDigit())
                        Text("Einheiten")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 86, height: 86)

                VStack(alignment: .leading, spacing: 10) {
                    weekDots
                    HStack(spacing: 10) {
                        StatTile(title: "Volumen", value: volume.noDecimal, unit: "kg", symbol: "scalemass.fill", color: Theme.training)
                    }
                }
            }

            if let last = finishedSessions.first {
                Divider()
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Letztes Training")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(last.name)
                            .font(.subheadline.weight(.semibold))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(last.startDate.relativeDayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(last.completedSets.count) Sätze · \(Formatters.shortDuration(last.duration))")
                            .font(.subheadline)
                    }
                }
            }
        }
        .cardStyle()
    }

    private var weekDots: some View {
        let start = Date().startOfWeek
        return HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { offset in
                let day = start.adding(days: offset)
                let trained = sessionsThisWeek.contains { Calendar.current.isDate($0.startDate, inSameDayAs: day) }
                VStack(spacing: 4) {
                    Circle()
                        .fill(trained ? Theme.training : Theme.training.opacity(0.12))
                        .frame(width: 18, height: 18)
                        .overlay {
                            if trained {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                    Text(day.formatted(.dateTime.weekday(.narrow)))
                        .font(.caption2)
                        .foregroundStyle(day.isToday ? Theme.training : .secondary)
                }
            }
        }
    }

    private var weightCard: some View {
        let current = weights.first
        let monthAgo = Date().adding(days: -30)
        let reference = weights.last { $0.date >= monthAgo }
        let recent = weights.filter { $0.date >= monthAgo }.reversed()

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                CardHeader(title: "Körpergewicht", symbol: "scalemass.fill", color: Theme.weight)
                Spacer()
                Button {
                    showWeightSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
            }

            if let current {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(current.weightKg.oneDecimal)
                                .font(.largeTitle.weight(.bold))
                                .monospacedDigit()
                            Text("kg").foregroundStyle(.secondary)
                        }
                        if let reference, reference.persistentModelID != current.persistentModelID {
                            let diff = current.weightKg - reference.weightKg
                            Text("\(diff >= 0 ? "+" : "")\(diff.oneDecimal) kg in 30 Tagen")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let target = profile?.targetWeightKg, target > 0 {
                            Text("Ziel: \(target.oneDecimal) kg")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if recent.count > 1 {
                        Chart(Array(recent)) { entry in
                            LineMark(x: .value("Datum", entry.date), y: .value("Gewicht", entry.weightKg))
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(Theme.weight)
                        }
                        .chartXAxis(.hidden)
                        .chartYAxis(.hidden)
                        .chartYScale(domain: .automatic(includesZero: false))
                        .frame(width: 130, height: 54)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { selectedTab = .progress }
            } else {
                Text("Trage dein Gewicht ein, um deinen Fortschritt zu verfolgen.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .cardStyle()
    }

    private var quickActions: some View {
        HStack(spacing: 12) {
            QuickActionButton(title: activeSession == nil ? "Training starten" : "Training öffnen", symbol: "play.fill", color: Theme.training) {
                coordinator.startWorkout(plan: nil, in: context)
            }
            QuickActionButton(title: "Essen erfassen", symbol: "fork.knife", color: Theme.calories) {
                addFoodMeal = MealType.suggested()
            }
            QuickActionButton(title: "Gewicht eintragen", symbol: "scalemass.fill", color: Theme.weight) {
                showWeightSheet = true
            }
        }
    }
}

/// Karte mit der Ernährungsübersicht eines Tages.
struct TodayNutritionCard: View {
    let goals: NutritionGoals
    @Query private var entries: [FoodEntry]

    init(day: Date, goals: NutritionGoals) {
        let start = day.startOfDay
        let end = day.endOfDay
        _entries = Query(filter: #Predicate<FoodEntry> { $0.date >= start && $0.date < end })
        self.goals = goals
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CardHeader(title: "Ernährung heute", symbol: "flame.fill", color: Theme.calories)
            NutritionSummaryView(totals: entries.totals, goals: goals)
        }
        .cardStyle()
    }
}

struct QuickActionButton: View {
    let title: String
    let symbol: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.title3.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .background(color.opacity(0.14), in: Circle())
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption.weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

/// Hinweis auf ein laufendes Training mit Live-Timer.
struct ActiveWorkoutBanner: View {
    let session: WorkoutSession
    let onResume: () -> Void

    var body: some View {
        Button(action: onResume) {
            HStack(spacing: 14) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.title2)
                    .frame(width: 48, height: 48)
                    .background(.white.opacity(0.2), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Training läuft")
                        .font(.caption.weight(.semibold))
                        .opacity(0.85)
                    Text(session.name)
                        .font(.headline)
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(Formatters.duration(context.date.timeIntervalSince(session.startDate)))
                            .font(.subheadline.monospacedDigit())
                    }
                }
                Spacer()
                Text("Fortsetzen")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.white, in: Capsule())
                    .foregroundStyle(Theme.training)
            }
            .foregroundStyle(.white)
            .padding()
            .background(
                LinearGradient(colors: [Theme.training, Theme.training.opacity(0.75)], startPoint: .leading, endPoint: .trailing),
                in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    DashboardView(selectedTab: .constant(.dashboard))
        .environment(WorkoutCoordinator())
        .modelContainer(PreviewData.container)
}
