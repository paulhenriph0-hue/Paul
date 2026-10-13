import SwiftData
import SwiftUI

/// Ernährungstagebuch mit Tagesnavigation.
struct NutritionView: View {
    @Query private var profiles: [UserProfile]
    @State private var selectedDate = Date()

    var body: some View {
        NavigationStack {
            DayLogView(date: selectedDate, goals: NutritionGoals(profile: profiles.first))
                .id(selectedDate.startOfDay)
                .safeAreaInset(edge: .top, spacing: 0) {
                    DaySwitcher(date: $selectedDate)
                }
                .navigationTitle("Ernährung")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink {
                            FoodLibraryView()
                        } label: {
                            Image(systemName: "books.vertical.fill")
                        }
                        .accessibilityLabel("Lebensmittel verwalten")
                    }
                }
        }
    }
}

/// Wechsel zwischen Tagen.
struct DaySwitcher: View {
    @Binding var date: Date

    var body: some View {
        HStack {
            Button {
                date = date.adding(days: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .frame(width: 44, height: 36)
            }
            .accessibilityLabel("Vorheriger Tag")

            Spacer()

            VStack(spacing: 0) {
                Text(date.relativeDayName)
                    .font(.headline)
                if !date.isToday {
                    Button("Zu heute springen") { date = .now }
                        .font(.caption)
                }
            }

            Spacer()

            Button {
                date = date.adding(days: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .frame(width: 44, height: 36)
            }
            .disabled(date.isToday)
            .accessibilityLabel("Nächster Tag")
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(.bar)
    }
}

/// Alle Mahlzeiten eines Tages.
struct DayLogView: View {
    let date: Date
    let goals: NutritionGoals

    @Environment(\.modelContext) private var context
    @Query private var entries: [FoodEntry]
    @State private var addMeal: MealType?
    @State private var editingEntry: FoodEntry?

    init(date: Date, goals: NutritionGoals) {
        self.date = date
        self.goals = goals
        let start = date.startOfDay
        let end = date.endOfDay
        _entries = Query(
            filter: #Predicate<FoodEntry> { $0.date >= start && $0.date < end },
            sort: \FoodEntry.date
        )
    }

    /// Zeitpunkt für neue Einträge: jetzt (heute) bzw. Mittag des gewählten Tages.
    private var entryDate: Date {
        date.isToday ? .now : date.startOfDay.addingTimeInterval(12 * 3600)
    }

    var body: some View {
        List {
            Section {
                NutritionSummaryView(totals: entries.totals, goals: goals)
                    .padding(.vertical, 8)
            }

            ForEach(MealType.allCases) { meal in
                let mealEntries = entries.filter { $0.meal == meal }
                Section {
                    ForEach(mealEntries) { entry in
                        Button {
                            editingEntry = entry
                        } label: {
                            FoodEntryRow(entry: entry)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                context.delete(entry)
                                context.saveIfNeeded()
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        }
                    }
                    Button {
                        addMeal = meal
                    } label: {
                        Label("Lebensmittel hinzufügen", systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                } header: {
                    MealHeader(meal: meal, totals: mealEntries.totals)
                }
            }
        }
        .sheet(item: $addMeal) { meal in
            FoodSearchView(meal: meal, date: entryDate)
        }
        .sheet(item: $editingEntry) { entry in
            NavigationStack {
                EditFoodEntryView(entry: entry)
            }
        }
    }
}

struct MealHeader: View {
    let meal: MealType
    let totals: MacroTotals

    var body: some View {
        HStack {
            Label(meal.displayName, systemImage: meal.symbol)
                .font(.headline)
                .foregroundStyle(.primary)
                .labelStyle(MealLabelStyle(color: meal.color))
            Spacer()
            Text("\(totals.calories.noDecimal) kcal")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .textCase(nil)
    }
}

private struct MealLabelStyle: LabelStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.icon.foregroundStyle(color)
            configuration.title
        }
    }
}

struct FoodEntryRow: View {
    let entry: FoodEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.name)
                    .font(.body.weight(.medium))
                HStack(spacing: 6) {
                    Text(entry.isQuickAdd ? "Schnelleintrag" : "\(entry.grams.noDecimal) g")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    MacroInlineView(macros: entry.macros)
                }
            }
            Spacer()
            Text("\(entry.macros.calories.noDecimal)")
                .font(.headline.monospacedDigit())
            Text("kcal")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    NutritionView()
        .modelContainer(PreviewData.container)
}
