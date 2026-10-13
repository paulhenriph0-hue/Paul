import Foundation
import SwiftData

/// Startdaten (Übungen, Lebensmittel, Pläne) und optionale Demo-Daten.
enum SeedData {
    // MARK: - Startdaten

    /// Legt beim ersten Start Profil, Übungen, Lebensmittel und Trainingspläne an.
    static func seedIfNeeded(in context: ModelContext) {
        let profileCount = (try? context.fetchCount(FetchDescriptor<UserProfile>())) ?? 0
        guard profileCount == 0 else { return }
        context.insert(UserProfile())
        seedLibrary(in: context)
        context.saveIfNeeded()
    }

    /// Fügt Standardübungen, -lebensmittel und -pläne hinzu.
    static func seedLibrary(in context: ModelContext) {
        var exercisesByName: [String: Exercise] = [:]
        for (name, group) in exerciseDefinitions {
            let exercise = Exercise(name: name, muscleGroup: group)
            context.insert(exercise)
            exercisesByName[name] = exercise
        }

        for food in foodDefinitions {
            context.insert(FoodItem(
                name: food.name,
                brand: food.brand,
                caloriesPer100g: food.kcal,
                proteinPer100g: food.protein,
                carbsPer100g: food.carbs,
                fatPer100g: food.fat,
                servingGrams: food.serving
            ))
        }

        for template in planDefinitions {
            let plan = WorkoutPlan(name: template.name, notes: template.notes)
            context.insert(plan)
            for (index, item) in template.exercises.enumerated() {
                guard let exercise = exercisesByName[item.name] else { continue }
                let entry = PlanExercise(sortIndex: index, targetSets: item.sets, targetReps: item.reps)
                context.insert(entry)
                entry.exercise = exercise
                plan.entries.append(entry)
            }
        }
    }

    /// Setzt alle Daten zurück, behält aber das (zurückgesetzte) Profilobjekt.
    static func resetAllData(in context: ModelContext) {
        context.deleteAll(WorkoutSession.self)
        context.deleteAll(WorkoutPlan.self)
        context.deleteAll(Exercise.self)
        context.deleteAll(FoodEntry.self)
        context.deleteAll(FoodItem.self)
        context.deleteAll(BodyWeightEntry.self)
        context.saveIfNeeded()

        let profiles = (try? context.fetch(FetchDescriptor<UserProfile>())) ?? []
        if let profile = profiles.first {
            profile.resetToDefaults()
        } else {
            context.insert(UserProfile())
        }
        seedLibrary(in: context)
        context.saveIfNeeded()
    }

    // MARK: - Demo-Daten

