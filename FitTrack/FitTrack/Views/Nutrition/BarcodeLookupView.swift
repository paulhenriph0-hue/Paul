import AVFoundation
import SwiftData
import SwiftUI

/// Barcode scannen (oder eintippen), Lebensmittel finden und zur Mahlzeit hinzufügen.
/// Reihenfolge der Suche: eigene Lebensmittel → Open Food Facts → manuell anlegen.
struct BarcodeLookupView: View {
    let meal: MealType
    let date: Date
    let onSaved: () -> Void

    private enum CameraState {
        case checking, ready, denied, unsupported
    }

    private enum LookupState {
        case scanning
        case loading(String)
        case local(FoodItem)
        case remote(FoodDraft)
        case notFound(String)
        case failed(String, String)
    }

    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @Query(sort: \FoodItem.name) private var foods: [FoodItem]

    @State private var cameraState: CameraState = .checking
    @State private var state: LookupState = .scanning
    @State private var manualCode = ""
    @State private var scanCount = 0
    @State private var selectedFood: FoodItem?
    @State private var editorDraft: FoodDraft?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                switch state {
                case .scanning:
                    scannerArea
                    manualEntryCard
                case .loading(let code):
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Suche Produkt \(code) …")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 160)
                    .cardStyle()
                case .local(let food):
                    localResultCard(food)
                case .remote(let draft):
                    remoteResultCard(draft)
                case .notFound(let code):
                    notFoundCard(code)
                case .failed(let code, let message):
                    failedCard(code: code, message: message)
                }

