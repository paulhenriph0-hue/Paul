import SwiftData
import SwiftUI

/// Lebensmittel suchen und einer Mahlzeit hinzufügen.
struct FoodSearchView: View {
    let meal: MealType
    let date: Date

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FoodItem.name) private var foods: [FoodItem]
    @Query(FoodSearchView.recentDescriptor) private var recentEntries: [FoodEntry]
    @State private var searchText = ""

    static var recentDescriptor: FetchDescriptor<FoodEntry> {
        var descriptor = FetchDescriptor<FoodEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 60
        return descriptor
    }

    private var filtered: [FoodItem] {
        guard !searchText.isEmpty else { return foods }
        return foods.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.brand.localizedCaseInsensitiveContains(searchText)
                || (!$0.barcode.isEmpty && $0.barcode.hasPrefix(searchText))
        }
    }

    private var favorites: [FoodItem] { foods.filter(\.isFavorite) }

    private var recentFoods: [FoodItem] {
        var seen = Set<PersistentIdentifier>()
        var result: [FoodItem] = []
        for entry in recentEntries {
            guard let food = entry.food, seen.insert(food.persistentModelID).inserted else { continue }
            result.append(food)
            if result.count == 8 { break }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            List {
                if searchText.isEmpty {
                    Section {
                        NavigationLink {
                            BarcodeLookupView(meal: meal, date: date) { dismiss() }
                        } label: {
                            Label("Barcode scannen", systemImage: "barcode.viewfinder")
                                .font(.headline)
                        }
                        NavigationLink {
                            QuickAddView(meal: meal, date: date) { dismiss() }
                        } label: {
                            Label("Schnelleintrag (nur Kalorien/Makros)", systemImage: "bolt.fill")
                        }
                        NavigationLink {
                            FoodEditorView(food: nil)
                        } label: {
                            Label("Eigenes Lebensmittel anlegen", systemImage: "plus.square.fill")
                        }
                    }

                    if !recentFoods.isEmpty {
                        Section("Zuletzt verwendet") {
                            ForEach(recentFoods) { food in row(for: food) }
                        }
                    }

                    if !favorites.isEmpty {
                        Section("Favoriten") {
                            ForEach(favorites) { food in row(for: food) }
                        }
                    }
                }

                Section(searchText.isEmpty ? "Alle Lebensmittel" : "Suchergebnisse") {
                    ForEach(filtered) { food in row(for: food) }
                }
            }
            .overlay {
                if filtered.isEmpty && !searchText.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Lebensmittel suchen")
            .navigationTitle(meal.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        BarcodeLookupView(meal: meal, date: date) { dismiss() }
                    } label: {
                        Image(systemName: "barcode.viewfinder")
                    }
                    .accessibilityLabel("Barcode scannen")
                }
            }
        }
    }

    private func row(for food: FoodItem) -> some View {
        NavigationLink {
            AddFoodEntryView(food: food, meal: meal, date: date) { dismiss() }
        } label: {
            FoodItemRow(food: food)
        }
    }
}

struct FoodItemRow: View {
    let food: FoodItem

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(food.name)
                        .font(.body.weight(.medium))
                    if food.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(Theme.fat)
                    }
                }
                Text(food.brand.isEmpty ? "pro 100 g" : "\(food.brand) · pro 100 g")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(food.caloriesPer100g.noDecimal) kcal")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                MacroInlineView(macros: food.per100g)
                    .font(.caption2)
            }
        }
    }
}

/// Menge wählen und Eintrag speichern.
struct AddFoodEntryView: View {
    @Bindable var food: FoodItem
    let date: Date
    let onSaved: () -> Void

    @Environment(\.modelContext) private var context
    @State private var meal: MealType
    @State private var grams: Double

    init(food: FoodItem, meal: MealType, date: Date, onSaved: @escaping () -> Void) {
        self._food = Bindable(food)
        self.date = date
        self.onSaved = onSaved
        _meal = State(initialValue: meal)
        _grams = State(initialValue: food.servingGrams > 0 ? food.servingGrams : 100)
    }

    private var macros: MacroTotals { food.macros(forGrams: grams) }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(food.name)
                        .font(.title3.weight(.bold))
                    if !food.brand.isEmpty {
                        Text(food.brand)
                            .foregroundStyle(.secondary)
                    }
                }
                Toggle(isOn: $food.isFavorite) {
                    Label("Favorit", systemImage: "star.fill")
                }
            }

            Section("Menge") {
                NumberInputRow(title: "Menge", value: $grams, unit: "g")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if food.servingGrams > 0 {
                            Button("1 Portion (\(food.servingGrams.noDecimal) g)") { grams = food.servingGrams }
                                .buttonStyle(.bordered)
                        }
                        ForEach([50.0, 100, 150, 200, 250], id: \.self) { amount in
                            Button("\(amount.noDecimal) g") { grams = amount }
                                .buttonStyle(.bordered)
                        }
                    }
                }
            }

            Section("Mahlzeit") {
                Picker("Mahlzeit", selection: $meal) {
                    ForEach(MealType.allCases) { meal in
                        Text(meal.displayName).tag(meal)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Nährwerte für diese Menge") {
                MacroBreakdownView(macros: macros)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Hinzufügen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Hinzufügen") { save() }
                    .disabled(grams <= 0)
            }
        }
    }

    private func save() {
        let entry = FoodEntry(food: food, grams: grams, meal: meal, date: date)
        context.insert(entry)
        entry.food = food
        context.saveIfNeeded()
        onSaved()
    }
}