    /// Erzeugt realistische Beispieldaten (Gewicht, Trainings, Ernährung),
    /// damit Diagramme und Auswertungen sofort ausprobiert werden können.
    /// Ersetzt vorhandene Trainings-, Gewichts- und Ernährungseinträge.
    static func loadDemoData(in context: ModelContext, now: Date = .now) {
        context.deleteAll(WorkoutSession.self)
        context.deleteAll(BodyWeightEntry.self)
        context.deleteAll(FoodEntry.self)
        context.saveIfNeeded()

        var rng = SeededGenerator(seed: 2024)

        // Körpergewicht: 120 Tage, langsamer Abwärtstrend mit natürlichen Schwankungen.
        for daysAgo in stride(from: 120, through: 0, by: -1) {
            if daysAgo > 0 && Double.random(in: 0...1, using: &rng) < 0.3 { continue }
            let progress = Double(120 - daysAgo) / 120
            let noise = sin(Double(daysAgo) / 4) * 0.35 + Double.random(in: -0.3...0.3, using: &rng)
            let weight = 84.5 - 4.2 * progress + noise
            let date = now.startOfDay.adding(days: -daysAgo).addingTimeInterval(7 * 3600 + 15 * 60)
            guard date <= now else { continue }
            context.insert(BodyWeightEntry(date: date, weightKg: (weight * 10).rounded() / 10))
        }

        // Trainings: 10 Wochen Push/Pull/Beine an Mo/Mi/Fr mit progressiver Steigerung.
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        let exercisesByName = Dictionary(exercises.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        let plans = (try? context.fetch(FetchDescriptor<WorkoutPlan>())) ?? []
        let plansByName = Dictionary(plans.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })

        let templates: [(name: String, items: [(String, Double, Int, Int)])] = [
            ("Push", [
                ("Bankdrücken", 70, 8, 4),
                ("Schrägbankdrücken (Kurzhantel)", 26, 10, 3),
                ("Schulterdrücken", 40, 10, 3),
                ("Seitheben", 10, 15, 3),
                ("Trizepsdrücken am Kabel", 25, 12, 3)
            ]),
            ("Pull", [
                ("Kreuzheben", 110, 5, 3),
                ("Klimmzüge", 0, 8, 3),
                ("Kabelrudern sitzend", 55, 10, 3),
                ("Face Pulls", 20, 15, 3),
                ("Bizepscurls (Langhantel)", 30, 12, 3)
            ]),
            ("Beine", [
                ("Kniebeugen", 90, 8, 4),
                ("Rumänisches Kreuzheben", 70, 10, 3),
                ("Beinpresse", 160, 12, 3),
                ("Beinbeuger", 40, 12, 3),
                ("Wadenheben", 60, 15, 4)
            ])
        ]

        var templateIndex = 0
        for weeksAgo in stride(from: 9, through: 0, by: -1) {
            for dayOffset in [0, 2, 4] {
                let date = now.startOfWeek.adding(weeks: -weeksAgo).adding(days: dayOffset).addingTimeInterval(18 * 3600)
                guard date < now.addingTimeInterval(-3600) else { continue }
                let template = templates[templateIndex % templates.count]
                templateIndex += 1

                let progression = 1 + Double(9 - weeksAgo) * 0.02
                let duration = Double.random(in: 3000...4500, using: &rng)
                let session = WorkoutSession(name: template.name, startDate: date, endDate: date.addingTimeInterval(duration))
                context.insert(session)
                session.plan = plansByName[template.name]

                var index = 0
                for (name, baseWeight, reps, setCount) in template.items {
                    guard let exercise = exercisesByName[name] else { continue }
                    let weight = baseWeight > 0 ? FitnessMath.roundToPlate(baseWeight * progression) : 0
                    for setNumber in 0..<setCount {
                        let fatigue = setNumber == setCount - 1 ? Int.random(in: 0...2, using: &rng) : 0
                        let set = WorkoutSet(
                            sortIndex: index,
                            reps: max(reps - fatigue, 1),
                            weight: weight,
                            isCompleted: true,
                            completedAt: date.addingTimeInterval(Double(index) * 150)
                        )
                        context.insert(set)
                        set.exercise = exercise
                        session.sets.append(set)
                        index += 1
                    }
                }
            }
        }

        // Ernährung: die letzten 14 Tage.
        let foods = (try? context.fetch(FetchDescriptor<FoodItem>())) ?? []
        let foodsByName = Dictionary(foods.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })

        let mealOptions: [MealType: [[(String, Double)]]] = [
            .breakfast: [
                [("Haferflocken", 80), ("Vollmilch (3,5 %)", 250), ("Banane", 120)],
                [("Skyr natur", 250), ("Blaubeeren", 100), ("Müsli (Früchte)", 50)],
                [("Vollkornbrot", 100), ("Hühnerei", 120), ("Gouda", 30)]
            ],
            .lunch: [
                [("Hähnchenbrust (gegart)", 160), ("Reis (gekocht)", 220), ("Brokkoli", 150)],
                [("Nudeln (gekocht)", 250), ("Rinderhack (5 % Fett)", 125), ("Tomate", 150)],
                [("Linsen (gekocht)", 200), ("Süßkartoffel (gekocht)", 200), ("Olivenöl", 10)]
            ],
            .dinner: [
                [("Lachs", 125), ("Kartoffeln (gekocht)", 250), ("Gurke", 150)],
                [("Vollkornbrot", 120), ("Hüttenkäse", 200), ("Paprika (rot)", 150)],
                [("Tofu natur", 200), ("Reis (gekocht)", 200), ("Brokkoli", 200)]
            ],
            .snack: [
                [("Whey-Protein (Pulver)", 30), ("Apfel", 150)],
                [("Magerquark", 250), ("Mandeln", 25)],
                [("Proteinriegel", 60)]
            ]
        ]
        let mealHours: [MealType: Double] = [.breakfast: 7.5, .lunch: 12.5, .dinner: 19, .snack: 16]

        for daysAgo in 0..<14 {
            let day = now.startOfDay.adding(days: -daysAgo)
            for meal in MealType.allCases {
                let date = day.addingTimeInterval((mealHours[meal] ?? 12) * 3600)
                guard date <= now, let options = mealOptions[meal], let choice = options.randomElement(using: &rng) else { continue }
                for (foodName, grams) in choice {
                    guard let food = foodsByName[foodName] else { continue }
                    let amount = (grams * Double.random(in: 0.85...1.15, using: &rng)).rounded()
                    let entry = FoodEntry(food: food, grams: amount, meal: meal, date: date)
                    context.insert(entry)
                    entry.food = food
                }
            }
        }

