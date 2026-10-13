import SwiftData
import XCTest
@testable import FitTrack

final class FitnessMathTests: XCTestCase {
    func testEstimatedOneRepMax() {
        XCTAssertEqual(FitnessMath.estimatedOneRepMax(weight: 100, reps: 1), 100)
        XCTAssertEqual(FitnessMath.estimatedOneRepMax(weight: 100, reps: 10), 133.33, accuracy: 0.01)
        XCTAssertEqual(FitnessMath.estimatedOneRepMax(weight: 0, reps: 10), 0)
        XCTAssertEqual(FitnessMath.estimatedOneRepMax(weight: 80, reps: 0), 0)
    }

    func testBasalMetabolicRate() {
        let male = FitnessMath.basalMetabolicRate(weightKg: 80, heightCm: 180, age: 30, sex: .male)
        XCTAssertEqual(male, 1780, accuracy: 0.001)
        let female = FitnessMath.basalMetabolicRate(weightKg: 60, heightCm: 165, age: 30, sex: .female)
        XCTAssertEqual(female, 1320.25, accuracy: 0.001)
    }

    func testRecommendedCaloriesRoundsToTen() {
        let calories = FitnessMath.recommendedCalories(
            weightKg: 80, heightCm: 180, age: 30, sex: .male, activity: .moderate, goal: .maintain
        )
        XCTAssertEqual(calories, 2760)
        XCTAssertEqual(calories % 10, 0)
    }

    func testRecommendedMacrosMatchCalories() {
        let macros = FitnessMath.recommendedMacros(calories: 2500, weightKg: 80, goal: .gain)
        XCTAssertEqual(macros.protein, 144)
        let total = macros.protein * 4 + macros.carbs * 4 + macros.fat * 9
        XCTAssertEqual(Double(total), 2500, accuracy: 15)
    }

    func testRoundToPlate() {
        XCTAssertEqual(FitnessMath.roundToPlate(71.4), 72.5)
        XCTAssertEqual(FitnessMath.roundToPlate(70.9), 70)
    }

    func testMacroScaling() {
        let per100 = MacroTotals(calories: 200, protein: 10, carbs: 20, fat: 5)
        let scaled = per100.scaled(toGrams: 150)
        XCTAssertEqual(scaled, MacroTotals(calories: 300, protein: 15, carbs: 30, fat: 7.5))
        XCTAssertEqual(per100.scaled(toGrams: -10), .zero)
        XCTAssertEqual(per100.caloriesFromMacros, 165)
    }
}

final class FormattingTests: XCTestCase {
    func testDecimalParsingAcceptsCommaAndDot() {
        XCTAssertEqual(NumberParsing.decimal(from: "82,5"), 82.5)
        XCTAssertEqual(NumberParsing.decimal(from: "82.5"), 82.5)
        XCTAssertEqual(NumberParsing.decimal(from: " 100 "), 100)
        XCTAssertNil(NumberParsing.decimal(from: ""))
        XCTAssertNil(NumberParsing.decimal(from: "abc"))
    }

    func testIntegerParsing() {
        XCTAssertEqual(NumberParsing.integer(from: "12"), 12)
        XCTAssertNil(NumberParsing.integer(from: "1,5"))
    }

    func testDurationFormatting() {
        XCTAssertEqual(Formatters.duration(65), "1:05")
        XCTAssertEqual(Formatters.duration(3725), "1:02:05")
        XCTAssertEqual(Formatters.duration(-5), "0:00")
    }
}

final class OpenFoodFactsTests: XCTestCase {
    private func data(_ json: String) -> Data { Data(json.utf8) }

