import Foundation

/// Entwurf eines Lebensmittels, z. B. aus einem Barcode-Treffer. Wird erst beim Übernehmen gespeichert.
struct FoodDraft: Hashable, Identifiable {
    var name: String = ""
    var brand: String = ""
    var barcode: String = ""
    var per100g = MacroTotals()
    var servingGrams: Double = 100

    var id: String { barcode.isEmpty ? name : barcode }

    /// `true`, wenn zumindest Kalorien bekannt sind.
    var hasNutrition: Bool { per100g.calories > 0 }
}

/// Abfrage der freien Produktdatenbank Open Food Facts (https://world.openfoodfacts.org).
/// Es wird ausschließlich die Barcode-Nummer übertragen; ein Konto ist nicht nötig.
enum OpenFoodFactsClient {
    enum LookupError: LocalizedError {
        case server(Int)

        var errorDescription: String? {
            switch self {
            case .server(let code): "Der Server hat mit Fehler \(code) geantwortet."
            }
        }
    }

    /// Lädt ein Produkt. Gibt `nil` zurück, wenn der Barcode unbekannt ist.
    static func fetchProduct(barcode: String, session: URLSession = .shared) async throws -> FoodDraft? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "world.openfoodfacts.org"
        components.path = "/api/v2/product/\(barcode).json"
        components.queryItems = [
            URLQueryItem(name: "fields", value: "code,product_name,product_name_de,generic_name,brands,nutriments,serving_quantity")
        ]
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("FitTrack/1.0 (iOS)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 404 { return nil }
            guard (200..<300).contains(http.statusCode) else { throw LookupError.server(http.statusCode) }
        }
        return parse(data, barcode: barcode)
    }

    /// Wandelt die JSON-Antwort in einen Entwurf um. Werte gelten pro 100 g.
    static func parse(_ data: Data, barcode: String) -> FoodDraft? {
        guard
            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
            (json["status"] as? NSNumber)?.intValue != 0,
            let product = json["product"] as? [String: Any]
        else { return nil }

        let name = ["product_name_de", "product_name", "generic_name"]
            .compactMap { (product[$0] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        guard let name else { return nil }

        let brand = (product["brands"] as? String)?
            .split(separator: ",")
            .first
            .map { $0.trimmingCharacters(in: .whitespaces) } ?? ""

        let nutriments = product["nutriments"] as? [String: Any] ?? [:]
        func value(_ key: String) -> Double? {
            number(nutriments[key])
        }

        var calories = value("energy-kcal_100g")
        if calories == nil, let kilojoules = value("energy-kj_100g") ?? value("energy_100g") {
            calories = kilojoules / 4.184
        }

        let serving = number(product["serving_quantity"]) ?? 0

        return FoodDraft(
            name: name,
            brand: brand,
            barcode: barcode,
            per100g: MacroTotals(
                calories: (calories ?? 0).rounded(),
                protein: rounded(value("proteins_100g")),
                carbs: rounded(value("carbohydrates_100g")),
                fat: rounded(value("fat_100g"))
            ),
            servingGrams: serving > 0 ? serving.rounded() : 100
        )
    }

    /// Prüft, ob ein Text wie ein Lebensmittel-Barcode aussieht (EAN-8, UPC, EAN-13, ITF-14).
    static func isValidBarcode(_ code: String) -> Bool {
        (8...14).contains(code.count) && code.allSatisfy(\.isNumber)
    }

    private static func number(_ raw: Any?) -> Double? {
        if let number = raw as? NSNumber { return number.doubleValue }
        if let text = raw as? String { return NumberParsing.decimal(from: text) }
        return nil
    }

    private static func rounded(_ value: Double?) -> Double {
        ((value ?? 0) * 10).rounded() / 10
    }
}
