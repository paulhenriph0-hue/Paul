import SwiftUI
import UIKit

/// Zentrales, helles Farb- und Formsystem von FitTrack.
enum Theme {
    static let accent = Color(red: 0.13, green: 0.69, blue: 0.49)
    static let background = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let fieldBackground = Color(uiColor: .tertiarySystemFill)

    static let calories = Color(red: 1.00, green: 0.45, blue: 0.22)
    static let protein = Color(red: 0.93, green: 0.29, blue: 0.45)
    static let carbs = Color(red: 0.24, green: 0.52, blue: 0.96)
    static let fat = Color(red: 0.98, green: 0.71, blue: 0.15)
    static let training = Color(red: 0.42, green: 0.36, blue: 0.95)
    static let weight = Color(red: 0.05, green: 0.62, blue: 0.75)

    static let cornerRadius: CGFloat = 20

    static let accentGradient = LinearGradient(
        colors: [accent, Color(red: 0.09, green: 0.58, blue: 0.72)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

/// Weiße Karte mit weichem Schatten.
struct CardStyle: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 6)
    }
}

/// Hinterlegtes Eingabefeld (z. B. für Gewicht und Wiederholungen).
struct FieldBoxStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.vertical, 7)
            .padding(.horizontal, 8)
            .background(Theme.fieldBackground, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

extension View {
    func cardStyle(padding: CGFloat = 16) -> some View {
        modifier(CardStyle(padding: padding))
    }

    func fieldBox() -> some View {
        modifier(FieldBoxStyle())
    }

    /// Schließt die Tastatur.
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