    func testParsesCompleteProduct() throws {
        let json = """
        {"code":"3017620422003","status":1,"product":{
          "product_name":"Nutella","product_name_de":"Nutella Nuss-Nougat-Creme",
          "brands":"Ferrero, Nutella","serving_quantity":15,
          "nutriments":{"energy-kcal_100g":539,"proteins_100g":6.3,"carbohydrates_100g":57.5,"fat_100g":30.9}}}
        """
        let draft = try XCTUnwrap(OpenFoodFactsClient.parse(data(json), barcode: "3017620422003"))
        XCTAssertEqual(draft.name, "Nutella Nuss-Nougat-Creme")
        XCTAssertEqual(draft.brand, "Ferrero")
        XCTAssertEqual(draft.barcode, "3017620422003")
        XCTAssertEqual(draft.per100g, MacroTotals(calories: 539, protein: 6.3, carbs: 57.5, fat: 30.9))
        XCTAssertEqual(draft.servingGrams, 15)
        XCTAssertTrue(draft.hasNutrition)
    }

    func testConvertsKilojoulesAndStringValues() throws {
        let json = """
        {"status":1,"product":{"product_name":"Testmüsli",
          "nutriments":{"energy_100g":"1590","proteins_100g":"9,5","carbohydrates_100g":60,"fat_100g":6}}}
        """
        let draft = try XCTUnwrap(OpenFoodFactsClient.parse(data(json), barcode: "4000000000001"))
        XCTAssertEqual(draft.per100g.calories, 380)
        XCTAssertEqual(draft.per100g.protein, 9.5)
        XCTAssertEqual(draft.servingGrams, 100)
        XCTAssertEqual(draft.brand, "")
    }

    func testMissingNutritionIsFlagged() throws {
        let json = #"{"status":1,"product":{"product_name":"Unbekannt","nutriments":{}}}"#
        let draft = try XCTUnwrap(OpenFoodFactsClient.parse(data(json), barcode: "12345678"))
        XCTAssertFalse(draft.hasNutrition)
    }

    func testUnknownProductReturnsNil() {
        XCTAssertNil(OpenFoodFactsClient.parse(data(#"{"status":0,"status_verbose":"product not found"}"#), barcode: "12345678"))
        XCTAssertNil(OpenFoodFactsClient.parse(data(#"{"status":1,"product":{"product_name":"  "}}"#), barcode: "12345678"))
        XCTAssertNil(OpenFoodFactsClient.parse(data("kein json"), barcode: "12345678"))
    }

    func testBarcodeValidation() {
        XCTAssertTrue(OpenFoodFactsClient.isValidBarcode("3017620422003"))
        XCTAssertTrue(OpenFoodFactsClient.isValidBarcode("96385074"))
        XCTAssertFalse(OpenFoodFactsClient.isValidBarcode("1234567"))
        XCTAssertFalse(OpenFoodFactsClient.isValidBarcode("ABC12345678"))
        XCTAssertFalse(OpenFoodFactsClient.isValidBarcode(""))
    }
}

@MainActor
final class DataTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() async throws {
        container = try PersistenceController.makeContainer(inMemory: true)
        context = container.mainContext
    }

    override func tearDown() async throws {
        context = nil
        container = nil
    }

    func testSeedingCreatesLibraryOnlyOnce() throws {
        SeedData.seedIfNeeded(in: context)
        SeedData.seedIfNeeded(in: context)

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<UserProfile>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Exercise>()), SeedData.exerciseDefinitions.count)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FoodItem>()), SeedData.foodDefinitions.count)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WorkoutPlan>()), SeedData.planDefinitions.count)