/// Kalorien und Makros als übersichtliche Zeilen.
struct MacroBreakdownView: View {
    let macros: MacroTotals

    var body: some View {
        VStack(spacing: 10) {
            row("Kalorien", macros.calories.noDecimal, "kcal", Theme.calories)
            row("Protein", macros.protein.oneDecimal, "g", Theme.protein)
            row("Kohlenhydrate", macros.carbs.oneDecimal, "g", Theme.carbs)
            row("Fett", macros.fat.oneDecimal, "g", Theme.fat)
        }
    }

    private func row(_ title: String, _ value: String, _ unit: String, _ color: Color) -> some View {
        HStack {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(title)
            Spacer()
            Text("\(value) \(unit)")
                .monospacedDigit()
                .fontWeight(.semibold)
        }
    }
}

/// Schnelleintrag ohne Lebensmittel aus der Datenbank.
struct QuickAddView: View {
    let date: Date
    let onSaved: () -> Void

    @Environment(\.modelContext) private var context
    @State private var meal: MealType
    @State private var name = ""
    @State private var totals = MacroTotals()

    init(meal: MealType, date: Date, onSaved: @escaping () -> Void) {
        self.date = date
        self.onSaved = onSaved
        _meal = State(initialValue: meal)
    }

    var body: some View {
        Form {
            Section("Beschreibung") {
                TextField("z. B. Restaurant-Essen", text: $name)
                Picker("Mahlzeit", selection: $meal) {
                    ForEach(MealType.allCases) { meal in
                        Text(meal.displayName).tag(meal)
                    }
                }
            }
            Section {
                NumberInputRow(title: "Kalorien", value: $totals.calories, unit: "kcal")
                NumberInputRow(title: "Protein", value: $totals.protein, unit: "g")
                NumberInputRow(title: "Kohlenhydrate", value: $totals.carbs, unit: "g")
                NumberInputRow(title: "Fett", value: $totals.fat, unit: "g")
            } header: {
                Text("Nährwerte (gesamt)")
            } footer: {
                if totals.calories == 0 && totals.caloriesFromMacros > 0 {
                    Button("Kalorien aus Makros übernehmen (\(totals.caloriesFromMacros.noDecimal) kcal)") {
                        totals.calories = totals.caloriesFromMacros.rounded()
                    }
                    .font(.caption)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Schnelleintrag")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Sichern") { save() }
                    .disabled(totals.calories <= 0)
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = FoodEntry(
            quickAddName: trimmed.isEmpty ? "Schnelleintrag" : trimmed,
            totals: totals,
            meal: meal,
            date: date
        )
        context.insert(entry)
        context.saveIfNeeded()
        onSaved()
    }
}

/// Bestehenden Tagebucheintrag bearbeiten.
struct EditFoodEntryView: View {
    @Bindable var entry: FoodEntry
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section {
                if entry.isQuickAdd {
                    TextField("Name", text: $entry.name)
                } else {
                    Text(entry.name)
                        .font(.headline)
                }
                Picker("Mahlzeit", selection: $entry.meal) {
                    ForEach(MealType.allCases) { meal in
                        Text(meal.displayName).tag(meal)
                    }
                }
                DatePicker("Zeitpunkt", selection: $entry.date)
            }

            if entry.isQuickAdd {
                Section("Nährwerte (gesamt)") {
                    NumberInputRow(title: "Kalorien", value: $entry.caloriesPer100g, unit: "kcal")
                    NumberInputRow(title: "Protein", value: $entry.proteinPer100g, unit: "g")
                    NumberInputRow(title: "Kohlenhydrate", value: $entry.carbsPer100g, unit: "g")
                    NumberInputRow(title: "Fett", value: $entry.fatPer100g, unit: "g")
                }
            } else {
                Section("Menge") {
                    NumberInputRow(title: "Menge", value: $entry.grams, unit: "g")
                }
                Section("Nährwerte") {
                    MacroBreakdownView(macros: entry.macros)
                }
            }

            Section {
                Button("Eintrag löschen", role: .destructive) {
                    let toDelete = entry
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        context.delete(toDelete)
                        context.saveIfNeeded()
                    }
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Eintrag bearbeiten")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Fertig") {
                    context.saveIfNeeded()
                    dismiss()
                }
            }
        }
    }
}
