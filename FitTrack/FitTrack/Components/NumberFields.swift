import SwiftUI
import UIKit

/// Eingabefeld für Dezimalzahlen. Aktualisiert den Wert sofort beim Tippen
/// und akzeptiert Komma sowie Punkt als Dezimaltrenner.
struct DecimalField: View {
    let placeholder: String
    @Binding var value: Double
    var alignment: TextAlignment = .center

    @State private var text = ""
    @FocusState private var isFocused: Bool

    init(_ placeholder: String, value: Binding<Double>, alignment: TextAlignment = .center) {
        self.placeholder = placeholder
        self._value = value
        self.alignment = alignment
    }

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(alignment)
            .monospacedDigit()
            .focused($isFocused)
            .onAppear { text = NumberParsing.text(for: value) }
            .onChange(of: text) { _, newText in
                if let parsed = NumberParsing.decimal(from: newText) {
                    if parsed != value { value = max(parsed, 0) }
                } else if newText.trimmingCharacters(in: .whitespaces).isEmpty, value != 0 {
                    value = 0
                }
            }
            .onChange(of: value) { _, newValue in
                guard !isFocused, NumberParsing.decimal(from: text) != newValue else { return }
                text = NumberParsing.text(for: newValue)
            }
    }
}

/// Eingabefeld für ganze Zahlen (z. B. Wiederholungen oder Kalorien).
struct IntegerField: View {
    let placeholder: String
    @Binding var value: Int
    var alignment: TextAlignment = .center

    @State private var text = ""
    @FocusState private var isFocused: Bool

    init(_ placeholder: String, value: Binding<Int>, alignment: TextAlignment = .center) {
        self.placeholder = placeholder
        self._value = value
        self.alignment = alignment
    }

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(.numberPad)
            .multilineTextAlignment(alignment)
            .monospacedDigit()
            .focused($isFocused)
            .onAppear { text = value == 0 ? "" : String(value) }
            .onChange(of: text) { _, newText in
                if let parsed = NumberParsing.integer(from: newText) {
                    if parsed != value { value = max(parsed, 0) }
                } else if newText.trimmingCharacters(in: .whitespaces).isEmpty, value != 0 {
                    value = 0
                }
            }
            .onChange(of: value) { _, newValue in
                guard !isFocused, NumberParsing.integer(from: text) != newValue else { return }
                text = newValue == 0 ? "" : String(newValue)
            }
    }
}

/// Formularzeile mit Beschriftung, Zahlenfeld und Einheit.
struct NumberInputRow: View {
    let title: String
    @Binding var value: Double
    let unit: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            DecimalField("0", value: $value, alignment: .trailing)
                .frame(width: 90)
                .fieldBox()
            Text(unit)
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .leading)
        }
    }
}

struct IntegerInputRow: View {
    let title: String
    @Binding var value: Int
    let unit: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            IntegerField("0", value: $value, alignment: .trailing)
                .frame(width: 90)
                .fieldBox()
            Text(unit)
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .leading)
        }
    }
}