                Text("Barcodes werden zuerst in deinen eigenen Lebensmitteln gesucht. Ist dort nichts hinterlegt, fragt FitTrack die freie Datenbank Open Food Facts ab. Dabei wird nur die Barcode-Nummer übertragen. Gespeichert wird alles lokal.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Barcode scannen")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedFood) { food in
            AddFoodEntryView(food: food, meal: meal, date: date, onSaved: onSaved)
        }
        .navigationDestination(item: $editorDraft) { draft in
            FoodEditorView(food: nil, draft: draft) { saved in
                editorDraft = nil
                state = .local(saved)
            }
        }
        .task { await prepareCamera() }
        .sensoryFeedback(.success, trigger: scanCount)
    }

    // MARK: - Scanner

    @ViewBuilder
    private var scannerArea: some View {
        switch cameraState {
        case .checking:
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 300)
                .cardStyle()
        case .ready:
            BarcodeScannerView { code in
                scanCount += 1
                lookup(code)
            }
            .frame(height: 340)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .overlay(alignment: .bottom) {
                Label("Barcode in die Kamera halten", systemImage: "barcode.viewfinder")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 14)
            }
        case .denied:
            ContentUnavailableView {
                Label("Kein Kamerazugriff", systemImage: "camera.fill")
            } description: {
                Text("Erlaube FitTrack den Zugriff auf die Kamera oder gib den Barcode unten ein.")
            } actions: {
                Button("Einstellungen öffnen") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .cardStyle()
        case .unsupported:
            ContentUnavailableView(
                "Kamera-Scanner nicht verfügbar",
                systemImage: "barcode.viewfinder",
                description: Text("Dieses Gerät unterstützt den Live-Scanner nicht (z. B. der Simulator). Gib den Barcode einfach unten ein.")
            )
            .cardStyle()
        }
    }

    private var manualEntryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            CardHeader(title: "Barcode eingeben", symbol: "keyboard", color: Theme.carbs)
            HStack {
                TextField("z. B. 3017620422003", text: $manualCode)
                    .keyboardType(.numberPad)
                    .monospacedDigit()
                    .fieldBox()
                Button("Suchen") {
                    hideKeyboard()
                    lookup(manualCode)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!OpenFoodFactsClient.isValidBarcode(cleaned(manualCode)))
            }
            Text("Die Nummer steht unter den Strichen des Barcodes (8–14 Ziffern).")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .cardStyle()
    }

    // MARK: - Ergebnisse

    private func localResultCard(_ food: FoodItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("In deinen Lebensmitteln gefunden", systemImage: "checkmark.seal.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accent)
            FoodItemRow(food: food)
            Button {
                selectedFood = food
            } label: {
                Label("Zu \(meal.displayName) hinzufügen", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            rescanButton
        }
        .cardStyle()
    }

    private func remoteResultCard(_ draft: FoodDraft) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Gefunden bei Open Food Facts", systemImage: "globe")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.carbs)

            VStack(alignment: .leading, spacing: 2) {
                Text(draft.name)
                    .font(.title3.weight(.bold))
                Text([draft.brand, draft.barcode].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Nährwerte pro 100 g")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            MacroBreakdownView(macros: draft.per100g)

            if !draft.hasNutrition {
                Label("Für dieses Produkt sind keine vollständigen Nährwerte hinterlegt. Bitte ergänze sie.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Button {
                selectedFood = save(draft)
            } label: {
                Label("Übernehmen und hinzufügen", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!draft.hasNutrition)

            Button {
                editorDraft = draft
            } label: {
                Label("Werte prüfen und bearbeiten", systemImage: "pencil")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            rescanButton
        }
        .cardStyle()
    }

    private func notFoundCard(_ code: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ContentUnavailableView(
                "Produkt nicht gefunden",
                systemImage: "questionmark.square.dashed",
                description: Text("Zum Barcode \(code) gibt es noch keinen Eintrag. Lege das Lebensmittel einmal an. Beim nächsten Scan wird es dann sofort erkannt.")
            )
            Button {
                editorDraft = FoodDraft(barcode: code)
            } label: {
                Label("Lebensmittel anlegen", systemImage: "plus.square.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            rescanButton
        }
        .cardStyle()
    }

    private func failedCard(code: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ContentUnavailableView(
                "Abfrage fehlgeschlagen",
                systemImage: "wifi.exclamationmark",
                description: Text(message)
            )
            if OpenFoodFactsClient.isValidBarcode(code) {
                Button {
                    lookup(code)
                } label: {
                    Label("Erneut versuchen", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                Button {
                    editorDraft = FoodDraft(barcode: code)
                } label: {
                    Label("Manuell anlegen", systemImage: "square.and.pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            rescanButton
        }
        .cardStyle()
    }

    private var rescanButton: some View {
        Button {
            manualCode = ""
            state = .scanning
        } label: {
            Label("Anderen Barcode scannen", systemImage: "barcode.viewfinder")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }

    // MARK: - Logik

    private func cleaned(_ code: String) -> String {
        code.filter { !$0.isWhitespace }
    }

    private func lookup(_ rawCode: String) {
        let code = cleaned(rawCode)
        guard OpenFoodFactsClient.isValidBarcode(code) else {
            state = .failed(code, "„\(code)“ ist kein Lebensmittel-Barcode. Erwartet werden 8 bis 14 Ziffern (EAN/UPC).")
            return
        }

        if let local = foods.first(where: { $0.barcode == code }) {
            state = .local(local)
            return
        }

        state = .loading(code)
        Task {
            do {
                if let draft = try await OpenFoodFactsClient.fetchProduct(barcode: code) {
                    state = .remote(draft)
                } else {
                    state = .notFound(code)
                }
            } catch {
                state = .failed(code, "Keine Verbindung zu Open Food Facts. Prüfe deine Internetverbindung oder lege das Lebensmittel manuell an.")
            }
        }
    }

    /// Speichert den Entwurf als eigenes Lebensmittel (oder nutzt ein vorhandenes mit gleichem Barcode).
    private func save(_ draft: FoodDraft) -> FoodItem {
        if let existing = foods.first(where: { $0.barcode == draft.barcode && !draft.barcode.isEmpty }) {
            return existing
        }
        let food = FoodItem(
            name: draft.name,
            brand: draft.brand,
            caloriesPer100g: draft.per100g.calories,
            proteinPer100g: draft.per100g.protein,
            carbsPer100g: draft.per100g.carbs,
            fatPer100g: draft.per100g.fat,
            servingGrams: draft.servingGrams,
            isCustom: true,
            barcode: draft.barcode
        )
        context.insert(food)
        context.saveIfNeeded()
        return food
    }

    private func prepareCamera() async {
        guard BarcodeScannerView.isSupported else {
            cameraState = .unsupported
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraState = .ready
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            cameraState = granted ? .ready : .denied
        default:
            cameraState = .denied
        }
    }
}
