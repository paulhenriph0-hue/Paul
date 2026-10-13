import Foundation
import SwiftData

/// Ein Datenpunkt der Kraftentwicklung (eine Trainingseinheit einer Übung).
struct StrengthPoint: Identifiable {
    let id: PersistentIdentifier
    let date: Date
    let estimatedOneRepMax: Double
    let topWeight: Double
    let volume: Double
    let sets: [WorkoutSet]
}

struct WeeklyVolume: Identifiable {
    var id: Date { weekStart }
    let weekStart: Date
    let volume: Double
    let workouts: Int
}

struct DailyCalories: Identifiable {
    var id: Date { day }
    let day: Date
    let totals: MacroTotals
}

/// Zeitraumauswahl für Diagramme.
enum TimeRange: String, CaseIterable, Identifiable {
    case month = "1M"
    case quarter = "3M"
    case halfYear = "6M"
    case year = "1J"
    case all = "Alle"

    var id: Self { self }

    var startDate: Date? {
        let now = Date()
        switch self {
        case .month: return now.adding(days: -30)
        case .quarter: return now.adding(days: -90)
        case .halfYear: return now.adding(days: -180)
        case .year: return now.adding(days: -365)
        case .all: return nil
        }
    }

    func contains(_ date: Date) -> Bool {
        guard let startDate else { return true }
        return date >= startDate
    }
}

enum Analytics {
    /// Bestes geschätztes 1RM und Top-Gewicht pro abgeschlossener Einheit.
    static func strengthPoints(for exercise: Exercise) -> [StrengthPoint] {
        let grouped = Dictionary(grouping: exercise.completedSets) { $0.session?.persistentModelID }
        return grouped.compactMap { id, sets -> StrengthPoint? in
            guard let id, let session = sets.first?.session else { return nil }
            return StrengthPoint(
                id: id,
                date: session.startDate,
                estimatedOneRepMax: sets.map(\.estimatedOneRepMax).max() ?? 0,
                topWeight: sets.map(\.weight).max() ?? 0,
                volume: sets.reduce(0) { $0 + $1.volume },
                sets: sets.sorted { $0.sortIndex < $1.sortIndex }
            )
        }
        .sorted { $0.date < $1.date }
    }

    /// Trainingsvolumen der letzten `weeks` Kalenderwochen (älteste zuerst).
    static func weeklyVolume(_ sessions: [WorkoutSession], weeks: Int, now: Date = .now) -> [WeeklyVolume] {
        let currentWeek = now.startOfWeek
        return (0..<weeks).reversed().map { offset in
            let start = currentWeek.adding(weeks: -offset)
            let end = start.adding(weeks: 1)
            let inWeek = sessions.filter { !$0.isActive && $0.startDate >= start && $0.startDate < end }
            return WeeklyVolume(
                weekStart: start,
                volume: inWeek.reduce(0) { $0 + $1.totalVolume },
                workouts: inWeek.count
            )
        }
    }

    /// Tagessummen der Ernährung für die letzten `days` Tage (ältester zuerst).
    static func dailyTotals(_ entries: [FoodEntry], days: Int, now: Date = .now) -> [DailyCalories] {
        let today = now.startOfDay
        let grouped = Dictionary(grouping: entries) { $0.date.startOfDay }
        return (0..<days).reversed().map { offset in
            let day = today.adding(days: -offset)
            return DailyCalories(day: day, totals: (grouped[day] ?? []).totals)
        }
    }
}