        let plans = try context.fetch(FetchDescriptor<WorkoutPlan>())
        for plan in plans {
            XCTAssertFalse(plan.entries.isEmpty, "Plan \(plan.name) sollte Übungen enthalten")
            XCTAssertTrue(plan.entries.allSatisfy { $0.exercise != nil })
        }
    }

    func testStartWorkoutFromPlanCreatesSets() throws {
        SeedData.seedIfNeeded(in: context)
        let plan = try XCTUnwrap(context.fetch(FetchDescriptor<WorkoutPlan>()).first { $0.name == "Push" })
        let coordinator = WorkoutCoordinator()

        coordinator.startWorkout(plan: plan, in: context)

        let session = try XCTUnwrap(coordinator.presentedSession)
        XCTAssertTrue(session.isActive)
        XCTAssertEqual(session.sets.count, plan.entries.reduce(0) { $0 + $1.targetSets })
        XCTAssertEqual(session.exerciseGroups.count, plan.entries.count)
        XCTAssertEqual(session.exerciseGroups.first?.exercise.name, "Bankdrücken")

        // Ein zweiter Start öffnet das laufende Training, statt ein neues anzulegen.
        coordinator.startWorkout(plan: nil, in: context)
        XCTAssertEqual(coordinator.presentedSession?.persistentModelID, session.persistentModelID)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WorkoutSession>()), 1)
    }

    func testDemoDataProducesAnalytics() throws {
        SeedData.seedIfNeeded(in: context)
        SeedData.loadDemoData(in: context)

        XCTAssertGreaterThan(try context.fetchCount(FetchDescriptor<BodyWeightEntry>()), 50)
        XCTAssertGreaterThan(try context.fetchCount(FetchDescriptor<FoodEntry>()), 20)

        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
        XCTAssertGreaterThan(sessions.count, 20)
        XCTAssertTrue(sessions.allSatisfy { !$0.isActive })

        let bench = try XCTUnwrap(context.fetch(FetchDescriptor<Exercise>()).first { $0.name == "Bankdrücken" })
        let points = Analytics.strengthPoints(for: bench)
        XCTAssertGreaterThan(points.count, 5)
        XCTAssertGreaterThan(points.last?.estimatedOneRepMax ?? 0, points.first?.estimatedOneRepMax ?? 0)

        let weekly = Analytics.weeklyVolume(sessions, weeks: 8)
        XCTAssertEqual(weekly.count, 8)
        XCTAssertGreaterThan(weekly.dropLast().reduce(0) { $0 + $1.volume }, 0)
    }

    func testFoodEntryKeepsValuesAfterFoodDeletion() throws {
        let food = FoodItem(name: "Testbrot", caloriesPer100g: 250, proteinPer100g: 8, carbsPer100g: 45, fatPer100g: 3)
        context.insert(food)
        let entry = FoodEntry(food: food, grams: 200, meal: .breakfast, date: .now)
        context.insert(entry)
        entry.food = food
        try context.save()

        context.delete(food)
        try context.save()

        let entries = try context.fetch(FetchDescriptor<FoodEntry>())
        XCTAssertEqual(entries.count, 1)
        XCTAssertNil(entries.first?.food)
        XCTAssertEqual(entries.first?.macros.calories ?? 0, 500, accuracy: 0.001)
        XCTAssertEqual([entry].totals.protein, 16, accuracy: 0.001)
    }

    func testDailyTotalsGroupsByDay() throws {
        let today = Date().startOfDay.addingTimeInterval(9 * 3600)
        let yesterday = today.adding(days: -1)
        let entries = [
            FoodEntry(quickAddName: "A", totals: MacroTotals(calories: 500, protein: 30, carbs: 50, fat: 10), meal: .lunch, date: today),
            FoodEntry(quickAddName: "B", totals: MacroTotals(calories: 300, protein: 20, carbs: 30, fat: 5), meal: .dinner, date: today),
            FoodEntry(quickAddName: "C", totals: MacroTotals(calories: 700, protein: 40, carbs: 60, fat: 20), meal: .lunch, date: yesterday)
        ]
        entries.forEach { context.insert($0) }

        let daily = Analytics.dailyTotals(entries, days: 3, now: today)
        XCTAssertEqual(daily.count, 3)
        XCTAssertEqual(daily[2].totals.calories, 800, accuracy: 0.001)
        XCTAssertEqual(daily[1].totals.calories, 700, accuracy: 0.001)
        XCTAssertEqual(daily[0].totals.calories, 0, accuracy: 0.001)
    }
}