        context.saveIfNeeded()
    }

    // MARK: - Definitionen

    static let exerciseDefinitions: [(String, MuscleGroup)] = [
        ("Bankdrücken", .chest),
        ("Schrägbankdrücken (Kurzhantel)", .chest),
        ("Butterfly", .chest),
        ("Liegestütze", .chest),
        ("Dips", .chest),
        ("Kreuzheben", .back),
        ("Klimmzüge", .back),
        ("Langhantelrudern", .back),
        ("Latzug", .back),
        ("Kabelrudern sitzend", .back),
        ("Schulterdrücken", .shoulders),
        ("Seitheben", .shoulders),
        ("Face Pulls", .shoulders),
        ("Reverse Butterfly", .shoulders),
        ("Bizepscurls (Langhantel)", .biceps),
        ("Hammercurls", .biceps),
        ("Konzentrationscurls", .biceps),
        ("Trizepsdrücken am Kabel", .triceps),
        ("French Press", .triceps),
        ("Overhead-Trizepsstrecken", .triceps),
        ("Kniebeugen", .legs),
        ("Beinpresse", .legs),
        ("Ausfallschritte", .legs),
        ("Beinstrecker", .legs),
        ("Beinbeuger", .legs),
        ("Wadenheben", .legs),
        ("Rumänisches Kreuzheben", .glutes),
        ("Hip Thrust", .glutes),
        ("Bulgarian Split Squats", .glutes),
        ("Crunches", .core),
        ("Hängendes Beinheben", .core),
        ("Cable Crunches", .core),
        ("Russian Twists", .core),
        ("Kettlebell Swings", .fullBody),
        ("Burpees", .fullBody),
        ("Thrusters", .fullBody)
    ]

    struct FoodSeed {
        let name: String
        var brand: String = ""
        let kcal: Double
        let protein: Double
        let carbs: Double
        let fat: Double
        var serving: Double = 100
    }

    /// Durchschnittliche Nährwerte pro 100 g (Richtwerte).
    static let foodDefinitions: [FoodSeed] = [
        FoodSeed(name: "Haferflocken", kcal: 372, protein: 13.5, carbs: 58.7, fat: 7.0, serving: 60),
        FoodSeed(name: "Müsli (Früchte)", kcal: 360, protein: 9, carbs: 65, fat: 6, serving: 60),
        FoodSeed(name: "Cornflakes", kcal: 357, protein: 7.5, carbs: 84, fat: 0.4, serving: 40),
        FoodSeed(name: "Vollkornbrot", kcal: 220, protein: 7.5, carbs: 39, fat: 1.8, serving: 50),
        FoodSeed(name: "Weizenbrötchen", kcal: 270, protein: 9, carbs: 53, fat: 1.5, serving: 60),
        FoodSeed(name: "Reis (gekocht)", kcal: 130, protein: 2.7, carbs: 28, fat: 0.3, serving: 200),
        FoodSeed(name: "Nudeln (gekocht)", kcal: 158, protein: 5.8, carbs: 31, fat: 0.9, serving: 200),
        FoodSeed(name: "Kartoffeln (gekocht)", kcal: 77, protein: 2, carbs: 17, fat: 0.1, serving: 250),
        FoodSeed(name: "Süßkartoffel (gekocht)", kcal: 86, protein: 1.6, carbs: 20, fat: 0.1, serving: 200),
        FoodSeed(name: "Vollmilch (3,5 %)", kcal: 64, protein: 3.3, carbs: 4.8, fat: 3.5, serving: 250),
        FoodSeed(name: "Magerquark", kcal: 67, protein: 12, carbs: 4, fat: 0.3, serving: 250),
        FoodSeed(name: "Skyr natur", kcal: 63, protein: 11, carbs: 4, fat: 0.2, serving: 150),
        FoodSeed(name: "Griechischer Joghurt (10 %)", kcal: 130, protein: 4.5, carbs: 4, fat: 10, serving: 150),
        FoodSeed(name: "Hüttenkäse", kcal: 98, protein: 11, carbs: 3.4, fat: 4.3, serving: 200),
        FoodSeed(name: "Gouda", kcal: 356, protein: 25, carbs: 2.2, fat: 27, serving: 30),
        FoodSeed(name: "Mozzarella", kcal: 253, protein: 18, carbs: 1, fat: 19, serving: 125),
        FoodSeed(name: "Hühnerei", kcal: 155, protein: 13, carbs: 1.1, fat: 11, serving: 60),
        FoodSeed(name: "Hähnchenbrust (gegart)", kcal: 165, protein: 31, carbs: 0, fat: 3.6, serving: 150),
        FoodSeed(name: "Rinderhack (5 % Fett)", kcal: 137, protein: 21, carbs: 0, fat: 5.5, serving: 125),
        FoodSeed(name: "Lachs", kcal: 208, protein: 20, carbs: 0, fat: 13, serving: 125),
        FoodSeed(name: "Thunfisch (im eigenen Saft)", kcal: 116, protein: 26, carbs: 0, fat: 1, serving: 130),
        FoodSeed(name: "Tofu natur", kcal: 120, protein: 13, carbs: 2, fat: 7, serving: 200),
        FoodSeed(name: "Linsen (gekocht)", kcal: 116, protein: 9, carbs: 20, fat: 0.4, serving: 200),
        FoodSeed(name: "Brokkoli", kcal: 34, protein: 2.8, carbs: 7, fat: 0.4, serving: 150),
        FoodSeed(name: "Tomate", kcal: 18, protein: 0.9, carbs: 3.9, fat: 0.2, serving: 100),
        FoodSeed(name: "Gurke", kcal: 15, protein: 0.7, carbs: 3.6, fat: 0.1, serving: 150),
        FoodSeed(name: "Paprika (rot)", kcal: 31, protein: 1, carbs: 6, fat: 0.3, serving: 150),
        FoodSeed(name: "Eisbergsalat", kcal: 14, protein: 0.9, carbs: 3, fat: 0.1, serving: 100),
        FoodSeed(name: "Avocado", kcal: 160, protein: 2, carbs: 8.5, fat: 14.7, serving: 80),
        FoodSeed(name: "Banane", kcal: 89, protein: 1.1, carbs: 22.8, fat: 0.3, serving: 120),
        FoodSeed(name: "Apfel", kcal: 52, protein: 0.3, carbs: 13.8, fat: 0.2, serving: 150),
        FoodSeed(name: "Blaubeeren", kcal: 57, protein: 0.7, carbs: 14.5, fat: 0.3, serving: 125),
        FoodSeed(name: "Olivenöl", kcal: 884, protein: 0, carbs: 0, fat: 100, serving: 10),
        FoodSeed(name: "Butter", kcal: 717, protein: 0.9, carbs: 0.1, fat: 81, serving: 10),
        FoodSeed(name: "Erdnussbutter", kcal: 588, protein: 25, carbs: 20, fat: 50, serving: 20),
        FoodSeed(name: "Mandeln", kcal: 579, protein: 21, carbs: 22, fat: 50, serving: 30),
        FoodSeed(name: "Walnüsse", kcal: 654, protein: 15, carbs: 14, fat: 65, serving: 30),
        FoodSeed(name: "Whey-Protein (Pulver)", kcal: 380, protein: 78, carbs: 6, fat: 5, serving: 30),
        FoodSeed(name: "Proteinriegel", kcal: 360, protein: 33, carbs: 30, fat: 12, serving: 60),
        FoodSeed(name: "Zartbitterschokolade (70 %)", kcal: 598, protein: 7.8, carbs: 46, fat: 43, serving: 20),
        FoodSeed(name: "Honig", kcal: 304, protein: 0.3, carbs: 82, fat: 0, serving: 20),
        FoodSeed(name: "Pizza Margherita", kcal: 266, protein: 11, carbs: 33, fat: 10, serving: 350),
        FoodSeed(name: "Orangensaft", kcal: 45, protein: 0.7, carbs: 10, fat: 0.2, serving: 250),
        FoodSeed(name: "Cola", kcal: 42, protein: 0, carbs: 10.6, fat: 0, serving: 330),
        FoodSeed(name: "Bier", kcal: 43, protein: 0.5, carbs: 3.6, fat: 0, serving: 500)
    ]

    struct PlanSeed {
        let name: String
        let notes: String
        let exercises: [(name: String, sets: Int, reps: Int)]
    }

    static let planDefinitions: [PlanSeed] = [
        PlanSeed(name: "Ganzkörper", notes: "Ideal für 2–3 Einheiten pro Woche.", exercises: [
            ("Kniebeugen", 3, 8),
            ("Bankdrücken", 3, 8),
            ("Langhantelrudern", 3, 10),
            ("Schulterdrücken", 3, 10),
            ("Crunches", 3, 15)
        ]),
        PlanSeed(name: "Push", notes: "Brust, Schultern, Trizeps", exercises: [
            ("Bankdrücken", 4, 8),
            ("Schrägbankdrücken (Kurzhantel)", 3, 10),
            ("Schulterdrücken", 3, 10),
            ("Seitheben", 3, 15),
            ("Trizepsdrücken am Kabel", 3, 12)
        ]),
        PlanSeed(name: "Pull", notes: "Rücken, hintere Schulter, Bizeps", exercises: [
            ("Kreuzheben", 3, 5),
            ("Klimmzüge", 3, 8),
            ("Kabelrudern sitzend", 3, 10),
            ("Face Pulls", 3, 15),
            ("Bizepscurls (Langhantel)", 3, 12)
        ]),
        PlanSeed(name: "Beine", notes: "Quadrizeps, Beinbeuger, Gesäß, Waden", exercises: [
            ("Kniebeugen", 4, 8),
            ("Rumänisches Kreuzheben", 3, 10),
            ("Beinpresse", 3, 12),
            ("Beinbeuger", 3, 12),
            ("Wadenheben", 4, 15)
        ])
    ]
}

/// Reproduzierbarer Zufallsgenerator (SplitMix64) für Demo-Daten.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
