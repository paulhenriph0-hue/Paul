import SwiftData
import SwiftUI

/// Verwaltung der Lebensmitteldatenbank.
struct FoodLibraryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \FoodItem.name) private var foods: [FoodItem]
    @State private var searchText = ""
    @State private var editingFood: FoodItem?
    @State private var showNewFood = false

    private var filtered: [FoodItem] {
        guard !searchText.isEmpty else { return foods }
        return foods.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) || $0.brand.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            Section {
                ForEach(filtered) { food in
                    Button {
                        editingFood = food
                    } label: {
                        FoodItemRow(food: food)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .leading) {
                        Button {
                            food.isFavorite.toggle()
                            context.saveIfNeeded()
                        } label: {
                            Label(food.isFavorite ? "Kein Favorit" : "Favorit", systemImage: food.isFavorite ? "star.slash" : "star.fill")
                        }
                        .tint(Theme.fat)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            context.delete(food)
                            context.saveIfNeeded()
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
                }
            } footer: {
                Text("\(foods.count) Lebensmittel · Nach links wischen zum Löschen, nach rechts für Favoriten. Bereits erfasste Mahlzeiten bleiben beim Löschen erhalten.")
            }
        }
        .overlay {
            if filtered.isEmpty && !searchText.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .searchable(text: $searchText, prompt: "Lebensmittel suchen")
        .navigationTitle("Lebensmittel")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showNewFood = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Neues Lebensmittel")
            }
        }
        .sheet(item: $editingFood) { food in
            NavigationStack {
                FoodEditorView(food: food)
            }
        }
        .sheet(isPresented: $showNewFood) {
            NavigationStack {
                FoodEditorView(food: nil)
            }
        }
    }
}

/// Lebensmittel anlegen oder bearbeiten (Werte pro 100 g).
struct FoodEditorView: View {
    let food: FoodItem?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var brand: String
    @State private var per100g: MacroTotals
    @State private var servingGrams: Double
    @State private var isFavorite: Bool

    init(food: FoodItem?) {
        self.food = food
        _name = State(initialValue: food?.name ?? "")
        _brand = State(initialValue: food?.brand ?? "")
        _per100g = State(initialValue: food?.per100g ?? MacroTotals())
        _servingGrams = State(initialValue: food?.servingGrams ?? 100)
        _isFavorite = State(initialValue: food?.isFavorite ?? false)
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var isValid: Bool {
        !trimmedName.isEmpty && per100g.calories > 0
    }

    /// Hinweis, wenn Kalorien und Makros stark voneinander abweichen.
    private var showsMismatchHint: Bool {
        let fromMacros = per100g.caloriesFromMacros
        guard per100g.calories > 0, fromMacros > 0 else { return false }
        return abs(fromMacros - per100g.calories) / per100g.calories > 0.15
    }

    var body: some View {
        Form {
            Section("Lebensmittel") {
                TextField("Name", text: $name)
                TextField("Marke (optional)", text: $brand)
                Toggle("Favorit", isOn: $isFavorite)
            }

            Section {
                NumberInputRow(title: "Kalorien", value: $per100g.calories, unit: "kcal")
                NumberInputRow(title: "Protein", value: $per100g.protein, unit: "g")
                NumberInputRow(title: "Kohlenhydrate", value: $per100g.carbs, unit: "g")
                NumberInputRow(title: "Fett", value: $per100g.fat, unit: "g")
            } header: {
                Text("Nährwerte pro 100 g")
            } footer: {
                if showsMismatchHint {
                    Text("Hinweis: Aus den Makros ergeben sich ca. \(per100g.caloriesFromMacros.noDecimal) kcal. Bitte Werte prüfen.")
                        .foregroundStyle(.orange)
                } else if per100g.calories == 0 && per100g.caloriesFromMacros > 0 {
                    Button("Kalorien aus Makros übernehmen (\(per100g.caloriesFromMacros.noDecimal) kcal)") {
                        per100g.calories = per100g.caloriesFromMacros.rounded()
                    }
                    .font(.caption)
                }
            }

            Section {
                NumberInputRow(title: "Portionsgröße", value: $servingGrams, unit: "g")
            } footer: {
                Text("Die Portionsgröße wird beim Hinzufügen als Standardmenge vorgeschlagen.")
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(food == nil ? "Neues Lebensmittel" : "Bearbeiten")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Sichern") { save() }
                    .disabled(!isValid)
            }
        }
    }

    private func save() {
        let target: FoodItem
        if let food {
            target = food
        } else {
            target = FoodItem(name: trimmedName, caloriesPer100g: 0, proteinPer100g: 0, carbsPer100g: 0, fatPer100g: 0, isCustom: true)
            context.insert(target)
        }
        target.name = trimmedName
        target.brand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        target.caloriesPer100g = per100g.calories
        target.proteinPer100g = per100g.protein
        target.carbsPer100g = per100g.carbs
        target.fatPer100g = per100g.fat
        target.servingGrams = servingGrams
        target.isFavorite = isFavorite
        context.saveIfNeeded()
        dismiss()
    }
}
