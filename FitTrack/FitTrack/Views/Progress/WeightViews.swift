import SwiftData
import SwiftUI

/// Körpergewicht eintragen. Existiert für den Tag bereits ein Eintrag, wird er aktualisiert.
struct AddWeightView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \BodyWeightEntry.date, order: .reverse) private var entries: [BodyWeightEntry]

    @State private var weight: Double = 0
    @State private var date = Date()
    @State private var note = ""
    @State private var didLoadDefaults = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(alignment: .firstTextBaseline) {
                        DecimalField("0,0", value: $weight)
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                        Text("kg")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)

                    HStack {
                        Button {
                            weight = max(weight - 0.1, 0)
                        } label: {
                            Image(systemName: "minus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        Button {
                            weight += 0.1
                        } label: {
                            Image(systemName: "plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Section {
                    DatePicker("Datum", selection: $date, in: ...Date(), displayedComponents: .date)
                    TextField("Notiz (optional)", text: $note)
                }
            }
            .navigationTitle("Gewicht eintragen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { save() }
                        .disabled(weight <= 0)
                }
            }
            .onAppear {
                guard !didLoadDefaults else { return }
                didLoadDefaults = true
                weight = ((entries.first?.weightKg ?? 75) * 10).rounded() / 10
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        let rounded = (weight * 10).rounded() / 10
        if let existing = entries.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
            existing.weightKg = rounded
            if !note.isEmpty { existing.note = note }
        } else {
            let entryDate = date.isToday ? Date() : date.startOfDay.addingTimeInterval(8 * 3600)
            context.insert(BodyWeightEntry(date: entryDate, weightKg: rounded, note: note))
        }
        context.saveIfNeeded()
        dismiss()
    }
}

/// Alle Gewichtseinträge mit Veränderung zum vorherigen Eintrag.
struct WeightHistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \BodyWeightEntry.date, order: .reverse) private var entries: [BodyWeightEntry]
    @State private var showAdd = false

    var body: some View {
        List {
            ForEach(Array(entries.enumerated()), id: \.element.persistentModelID) { index, entry in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.body.weight(.medium))
                        if !entry.note.isEmpty {
                            Text(entry.note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if index + 1 < entries.count {
                        let diff = entry.weightKg - entries[index + 1].weightKg
                        Text("\(diff > 0 ? "+" : "")\(diff.oneDecimal)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(diff > 0 ? Theme.calories : Theme.accent)
                    }
                    Text("\(entry.weightKg.oneDecimal) kg")
                        .font(.headline.monospacedDigit())
                        .frame(minWidth: 80, alignment: .trailing)
                }
            }
            .onDelete { offsets in
                let items = offsets.map { entries[$0] }
                items.forEach { context.delete($0) }
                context.saveIfNeeded()
            }
        }
        .overlay {
            if entries.isEmpty {
                ContentUnavailableView("Keine Einträge", systemImage: "scalemass")
            }
        }
        .navigationTitle("Gewichtsverlauf")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAdd = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddWeightView()
        }
    }
}
