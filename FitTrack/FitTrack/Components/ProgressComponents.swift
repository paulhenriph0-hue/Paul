import SwiftUI

/// Kreisförmige Fortschrittsanzeige.
struct ProgressRing: View {
    var progress: Double
    var color: Color
    var lineWidth: CGFloat = 14

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: progress)
        }
    }
}

/// Horizontale Fortschrittsleiste für einen Makronährstoff.
struct MacroProgressRow: View {
    let title: String
    let value: Double
    let goal: Double
    let color: Color
    var unit: String = "g"

    private var progress: Double { goal > 0 ? value / goal : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(value.noDecimal) / \(goal.noDecimal) \(unit)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.15))
                    Capsule()
                        .fill(progress > 1.05 ? Color.red : color)
                        .frame(width: proxy.size.width * min(progress, 1))
                        .animation(.easeOut(duration: 0.6), value: progress)
                }
            }
            .frame(height: 8)
        }
    }
}

/// Kleine Kennzahl-Kachel.
struct StatTile: View {
    let title: String
    let value: String
    var unit: String = ""
    let symbol: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.09), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// Überschrift einer Karte mit Symbol.
struct CardHeader: View {
    let title: String
    let symbol: String
    let color: Color

    var body: some View {
        Label {
            Text(title).font(.headline)
        } icon: {
            Image(systemName: symbol).foregroundStyle(color)
        }
    }
}

/// Übersicht aus Kalorienring und Makro-Leisten.
struct NutritionSummaryView: View {
    let totals: MacroTotals
    let goals: NutritionGoals

    private var remaining: Double { goals.calories - totals.calories }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                ZStack {
                    ProgressRing(
                        progress: goals.calories > 0 ? totals.calories / goals.calories : 0,
                        color: remaining < 0 ? .red : Theme.calories,
                        lineWidth: 13
                    )
                    VStack(spacing: 0) {
                        Text(abs(remaining).noDecimal)
                            .font(.title2.weight(.bold))
                            .monospacedDigit()
                        Text(remaining >= 0 ? "kcal übrig" : "kcal zu viel")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 120, height: 120)

                VStack(alignment: .leading, spacing: 10) {
                    caloriesLine(title: "Gegessen", value: totals.calories, color: Theme.calories)
                    caloriesLine(title: "Ziel", value: goals.calories, color: .secondary)
                }
                Spacer(minLength: 0)
            }

            VStack(spacing: 12) {
                MacroProgressRow(title: "Protein", value: totals.protein, goal: goals.protein, color: Theme.protein)
                MacroProgressRow(title: "Kohlenhydrate", value: totals.carbs, goal: goals.carbs, color: Theme.carbs)
                MacroProgressRow(title: "Fett", value: totals.fat, goal: goals.fat, color: Theme.fat)
            }
        }
    }

    private func caloriesLine(title: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value.noDecimal)
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(color)
                Text("kcal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Kompakte Makroanzeige („P 30 · K 45 · F 12“).
struct MacroInlineView: View {
    let macros: MacroTotals

    var body: some View {
        HStack(spacing: 8) {
            macro("P", macros.protein, Theme.protein)
            macro("K", macros.carbs, Theme.carbs)
            macro("F", macros.fat, Theme.fat)
        }
        .font(.caption.monospacedDigit())
    }

    private func macro(_ letter: String, _ value: Double, _ color: Color) -> some View {
        HStack(spacing: 2) {
            Text(letter).fontWeight(.bold).foregroundStyle(color)
            Text("\(value.oneDecimal) g").foregroundStyle(.secondary)
        }
    }
}
