import Foundation

extension Date {
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }

    var endOfDay: Date { startOfDay.adding(days: 1) }

    var startOfWeek: Date {
        Calendar.current.dateInterval(of: .weekOfYear, for: self)?.start ?? startOfDay
    }

    var isToday: Bool { Calendar.current.isDateInToday(self) }

    var isYesterday: Bool { Calendar.current.isDateInYesterday(self) }

    func adding(days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }

    func adding(weeks: Int) -> Date {
        Calendar.current.date(byAdding: .weekOfYear, value: weeks, to: self) ?? self
    }

    /// „Heute“, „Gestern“ oder ein formatiertes Datum.
    var relativeDayName: String {
        if isToday { return "Heute" }
        if isYesterday { return "Gestern" }
        return formatted(.dateTime.weekday(.wide).day().month(.wide))
    }
}

extension Double {
    /// Höchstens eine Nachkommastelle, z. B. „82,5“.
    var oneDecimal: String {
        formatted(.number.precision(.fractionLength(0...1)))
    }

    /// Ohne Nachkommastellen, z. B. „2.350“.
    var noDecimal: String {
        formatted(.number.precision(.fractionLength(0)))
    }
}

enum Formatters {
    /// Formatiert eine Dauer als „m:ss“ bzw. „h:mm:ss“.
    static func duration(_ interval: TimeInterval) -> String {
        let total = max(Int(interval), 0)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Kurze Dauer für Listen, z. B. „1 h 05 min“ oder „48 min“.
    static func shortDuration(_ interval: TimeInterval) -> String {
        let minutes = max(Int(interval / 60), 0)
        if minutes >= 60 {
            return String(format: "%d h %02d min", minutes / 60, minutes % 60)
        }
        return "\(minutes) min"
    }

    static func setDescription(weight: Double, reps: Int) -> String {
        weight > 0 ? "\(weight.oneDecimal) kg × \(reps)" : "\(reps) Wdh."
    }
}

/// Parsen von Zahleneingaben – akzeptiert Komma und Punkt als Dezimaltrenner.
enum NumberParsing {
    static func decimal(from text: String) -> Double? {
        let cleaned = text
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty else { return nil }
        return Double(cleaned)
    }

    static func integer(from text: String) -> Int? {
        let cleaned = text.trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty else { return nil }
        return Int(cleaned)
    }

    static func text(for value: Double) -> String {
        value == 0 ? "" : value.formatted(.number.precision(.fractionLength(0...2)).grouping(.never))
    }
}
