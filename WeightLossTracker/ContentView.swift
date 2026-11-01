import SwiftUI
import UIKit
import Combine
import UserNotifications
import AVFoundation
import AudioToolbox
import HealthKit

// MARK: - Models

enum WeightUnit: String, CaseIterable, Identifiable {
    case kg
    case lb

    var id: String { rawValue }

    var title: String {
        switch self {
        case .kg: return "kg"
        case .lb: return "lbs"
        }
    }
}

struct WeightLog: Identifiable, Codable {
    var id: UUID
    var date: Date
    var weightKg: Double
    var photoFileName: String?
    var additionalPhotos: [String: String] = [:]

    enum CodingKeys: String, CodingKey {
        case id, date, weightKg, photoFileName, additionalPhotos
    }

    init(id: UUID, date: Date, weightKg: Double, photoFileName: String? = nil, additionalPhotos: [String: String] = [:]) {
        self.id = id
        self.date = date
        self.weightKg = weightKg
        self.photoFileName = photoFileName
        self.additionalPhotos = additionalPhotos
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        weightKg = try container.decode(Double.self, forKey: .weightKg)
        photoFileName = try container.decodeIfPresent(String.self, forKey: .photoFileName)
        additionalPhotos = try container.decodeIfPresent([String: String].self, forKey: .additionalPhotos) ?? [:]
    }
}

struct FoodLog: Identifiable, Codable {
    var id: UUID
    var date: Date
    var calories: Int
    var protein: Int? = nil
    var carbs: Int? = nil
    var fat: Int? = nil
    var name: String?
}

struct PhysiqueScan: Identifiable, Codable {
    var id: UUID
    var date: Date
    var photoFileName: String
    var weightKg: Double
    var sex: String
    var bodyFat: Double
    var low: Double
    var high: Double
    var summary: String
    var cues: [String]
    var generated: [String: String] = [:]

    enum CodingKeys: String, CodingKey {
        case id, date, photoFileName, weightKg, sex, bodyFat, low, high, summary, cues, generated
    }

    init(id: UUID, date: Date, photoFileName: String, weightKg: Double, sex: String, bodyFat: Double, low: Double, high: Double, summary: String, cues: [String], generated: [String: String] = [:]) {
        self.id = id
        self.date = date
        self.photoFileName = photoFileName
        self.weightKg = weightKg
        self.sex = sex
        self.bodyFat = bodyFat
        self.low = low
        self.high = high
        self.summary = summary
        self.cues = cues
        self.generated = generated
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        photoFileName = try container.decode(String.self, forKey: .photoFileName)
        weightKg = try container.decode(Double.self, forKey: .weightKg)
        sex = try container.decode(String.self, forKey: .sex)
        bodyFat = try container.decode(Double.self, forKey: .bodyFat)
        low = try container.decode(Double.self, forKey: .low)
        high = try container.decode(Double.self, forKey: .high)
        summary = try container.decode(String.self, forKey: .summary)
        cues = try container.decodeIfPresent([String].self, forKey: .cues) ?? []
        generated = try container.decodeIfPresent([String: String].self, forKey: .generated) ?? [:]
    }
}

enum Meal: String, Codable, CaseIterable, Identifiable {
    case breakfast, lunch, dinner, snack

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var icon: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.stars.fill"
        case .snack: return "carrot.fill"
        }
    }
}

struct FoodEntry: Identifiable, Codable {
    var id: UUID
    var date: Date
    var name: String
    var calories: Int
    var meal: Meal
}

struct BodyFatLog: Identifiable, Codable {
    var id: UUID
    var date: Date
    var percent: Double
}

struct WaistLog: Identifiable, Codable {
    var id: UUID
    var date: Date
    var cm: Double
}

struct Milestone: Codable, Identifiable {
    var id: Int { week }
    var week: Int
    var weight: Double
    var bodyFat: Double
    var waist: Double
    var focus: String?

    enum CodingKeys: String, CodingKey { case week, weight, bodyFat, waist, focus }

    init(week: Int, weight: Double, bodyFat: Double, waist: Double, focus: String?) {
        self.week = week
        self.weight = weight
        self.bodyFat = bodyFat
        self.waist = waist
        self.focus = focus
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        week = Int(try c.decode(Double.self, forKey: .week))
        weight = try c.decode(Double.self, forKey: .weight)
        bodyFat = try c.decode(Double.self, forKey: .bodyFat)
        waist = try c.decode(Double.self, forKey: .waist)
        focus = try c.decodeIfPresent(String.self, forKey: .focus)
    }
}

struct RoadmapPlan: Codable {
    var summary: String
    var goalWeight: Double
    var totalWeeks: Int
    var dailyCalories: Int
    var dailySteps: Int
    var proteinGrams: Int
    var milestones: [Milestone]
    var tips: [String]

    enum CodingKeys: String, CodingKey { case summary, goalWeight, totalWeeks, dailyCalories, dailySteps, proteinGrams, milestones, tips }

    init(summary: String, goalWeight: Double, totalWeeks: Int, dailyCalories: Int, dailySteps: Int, proteinGrams: Int, milestones: [Milestone], tips: [String]) {
        self.summary = summary
        self.goalWeight = goalWeight
        self.totalWeeks = totalWeeks
        self.dailyCalories = dailyCalories
        self.dailySteps = dailySteps
        self.proteinGrams = proteinGrams
        self.milestones = milestones
        self.tips = tips
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        summary = try c.decodeIfPresent(String.self, forKey: .summary) ?? ""
        goalWeight = try c.decode(Double.self, forKey: .goalWeight)
        milestones = try c.decode([Milestone].self, forKey: .milestones)
        totalWeeks = Int(try c.decodeIfPresent(Double.self, forKey: .totalWeeks) ?? Double(milestones.count))
        dailyCalories = Int(try c.decode(Double.self, forKey: .dailyCalories))
        dailySteps = Int(try c.decode(Double.self, forKey: .dailySteps))
        proteinGrams = Int(try c.decode(Double.self, forKey: .proteinGrams))
        tips = try c.decodeIfPresent([String].self, forKey: .tips) ?? []
    }
}

struct Roadmap: Codable {
    var createdAt: Date
    var weightUnit: String
    var waistUnit: String
    var startWeight: Double
    var startBodyFat: Double
    var goalBodyFat: Double
    var startWaist: Double
    var plan: RoadmapPlan

    /// Plan weeks run Sunday–Saturday; week 1 is the calendar week the plan was created in.
    func weekStart(_ week: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: (week - 1) * 7, to: sundayOnOrBefore(createdAt)) ?? createdAt
    }

    func currentWeek(at date: Date = Date()) -> Int {
        let days = Calendar.current.dateComponents([.day], from: sundayOnOrBefore(createdAt), to: sundayOnOrBefore(date)).day ?? 0
        return max(1, days / 7 + 1)
    }

    var currentWeek: Int { currentWeek() }
}

struct ChartPoint: Identifiable {
    let id: UUID
    let value: Double
}

func parseNumber(_ text: String) -> Double? {
    Double(text.replacingOccurrences(of: ",", with: "."))
}

func convertWeight(_ value: Double, from: String, to: String) -> Double {
    guard from != to else { return value }
    return to == "kg" ? value / 2.20462262 : value * 2.20462262
}

func convertLength(_ value: Double, from: String, to: String) -> Double {
    guard from != to else { return value }
    return to == "cm" ? value * 2.54 : value / 2.54
}

// MARK: - Store

class Store: ObservableObject {
    @Published var logs: [WeightLog] = []
    @Published var foods: [FoodEntry] = []
    @Published var bodyFat: [BodyFatLog] = []
    @Published var waist: [WaistLog] = []
    @Published var unit: WeightUnit = .kg {
        didSet { UserDefaults.standard.set(unit.rawValue, forKey: unitKey) }
    }
    @Published var stepGoal: Int = 10000 {
        didSet { UserDefaults.standard.set(stepGoal, forKey: stepGoalKey) }
    }
    @Published var healthConnected = false {
        didSet { UserDefaults.standard.set(healthConnected, forKey: healthKey) }
    }
    /// Daily step totals from Apple Health for the last 7 days (oldest first), including today.
    @Published var dailySteps: [(date: Date, steps: Int)] = []
    @Published var stepsUpdatedAt: Date?
    @Published var foodLogs: [FoodLog] = []
    @Published var scans: [PhysiqueScan] = [] {
        didSet { persist(scans, scansKey) }
    }
    /// Mr Olympia conversation, kept across app launches so the coach remembers past sessions.
    @Published var chat: [ChatMessage] = [] {
        didSet { persist(chat, chatKey) }
    }

    func clearChat() {
        for msg in chat { if let name = msg.imageFileName { try? FileManager.default.removeItem(at: docDir.appendingPathComponent(name)) } }
        chat = []
    }
    private let healthStore = HKHealthStore()
    @Published var calorieGoal: Int = 2000 {
        didSet { UserDefaults.standard.set(calorieGoal, forKey: goalKey) }
    }
    @Published var roadmap: Roadmap? {
        didSet {
            if let roadmap { persist(roadmap, roadmapKey) } else { UserDefaults.standard.removeObject(forKey: roadmapKey) }
        }
    }

    private let logsKey = "weightLogs"
    private let unitKey = "weightUnit"
    private let foodsKey = "foodEntries"
    private let bodyFatKey = "bodyFatLogs"
    private let goalKey = "calorieGoal"
    private let roadmapKey = "roadmap"
    private let waistKey = "waistLogs"
    private let stepGoalKey = "stepGoal"
    private let healthKey = "healthConnected"
    private let scansKey = "physiqueScans"
    private let healthFoodsKey = "healthFoodLogs"
    private let chatKey = "olympiaChat"
    private let docDir: URL

    init() {
        docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        unit = WeightUnit(rawValue: UserDefaults.standard.string(forKey: unitKey) ?? "kg") ?? .kg
        let goal = UserDefaults.standard.integer(forKey: goalKey)
        calorieGoal = goal > 0 ? goal : 2000
        logs = load(logsKey) ?? []
        foods = load(foodsKey) ?? []
        foodLogs = load(healthFoodsKey) ?? []
        bodyFat = load(bodyFatKey) ?? []
        roadmap = load(roadmapKey)
        waist = load(waistKey) ?? []
        scans = load(scansKey) ?? []
        chat = load(chatKey) ?? []
        let savedStepGoal = UserDefaults.standard.integer(forKey: stepGoalKey)
        stepGoal = savedStepGoal > 0 ? savedStepGoal : 10000
        healthConnected = UserDefaults.standard.bool(forKey: healthKey)
    }

    var stepsToday: Int { dailySteps.last?.steps ?? 0 }

    var healthAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func connectHealth() async {
        guard healthAvailable else { return }
        do {
            try await healthStore.requestAuthorization(toShare: [], read: [
                HKQuantityType(.stepCount), HKQuantityType(.dietaryEnergyConsumed),
                HKQuantityType(.dietaryProtein), HKQuantityType(.dietaryCarbohydrates), HKQuantityType(.dietaryFatTotal)
            ])
            healthConnected = true
            await refreshSteps()
            await refreshFoods()
        } catch {
            healthConnected = false
        }
    }

    /// Pulls the last 7 days of step counts (same data the Fitness/Health apps show, de-duplicated across iPhone and Watch).
    func refreshSteps() async {
        guard healthConnected, healthAvailable else { return }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let start = cal.date(byAdding: .day, value: -6, to: today) else { return }

        let predicate = HKSamplePredicate.quantitySample(
            type: HKQuantityType(.stepCount),
            predicate: HKQuery.predicateForSamples(withStart: start, end: nil, options: .strictStartDate))
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: predicate, options: .cumulativeSum, anchorDate: start, intervalComponents: DateComponents(day: 1))

        guard let collection = try? await descriptor.result(for: healthStore) else { return }
        var days: [(date: Date, steps: Int)] = []
        collection.enumerateStatistics(from: start, to: Date()) { stats, _ in
            days.append((stats.startDate, Int(stats.sumQuantity()?.doubleValue(for: .count()) ?? 0)))
        }
        dailySteps = days
        stepsUpdatedAt = Date()
    }

    /// Pulls food/calorie data from Apple Health (MyFitnessPal sync).
    func refreshFoods() async {
        guard healthConnected, healthAvailable else { return }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let start = cal.date(byAdding: .day, value: -30, to: today) else { return }

        /// Daily sums for one nutrient, keyed by start of day.
        func dailyTotals(_ id: HKQuantityTypeIdentifier, unit: HKUnit) async -> [Date: Int] {
            let predicate = HKSamplePredicate.quantitySample(
                type: HKQuantityType(id),
                predicate: HKQuery.predicateForSamples(withStart: start, end: nil, options: .strictStartDate))
            let descriptor = HKStatisticsCollectionQueryDescriptor(
                predicate: predicate, options: .cumulativeSum, anchorDate: start, intervalComponents: DateComponents(day: 1))
            guard let collection = try? await descriptor.result(for: healthStore) else { return [:] }
            var totals: [Date: Int] = [:]
            collection.enumerateStatistics(from: start, to: Date()) { stats, _ in
                let value = Int((stats.sumQuantity()?.doubleValue(for: unit) ?? 0).rounded())
                if value > 0 { totals[stats.startDate] = value }
            }
            return totals
        }

        let kcal = await dailyTotals(.dietaryEnergyConsumed, unit: .kilocalorie())
        let protein = await dailyTotals(.dietaryProtein, unit: .gram())
        let carbs = await dailyTotals(.dietaryCarbohydrates, unit: .gram())
        let fat = await dailyTotals(.dietaryFatTotal, unit: .gram())

        let allDays = Set(kcal.keys).union(protein.keys).union(carbs.keys).union(fat.keys)
        foodLogs = allDays.sorted().map { day in
            FoodLog(id: UUID(), date: day, calories: kcal[day] ?? 0,
                    protein: protein[day], carbs: carbs[day], fat: fat[day], name: "Apple Health")
        }
        persist(foodLogs, healthFoodsKey)
    }

    /// Macros synced from Apple Health for a day (grams). Nil when nothing was synced.
    func macros(on date: Date) -> (protein: Int, carbs: Int, fat: Int)? {
        guard let log = foodLogs.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }),
              log.protein != nil || log.carbs != nil || log.fat != nil else { return nil }
        return (log.protein ?? 0, log.carbs ?? 0, log.fat ?? 0)
    }

    private func load<T: Decodable>(_ key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func persist<T: Encodable>(_ value: T, _ key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func convert(_ kg: Double) -> Double { unit == .lb ? kg * 2.20462262 : kg }

    func display(weightKg: Double) -> String {
        String(format: "%.1f", convert(weightKg))
    }

    func addLog(date: Date, weight: String, photo: UIImage?) {
        guard let entered = parseNumber(weight) else { return }
        let kg = unit == .lb ? entered / 2.20462262 : entered

        var photoName: String? = nil
        if let photo, let data = photo.jpegData(compressionQuality: 0.85) {
            let name = "\(UUID().uuidString).jpg"
            try? data.write(to: docDir.appendingPathComponent(name))
            photoName = name
        }

        var existing = logs
        if let index = existing.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
            existing[index].weightKg = kg
            if let photoName { existing[index].photoFileName = photoName }
        } else {
            existing.append(WeightLog(id: UUID(), date: date, weightKg: kg, photoFileName: photoName))
        }

        logs = existing.sorted { $0.date < $1.date }
        persist(logs, logsKey)
    }

    func addLog(date: Date, weight: String, photos: [String: UIImage]?) {
        guard let entered = parseNumber(weight) else { return }
        let kg = unit == .lb ? entered / 2.20462262 : entered

        var photoName: String? = nil
        var additionalPhotos: [String: String] = [:]

        if let photos = photos {
            for (angle, image) in photos {
                if let data = image.jpegData(compressionQuality: 0.85) {
                    let name = "\(UUID().uuidString).jpg"
                    try? data.write(to: docDir.appendingPathComponent(name))
                    if angle == "front" {
                        photoName = name
                    } else {
                        additionalPhotos[angle] = name
                    }
                }
            }
        }

        var existing = logs
        if let index = existing.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
            existing[index].weightKg = kg
            if let photoName { existing[index].photoFileName = photoName }
            if !additionalPhotos.isEmpty {
                existing[index].additionalPhotos = additionalPhotos
            }
        } else {
            existing.append(WeightLog(id: UUID(), date: date, weightKg: kg, photoFileName: photoName, additionalPhotos: additionalPhotos))
        }

        logs = existing.sorted { $0.date < $1.date }
        persist(logs, logsKey)
    }

    func deleteLog(_ log: WeightLog) {
        if let name = log.photoFileName {
            try? FileManager.default.removeItem(at: docDir.appendingPathComponent(name))
        }
        for (_, name) in log.additionalPhotos {
            try? FileManager.default.removeItem(at: docDir.appendingPathComponent(name))
        }
        logs.removeAll { $0.id == log.id }
        persist(logs, logsKey)
    }

    /// Average of weight logs over a 7-day window ending `daysBack` days before today (0 = today and the 6 days before).
    func averageWeightKg(daysBack: Int) -> (kg: Double, count: Int)? {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let end = cal.date(byAdding: .day, value: 1 - daysBack, to: today),
              let start = cal.date(byAdding: .day, value: -7, to: end) else { return nil }
        return averageWeightKg(from: start, to: end)
    }

    func averageWeightKg(from start: Date, to end: Date) -> (kg: Double, count: Int)? {
        let window = logs.filter { $0.date >= start && $0.date < end }
        guard !window.isEmpty else { return nil }
        return (window.reduce(0) { $0 + $1.weightKg } / Double(window.count), window.count)
    }

    func image(for fileName: String?) -> UIImage? {
        guard let fileName else { return nil }
        return UIImage(contentsOfFile: docDir.appendingPathComponent(fileName).path)
    }

    func photoURL(for log: WeightLog) -> URL? {
        log.photoFileName.map { docDir.appendingPathComponent($0) }
    }

    func photoURL(for log: WeightLog, angle: String) -> URL? {
        if angle == "front" {
            return log.photoFileName.map { docDir.appendingPathComponent($0) }
        } else if let name = log.additionalPhotos[angle] {
            return docDir.appendingPathComponent(name)
        }
        return nil
    }

    /// Every entry that has a progress photo, newest first.
    var photoLogs: [WeightLog] {
        logs.filter { $0.photoFileName != nil }.sorted { $0.date > $1.date }
    }

    /// Deletes just the photo from these entries; the weights stay.
    func removePhotos(_ ids: Set<UUID>) {
        for index in logs.indices where ids.contains(logs[index].id) {
            if let name = logs[index].photoFileName {
                try? FileManager.default.removeItem(at: docDir.appendingPathComponent(name))
            }
            logs[index].photoFileName = nil
        }
        persist(logs, logsKey)
    }

    func addFood(date: Date, name: String, calories: Int, meal: Meal) {
        let title = name.trimmingCharacters(in: .whitespaces)
        foods.append(FoodEntry(id: UUID(), date: date, name: title.isEmpty ? meal.title : title, calories: calories, meal: meal))
        persist(foods, foodsKey)
    }

    func deleteFood(_ entry: FoodEntry) {
        foods.removeAll { $0.id == entry.id }
        persist(foods, foodsKey)
    }

    func foods(on date: Date) -> [FoodEntry] {
        foods.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    func calories(on date: Date) -> Int {
        let manualCalories = foods(on: date).reduce(0) { $0 + $1.calories }
        let healthCalories = foodLogs.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }.reduce(0) { $0 + $1.calories }
        return manualCalories + healthCalories
    }

    func addBodyFat(date: Date, percent: Double) {
        if let index = bodyFat.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
            bodyFat[index].percent = percent
        } else {
            bodyFat.append(BodyFatLog(id: UUID(), date: date, percent: percent))
        }
        bodyFat.sort { $0.date < $1.date }
        persist(bodyFat, bodyFatKey)
    }

    func deleteBodyFat(_ log: BodyFatLog) {
        bodyFat.removeAll { $0.id == log.id }
        persist(bodyFat, bodyFatKey)
    }

    func addWaist(sunday: Date, value: Double, unit: String) {
        let cm = convertLength(value, from: unit, to: "cm")
        let day = sundayOnOrBefore(sunday)
        if let index = waist.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: day) }) {
            waist[index].cm = cm
        } else {
            waist.append(WaistLog(id: UUID(), date: day, cm: cm))
        }
        waist.sort { $0.date < $1.date }
        persist(waist, waistKey)
    }

    func deleteWaist(_ log: WaistLog) {
        waist.removeAll { $0.id == log.id }
        persist(waist, waistKey)
    }

    func waist(on date: Date) -> WaistLog? {
        waist.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
}

enum WaistReminder {
    private static let prefix = "waistReminder-"
    private static let weeksAhead = 8

    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func cancelAll() async {
        let center = UNUserNotificationCenter.current()
        let ids = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// Schedules one reminder per upcoming Sunday, skipping Sundays that already have a waist log.
    static func reschedule(hour: Int, minute: Int, loggedSundays: [Date]) async {
        await cancelAll()
        let center = UNUserNotificationCenter.current()
        guard await center.notificationSettings().authorizationStatus == .authorized else { return }

        let cal = Calendar(identifier: .gregorian)
        let thisSunday = sundayOnOrBefore(Date())
        for week in 0..<weeksAhead {
            guard let sunday = cal.date(byAdding: .day, value: 7 * week, to: thisSunday),
                  let fireDate = cal.date(bySettingHour: hour, minute: minute, second: 0, of: sunday),
                  fireDate > Date(),
                  !loggedSundays.contains(where: { cal.isDate($0, inSameDayAs: sunday) }) else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Weekly Waist Check-in"
            content.body = "It's Sunday! Measure your waist at the belly button, relaxed, before breakfast."
            content.sound = .default

            let components = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let id = prefix + fireDate.formatted(.iso8601.year().month().day())
            let request = UNNotificationRequest(identifier: id, content: content,
                                                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
            try? await center.add(request)
        }
    }
}

func sundayOnOrBefore(_ date: Date) -> Date {
    let cal = Calendar(identifier: .gregorian)
    let start = cal.startOfDay(for: date)
    let weekday = cal.component(.weekday, from: start)
    return cal.date(byAdding: .day, value: -(weekday - 1), to: start) ?? start
}

// MARK: - Design System

enum Theme {
    static let weight = LinearGradient(colors: [Color(red: 0.49, green: 0.30, blue: 1.0), Color(red: 0.96, green: 0.34, blue: 0.72)], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let calories = LinearGradient(colors: [Color(red: 1.0, green: 0.62, blue: 0.20), Color(red: 1.0, green: 0.30, blue: 0.36)], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let bodyFat = LinearGradient(colors: [Color(red: 0.10, green: 0.82, blue: 0.75), Color(red: 0.20, green: 0.50, blue: 1.0)], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let olympia = LinearGradient(colors: [Color(red: 1.0, green: 0.80, blue: 0.25), Color(red: 0.95, green: 0.50, blue: 0.10)], startPoint: .topLeading, endPoint: .bottomTrailing)

    static let weightColor = Color(red: 0.62, green: 0.32, blue: 0.95)
    static let caloriesColor = Color(red: 1.0, green: 0.45, blue: 0.25)
    static let bodyFatColor = Color(red: 0.15, green: 0.65, blue: 0.90)
    static let olympiaColor = Color(red: 0.95, green: 0.62, blue: 0.12)
    static let roadmap = LinearGradient(colors: [Color(red: 0.20, green: 0.85, blue: 0.50), Color(red: 0.10, green: 0.55, blue: 0.95)], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let roadmapColor = Color(red: 0.12, green: 0.70, blue: 0.62)
    static let steps = LinearGradient(colors: [Color(red: 0.55, green: 0.85, blue: 0.20), Color(red: 0.10, green: 0.72, blue: 0.45)], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let stepsColor = Color(red: 0.20, green: 0.70, blue: 0.35)
}

extension View {
    func card() -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
            .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
    }

    func inputField() -> some View {
        padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(.tertiarySystemFill)))
    }

    func keyboardDoneButton() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { hideKeyboard() }
            }
        }
    }
}

/// Finds the UIScrollView behind a SwiftUI ScrollView and pins it horizontally so it can only move up/down.
struct HorizontalScrollLock: UIViewRepresentable {
    func makeUIView(context: Context) -> LockView { LockView() }
    func updateUIView(_ uiView: LockView, context: Context) {}

    final class LockView: UIView {
        private var observation: NSKeyValueObservation?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            DispatchQueue.main.async { [weak self] in self?.attach() }
        }

        private func attach() {
            var view = superview
            while let current = view, !(current is UIScrollView) { view = current.superview }
            guard let scrollView = view as? UIScrollView else { return }
            scrollView.alwaysBounceHorizontal = false
            scrollView.isDirectionalLockEnabled = true
            scrollView.showsHorizontalScrollIndicator = false
            observation = scrollView.observe(\.contentOffset, options: [.new]) { scrollView, _ in
                MainActor.assumeIsolated {
                    let pinnedX = -scrollView.adjustedContentInset.left
                    if scrollView.contentOffset.x != pinnedX {
                        scrollView.contentOffset.x = pinnedX
                    }
                }
            }
        }
    }
}

extension View {
    func lockHorizontalScroll() -> some View {
        background(HorizontalScrollLock().frame(width: 0, height: 0))
    }
}

struct GradientButtonStyle: ButtonStyle {
    let gradient: LinearGradient
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(gradient))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct SectionTitle: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(color)
            Text(title)
                .font(.title3.weight(.bold))
        }
    }
}

struct StatTile: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.18)))
    }
}

struct HeroCard<Content: View>: View {
    let gradient: LinearGradient
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) { content }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(gradient))
            .shadow(color: .black.opacity(0.15), radius: 16, y: 8)
    }
}

struct EmptyHint: View {
    let icon: String
    let text: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

// MARK: - Root

struct ContentView: View {
    @StateObject private var store = Store()

    var body: some View {
        TabView {
            WeightView(store: store)
                .tabItem { Label("Weight", systemImage: "scalemass.fill") }
            NutritionView(store: store)
                .tabItem { Label("Nutrition", systemImage: "flame.fill") }
            RoadMapView(store: store)
                .tabItem { Label("Road Map", systemImage: "map.fill") }
            PhysiqueView(store: store)
                .tabItem { Label("Physique", systemImage: "figure") }
            MrOlympiaView(store: store)
                .tabItem { Label("Mr Olympia", systemImage: "trophy.fill") }
        }
        .tint(Theme.weightColor)
    }
}

// MARK: - Weight Tab

struct WeightView: View {
    @ObservedObject var store: Store
    @State private var date = Date()
    @State private var weightInput = ""
    @State private var selectedImages: [String: UIImage] = [:]
    @State private var showCamera = false
    @State private var waistInput = ""
    @State private var waistSunday = sundayOnOrBefore(Date())
    @State private var viewerStart: PhotoViewerStart?
    @State private var showGallery = false
    @AppStorage("roadmapLengthUnit") private var lengthUnitRaw = ""
    @AppStorage("waistReminderOn") private var reminderOn = false
    @AppStorage("waistReminderHour") private var reminderHour = 9
    @AppStorage("waistReminderMinute") private var reminderMinute = 0
    @State private var reminderDenied = false

    private var reminderBinding: Binding<Bool> {
        Binding(get: { reminderOn }, set: { on in
            Task {
                if on {
                    let granted = await WaistReminder.requestPermission()
                    reminderDenied = !granted
                    reminderOn = granted
                } else {
                    reminderOn = false
                }
                await rescheduleReminders()
            }
        })
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding(get: {
            Calendar.current.date(bySettingHour: reminderHour, minute: reminderMinute, second: 0, of: Date()) ?? Date()
        }, set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            reminderHour = parts.hour ?? 9
            reminderMinute = parts.minute ?? 0
            Task { await rescheduleReminders() }
        })
    }

    private func rescheduleReminders() async {
        if reminderOn {
            await WaistReminder.reschedule(hour: reminderHour, minute: reminderMinute, loggedSundays: store.waist.map(\.date))
        } else {
            await WaistReminder.cancelAll()
        }
    }

    private var lengthUnit: String { lengthUnitRaw.isEmpty ? (store.unit == .lb ? "in" : "cm") : lengthUnitRaw }
    private var lengthUnitBinding: Binding<String> {
        Binding(get: { lengthUnit }, set: { newUnit in
            if let v = parseNumber(waistInput) { waistInput = String(format: "%.1f", convertLength(v, from: lengthUnit, to: newUnit)) }
            lengthUnitRaw = newUnit
        })
    }
    private func waistText(_ cm: Double) -> String {
        String(format: "%.1f", convertLength(cm, from: "cm", to: lengthUnit))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    heroCard
                    addEntryCard
                    waistCard
                    if !store.photoLogs.isEmpty { photosCard }
                    if store.logs.count > 1 { graphCard }
                    if !store.logs.isEmpty { historyCard }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Weight")
            .navigationDestination(isPresented: $showGallery) { PhotoGalleryView(store: store) }
            .fullScreenCover(item: $viewerStart) { start in
                PhotoViewer(store: store, logs: store.photoLogs, startID: start.id)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showGallery = true
                    } label: {
                        Image(systemName: "photo.on.rectangle.angled")
                    }
                    .accessibilityLabel("Progress Photos")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Picker("Unit", selection: $store.unit) {
                        ForEach(WeightUnit.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 110)
                }
            }
            .keyboardDoneButton()
            .task { await rescheduleReminders() }
            .onChange(of: store.waist.map(\.date)) { _, _ in
                Task { await rescheduleReminders() }
            }
            .fullScreenCover(isPresented: $showCamera) {
                MultiAngleCameraView(images: $selectedImages)
            }
        }
    }

    private var heroCard: some View {
        HeroCard(gradient: Theme.weight) {
            Text("Current Weight")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(store.logs.last.map { store.display(weightKg: $0.weightKg) } ?? "--")
                    .font(.system(size: 52, weight: .heavy, design: .rounded))
                Text(store.unit.title)
                    .font(.title3.weight(.bold))
            }
            .foregroundStyle(.white)

            HStack(spacing: 10) {
                StatTile(title: "Start", value: store.logs.first.map { store.display(weightKg: $0.weightKg) } ?? "--", icon: "flag.fill")
                StatTile(title: "Change", value: changeText, icon: "arrow.down.right")
                StatTile(title: "Logs", value: "\(store.logs.count)", icon: "calendar")
            }

            weeklyAverageRow
        }
    }

    private var weeklyAverageRow: some View {
        let thisWeek = store.averageWeightKg(daysBack: 0)
        let lastWeek = store.averageWeightKg(daysBack: 7)

        return HStack(alignment: .center, spacing: 10) {
            Image(systemName: "chart.bar.xaxis")
                .font(.headline)
            VStack(alignment: .leading, spacing: 2) {
                Text("7-Day Average")
                    .font(.caption.weight(.semibold))
                    .opacity(0.85)
                if let thisWeek {
                    Text("\(thisWeek.count) \(thisWeek.count == 1 ? "entry" : "entries") in the past 7 days")
                        .font(.caption2)
                        .opacity(0.75)
                } else {
                    Text("Log a weight this week to see it")
                        .font(.caption2)
                        .opacity(0.75)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(thisWeek.map { "\(store.display(weightKg: $0.kg)) \(store.unit.title)" } ?? "--")
                    .font(.title3.weight(.heavy))
                if let thisWeek, let lastWeek {
                    Text(String(format: "%+.1f vs last week", store.convert(thisWeek.kg - lastWeek.kg)))
                        .font(.caption2.weight(.semibold))
                        .opacity(0.85)
                }
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .foregroundStyle(.white)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.18)))
    }

    private var changeText: String {
        guard let first = store.logs.first, let last = store.logs.last else { return "--" }
        let diff = store.convert(last.weightKg - first.weightKg)
        return String(format: "%+.1f", diff)
    }

    private var addEntryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "Log Today", icon: "plus.circle.fill", color: Theme.weightColor)

            DatePicker("Date", selection: $date, displayedComponents: .date)
                .font(.subheadline.weight(.medium))

            HStack(spacing: 12) {
                HStack {
                    TextField("Weight", text: $weightInput)
                        .keyboardType(.decimalPad)
                        .font(.title3.weight(.semibold))
                    Text(store.unit.title)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .inputField()

                Button {
                    showCamera = true
                } label: {
                    ZStack {
                        if !selectedImages.isEmpty {
                            Image(uiImage: selectedImages["front"]!)
                                .resizable()
                                .scaledToFill()
                            if selectedImages.count > 1 {
                                Circle()
                                    .fill(Theme.weightColor)
                                    .frame(width: 18, height: 18)
                                    .overlay(Text("\(selectedImages.count)").font(.caption2.weight(.bold)).foregroundStyle(.white))
                            }
                        } else {
                            Image(systemName: "camera.fill")
                                .font(.title3)
                                .foregroundStyle(Theme.weightColor)
                        }
                    }
                    .frame(width: 52, height: 52)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.weightColor.opacity(0.12)))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }

            Button {
                store.addLog(date: date, weight: weightInput, photos: selectedImages.isEmpty ? nil : selectedImages)
                weightInput = ""
                selectedImages = [:]
                hideKeyboard()
            } label: {
                Label("Save Entry", systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(GradientButtonStyle(gradient: Theme.weight))
            .disabled(parseNumber(weightInput) == nil)
        }
        .card()
    }

    private var waistCard: some View {
        let currentSunday = sundayOnOrBefore(Date())
        let isThisWeek = Calendar.current.isDate(waistSunday, inSameDayAs: currentSunday)
        let existing = store.waist(on: waistSunday)
        let isSundayToday = Calendar.current.isDate(Date(), inSameDayAs: currentSunday)

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionTitle(title: "Weekly Waist", icon: "ruler.fill", color: Theme.weightColor)
                Spacer()
                Picker("Length unit", selection: lengthUnitBinding) {
                    Text("in").tag("in")
                    Text("cm").tag("cm")
                }
                .pickerStyle(.segmented)
                .frame(width: 100)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Toggle(isOn: reminderBinding) {
                        Label("Sunday reminder", systemImage: reminderOn ? "bell.badge.fill" : "bell")
                            .font(.subheadline.weight(.semibold))
                    }
                    .tint(Theme.weightColor)
                }
                if reminderOn {
                    DatePicker("Remind me at", selection: reminderTimeBinding, displayedComponents: .hourAndMinute)
                        .font(.subheadline)
                    Text("Skipped automatically on Sundays you've already logged.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if reminderDenied {
                    HStack(spacing: 6) {
                        Text("Notifications are off for this app.")
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                        }
                        .fontWeight(.semibold)
                    }
                    .font(.caption)
                    .foregroundStyle(.orange)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.weightColor.opacity(0.08)))

            HStack(spacing: 12) {
                Button {
                    waistSunday = Calendar.current.date(byAdding: .day, value: -7, to: waistSunday) ?? waistSunday
                } label: {
                    Image(systemName: "chevron.left.circle.fill").font(.title2)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(isThisWeek ? "This Sunday" : "Sunday")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(waistSunday, format: .dateTime.month(.abbreviated).day().year())
                        .font(.headline)
                }
                Button {
                    waistSunday = Calendar.current.date(byAdding: .day, value: 7, to: waistSunday) ?? waistSunday
                } label: {
                    Image(systemName: "chevron.right.circle.fill").font(.title2)
                }
                .disabled(isThisWeek)
                Spacer()
                Group {
                    if existing != nil {
                        Label("Logged", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    } else if isThisWeek {
                        Label(isSundayToday ? "Due today" : "Due Sunday", systemImage: "bell.fill").foregroundStyle(.orange)
                    } else {
                        Label("Missed", systemImage: "minus.circle").foregroundStyle(.secondary)
                    }
                }
                .font(.caption.weight(.bold))
            }
            .foregroundStyle(Theme.weightColor)

            HStack(spacing: 12) {
                HStack {
                    TextField(existing.map { "Logged: \(waistText($0.cm))" } ?? "Waist", text: $waistInput)
                        .keyboardType(.decimalPad)
                        .font(.title3.weight(.semibold))
                    Text(lengthUnit)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .inputField()

                Button {
                    if let v = parseNumber(waistInput), v > 0 {
                        store.addWaist(sunday: waistSunday, value: v, unit: lengthUnit)
                        waistInput = ""
                        hideKeyboard()
                    }
                } label: {
                    Image(systemName: "checkmark").font(.headline).frame(width: 24)
                }
                .buttonStyle(GradientButtonStyle(gradient: Theme.weight))
                .frame(width: 64)
                .disabled((parseNumber(waistInput) ?? 0) <= 0)
            }

            if let first = store.waist.first, let last = store.waist.last {
                HStack(spacing: 10) {
                    waistStat("Latest", "\(waistText(last.cm)) \(lengthUnit)")
                    waistStat("Start", "\(waistText(first.cm)) \(lengthUnit)")
                    waistStat("Change", String(format: "%+.1f %@", convertLength(last.cm - first.cm, from: "cm", to: lengthUnit), lengthUnit),
                              color: last.cm <= first.cm ? .green : .red)
                }
            }

            if store.waist.count > 1 {
                LineChart(points: store.waist.map { ChartPoint(id: $0.id, value: convertLength($0.cm, from: "cm", to: lengthUnit)) },
                          color: Theme.weightColor)
                    .frame(height: 140)
            }

            ForEach(store.waist.reversed().prefix(6)) { log in
                HStack {
                    Text(log.date, format: .dateTime.weekday(.abbreviated).month().day())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(waistText(log.cm)) \(lengthUnit)")
                        .font(.body.weight(.semibold))
                    Button {
                        withAnimation { store.deleteWaist(log) }
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
                .font(.subheadline)
            }
        }
        .card()
    }

    private func waistStat(_ title: String, _ value: String, color: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.bold)).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.weightColor.opacity(0.08)))
    }

    private var graphCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Progress", icon: "chart.xyaxis.line", color: Theme.weightColor)
            LineChart(
                points: store.logs.map { ChartPoint(id: $0.id, value: store.convert($0.weightKg)) },
                color: Theme.weightColor
            )
            .frame(height: 200)
        }
        .card()
    }

    private var photosCard: some View {
        let photos = store.photoLogs

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionTitle(title: "Progress Photos", icon: "photo.on.rectangle.angled", color: Theme.weightColor)
                Spacer()
                Button("See All (\(photos.count))") { showGallery = true }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.weightColor)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(photos.prefix(12)) { log in
                        Button {
                            viewerStart = PhotoViewerStart(id: log.id)
                        } label: {
                            VStack(spacing: 4) {
                                PhotoThumbnail(url: store.photoURL(for: log))
                                    .frame(width: 84, height: 112)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                Text(log.date, format: .dateTime.month(.abbreviated).day())
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .card()
    }

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "History", icon: "clock.fill", color: Theme.weightColor)

            HStack {
                Text("Entry")
                Spacer()
                Text("Waist (\(lengthUnit))")
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)

            ForEach(store.logs.reversed()) { log in
                HStack(spacing: 12) {
                    if log.photoFileName != nil {
                        Button {
                            viewerStart = PhotoViewerStart(id: log.id)
                        } label: {
                            PhotoThumbnail(url: store.photoURL(for: log))
                                .frame(width: 54, height: 54)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    } else {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Theme.weightColor.opacity(0.12))
                            .frame(width: 54, height: 54)
                            .overlay(Image(systemName: "photo").foregroundStyle(Theme.weightColor))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(log.date, format: .dateTime.weekday(.abbreviated).month().day())
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(store.display(weightKg: log.weightKg)) \(store.unit.title)")
                            .font(.headline)
                    }
                    Spacer()
                    if let w = store.waist(on: log.date) {
                        Label(waistText(w.cm), systemImage: "ruler")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.weightColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Theme.weightColor.opacity(0.12)))
                    } else {
                        Text("—").foregroundStyle(.tertiary)
                    }
                }
                .contentShape(Rectangle())
                .contextMenu {
                    Button("Delete", systemImage: "trash", role: .destructive) { store.deleteLog(log) }
                }
                if log.id != store.logs.first?.id { Divider() }
            }
            Text("Long-press an entry to delete it.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .card()
    }
}

// MARK: - Nutrition Tab

struct NutritionView: View {
    @ObservedObject var store: Store
    @State private var date = Date()
    @State private var foodName = ""
    @State private var caloriesInput = ""
    @State private var meal: Meal = .breakfast
    @State private var bodyFatInput = ""
    @State private var showGoalAlert = false
    @State private var goalInput = ""
    @State private var showStepGoalAlert = false
    @State private var stepGoalInput = ""
    @Environment(\.scenePhase) private var scenePhase

    private var consumed: Int { store.calories(on: date) }
    private var remaining: Int { store.calorieGoal - consumed }
    private var progress: Double { min(Double(consumed) / Double(max(store.calorieGoal, 1)), 1) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    DatePicker("Day", selection: $date, displayedComponents: .date)
                        .font(.subheadline.weight(.medium))
                        .card()
                    caloriesHero
                    macrosCard
                    stepsCard
                    addFoodCard
                    foodListCard
                    weeklyCard
                    bodyFatCard
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Nutrition")
            .keyboardDoneButton()
            .alert("Daily Calorie Goal", isPresented: $showGoalAlert) {
                TextField("kcal", text: $goalInput)
                    .keyboardType(.numberPad)
                Button("Save") {
                    if let value = Int(goalInput), value > 0 { store.calorieGoal = value }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Tip: ask Mr Olympia what your goal should be.")
            }
            .alert("Daily Step Goal", isPresented: $showStepGoalAlert) {
                TextField("steps", text: $stepGoalInput)
                    .keyboardType(.numberPad)
                Button("Save") {
                    if let value = Int(stepGoalInput), value > 0 { store.stepGoal = value }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your Road Map suggests a goal too. Tap \"Use as my calorie & step goals\" there to sync it.")
            }
            .task { await store.refreshSteps(); await store.refreshFoods() }
            .refreshable { await store.refreshSteps(); await store.refreshFoods() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await store.refreshSteps(); await store.refreshFoods() } }
            }
            .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
                Task { await store.refreshSteps(); await store.refreshFoods() }
            }
        }
    }

    private var stepsCard: some View {
        let today = store.stepsToday
        let goal = max(store.stepGoal, 1)
        let stepProgress = min(Double(today) / Double(goal), 1)
        let maxDay = Double(max(store.dailySteps.map(\.steps).max() ?? 0, goal))

        return HeroCard(gradient: Theme.steps) {
            HStack {
                Label("Steps", systemImage: "figure.walk")
                    .font(.headline.weight(.bold))
                Spacer()
                Text("Apple Health")
                    .font(.caption.weight(.semibold))
                    .opacity(0.85)
            }
            .foregroundStyle(.white)

            if !store.healthAvailable {
                Text("Apple Health isn't available on this device.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
            } else if !store.healthConnected {
                Text("Sync your steps from the iPhone Fitness / Health app to track your daily step goal.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
                Button {
                    Task { await store.connectHealth() }
                } label: {
                    Label("Connect Apple Health", systemImage: "heart.fill")
                        .font(.headline)
                        .foregroundStyle(Theme.stepsColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white))
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 20) {
                    ZStack {
                        Circle().stroke(.white.opacity(0.25), lineWidth: 12)
                        Circle()
                            .trim(from: 0, to: stepProgress)
                            .stroke(.white, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.spring, value: stepProgress)
                        VStack(spacing: 0) {
                            Text(today.formatted())
                                .font(.system(size: 22, weight: .heavy, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                            Text("today")
                                .font(.caption2.weight(.semibold))
                                .opacity(0.85)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                    }
                    .frame(width: 110, height: 110)

                    VStack(alignment: .leading, spacing: 10) {
                        StatTile(title: today >= goal ? "Goal hit!" : "To go",
                                 value: today >= goal ? "+\((today - goal).formatted())" : (goal - today).formatted(),
                                 icon: today >= goal ? "checkmark.seal.fill" : "shoeprints.fill")
                        Button {
                            stepGoalInput = "\(store.stepGoal)"
                            showStepGoalAlert = true
                        } label: {
                            StatTile(title: "Goal · tap to edit", value: store.stepGoal.formatted(), icon: "target")
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(Array(store.dailySteps.enumerated()), id: \.offset) { _, day in
                        VStack(spacing: 4) {
                            Capsule()
                                .fill(.white.opacity(day.steps >= goal ? 1 : 0.45))
                                .frame(height: max(4, 60 * Double(day.steps) / maxDay))
                            Text(day.date, format: .dateTime.weekday(.narrow))
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 80, alignment: .bottom)

                HStack {
                    Text("Weekly avg: \((store.dailySteps.isEmpty ? 0 : store.dailySteps.map(\.steps).reduce(0, +) / store.dailySteps.count).formatted())")
                    Spacer()
                    if let updated = store.stepsUpdatedAt {
                        Text("Synced \(updated.formatted(date: .omitted, time: .shortened))")
                    }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))

                if store.dailySteps.allSatisfy({ $0.steps == 0 }) {
                    Text("Seeing 0? Open the Health app → Sharing → Apps → WeightLossTracker and turn on Steps.")
                        .font(.caption)
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private var macrosCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionTitle(title: "Macros", icon: "chart.pie.fill", color: Theme.caloriesColor)
                Spacer()
                Text("Apple Health")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if let m = store.macros(on: date) {
                let pCal = Double(m.protein * 4), cCal = Double(m.carbs * 4), fCal = Double(m.fat * 9)
                let total = max(pCal + cCal + fCal, 1)
                let macros: [(name: String, grams: Int, cal: Double, color: Color)] = [
                    ("Protein", m.protein, pCal, .blue),
                    ("Carbs", m.carbs, cCal, .orange),
                    ("Fat", m.fat, fCal, .pink)
                ]

                GeometryReader { geo in
                    HStack(spacing: 2) {
                        ForEach(macros, id: \.name) { macro in
                            Capsule().fill(macro.color)
                                .frame(width: max(geo.size.width * macro.cal / total - 2, 0))
                        }
                    }
                }
                .frame(height: 12)

                HStack(spacing: 0) {
                    ForEach(macros, id: \.name) { macro in
                        VStack(spacing: 4) {
                            Text("\(macro.grams)g")
                                .font(.title3.weight(.heavy))
                                .foregroundStyle(macro.color)
                            Text(macro.name)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text("\(Int((macro.cal / total * 100).rounded()))%")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            } else if !store.healthConnected {
                EmptyHint(icon: "heart.text.square", text: "Connect Apple Health on the Steps card to see protein, carbs and fat from MyFitnessPal.")
            } else {
                EmptyHint(icon: "fork.knife", text: "No macros synced for this day yet. Log a meal in MyFitnessPal and pull down to refresh.")
            }
        }
        .card()
    }

    private var caloriesHero: some View {
        HeroCard(gradient: Theme.calories) {
            HStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.25), lineWidth: 14)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(.white, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.spring, value: progress)
                    VStack(spacing: 0) {
                        Text("\(consumed)")
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                        Text("kcal eaten")
                            .font(.caption2.weight(.semibold))
                            .opacity(0.85)
                    }
                    .foregroundStyle(.white)
                }
                .frame(width: 130, height: 130)

                VStack(alignment: .leading, spacing: 10) {
                    StatTile(title: remaining >= 0 ? "Remaining" : "Over", value: "\(abs(remaining)) kcal", icon: remaining >= 0 ? "flame" : "exclamationmark.triangle.fill")
                    Button {
                        goalInput = "\(store.calorieGoal)"
                        showGoalAlert = true
                    } label: {
                        StatTile(title: "Goal · tap to edit", value: "\(store.calorieGoal) kcal", icon: "target")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var addFoodCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "Add Food", icon: "fork.knife", color: Theme.caloriesColor)

            HStack(spacing: 8) {
                ForEach(Meal.allCases) { item in
                    Button {
                        meal = item
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: item.icon)
                            Text(item.title).font(.caption2.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(meal == item ? .white : Theme.caloriesColor)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(meal == item ? AnyShapeStyle(Theme.calories) : AnyShapeStyle(Theme.caloriesColor.opacity(0.12)))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            TextField("Food name (e.g. Chicken rice)", text: $foodName)
                .inputField()

            HStack {
                TextField("Calories", text: $caloriesInput)
                    .keyboardType(.numberPad)
                Text("kcal").foregroundStyle(.secondary)
            }
            .inputField()

            Button {
                if let kcal = Int(caloriesInput) {
                    store.addFood(date: date, name: foodName, calories: kcal, meal: meal)
                    foodName = ""
                    caloriesInput = ""
                    hideKeyboard()
                }
            } label: {
                Label("Add", systemImage: "plus.circle.fill")
            }
            .buttonStyle(GradientButtonStyle(gradient: Theme.calories))
            .disabled(Int(caloriesInput) == nil)
        }
        .card()
    }

    private var foodListCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Meals", icon: "list.bullet", color: Theme.caloriesColor)
            let entries = store.foods(on: date)
            if entries.isEmpty {
                EmptyHint(icon: "takeoutbag.and.cup.and.straw", text: "Nothing logged for this day yet.")
            } else {
                ForEach(Meal.allCases) { item in
                    let group = entries.filter { $0.meal == item }
                    if !group.isEmpty {
                        HStack {
                            Label(item.title, systemImage: item.icon)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Theme.caloriesColor)
                            Spacer()
                            Text("\(group.reduce(0) { $0 + $1.calories }) kcal")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        ForEach(group) { entry in
                            HStack {
                                Text(entry.name)
                                Spacer()
                                Text("\(entry.calories)")
                                    .font(.body.monospacedDigit().weight(.semibold))
                                Button {
                                    withAnimation { store.deleteFood(entry) }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.tertiary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.leading, 26)
                        }
                    }
                }
            }
        }
        .card()
    }

    private var weeklyCard: some View {
        let days = (0..<7).reversed().compactMap { Calendar.current.date(byAdding: .day, value: -$0, to: date) }
        let totals = days.map { store.calories(on: $0) }
        let maxValue = Double(max(totals.max() ?? 0, store.calorieGoal, 1))

        return VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Last 7 Days", icon: "chart.bar.fill", color: Theme.caloriesColor)
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                    VStack(spacing: 6) {
                        Text(totals[index] > 0 ? "\(totals[index])" : "")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Capsule()
                            .fill(totals[index] > store.calorieGoal ? AnyShapeStyle(Color.red.opacity(0.8)) : AnyShapeStyle(Theme.calories))
                            .frame(height: max(6, 120 * Double(totals[index]) / maxValue))
                        Text(day, format: .dateTime.weekday(.narrow))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Calendar.current.isDate(day, inSameDayAs: date) ? Theme.caloriesColor : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 160, alignment: .bottom)
        }
        .card()
    }

    private var bodyFatCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "Body Fat %", icon: "figure.arms.open", color: Theme.bodyFatColor)

            HeroCard(gradient: Theme.bodyFat) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(store.bodyFat.last.map { String(format: "%.1f", $0.percent) } ?? "--")
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                    Text("%").font(.title3.weight(.bold))
                    Spacer()
                    if let first = store.bodyFat.first, let last = store.bodyFat.last, store.bodyFat.count > 1 {
                        Text(String(format: "%+.1f%%", last.percent - first.percent))
                            .font(.headline.weight(.bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(.white.opacity(0.2)))
                    }
                }
                .foregroundStyle(.white)
            }

            HStack(spacing: 12) {
                HStack {
                    TextField("Body fat", text: $bodyFatInput)
                        .keyboardType(.decimalPad)
                    Text("%").foregroundStyle(.secondary)
                }
                .inputField()

                Button {
                    if let value = parseNumber(bodyFatInput), value > 0, value < 100 {
                        store.addBodyFat(date: date, percent: value)
                        bodyFatInput = ""
                        hideKeyboard()
                    }
                } label: {
                    Image(systemName: "checkmark")
                        .font(.headline)
                        .frame(width: 24)
                }
                .buttonStyle(GradientButtonStyle(gradient: Theme.bodyFat))
                .frame(width: 64)
                .disabled(parseNumber(bodyFatInput).map { $0 <= 0 || $0 >= 100 } ?? true)
            }

            if store.bodyFat.count > 1 {
                LineChart(points: store.bodyFat.map { ChartPoint(id: $0.id, value: $0.percent) }, color: Theme.bodyFatColor)
                    .frame(height: 150)
            }

            ForEach(store.bodyFat.reversed().prefix(5)) { log in
                HStack {
                    Text(log.date, format: .dateTime.month().day().year())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.1f%%", log.percent))
                        .font(.body.weight(.semibold))
                    Button {
                        withAnimation { store.deleteBodyFat(log) }
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
                .font(.subheadline)
            }
        }
        .card()
    }
}

// MARK: - Road Map Tab

enum Sex: String, CaseIterable, Identifiable {
    case male, female
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum Pace: String, CaseIterable, Identifiable {
    case steady, moderate, aggressive
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var weeklyPercent: Double {
        switch self {
        case .steady: return 0.5
        case .moderate: return 0.75
        case .aggressive: return 1.0
        }
    }
}

struct RoadMapView: View {
    @ObservedObject var store: Store
    @AppStorage("geminiAPIKey") private var apiKey: String = ""
    @State private var weightInput = ""
    @State private var bodyFatInput = ""
    @State private var goalFatInput = ""
    @State private var waistInput = ""
    @State private var heightInput = ""
    @State private var ageInput = ""
    @State private var sex: Sex = .male
    @State private var pace: Pace = .moderate
    @State private var isLoading = false
    @State private var errorText: String?
    @State private var showForm = true
    @State private var now = Date()
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("roadmapWeightUnit") private var weightUnitRaw = ""
    @AppStorage("roadmapLengthUnit") private var lengthUnitRaw = ""

    private var weightUnit: String { weightUnitRaw.isEmpty ? store.unit.title : weightUnitRaw }
    private var lengthUnit: String { lengthUnitRaw.isEmpty ? (store.unit == .lb ? "in" : "cm") : lengthUnitRaw }

    private var weightUnitBinding: Binding<String> {
        Binding(get: { weightUnit }, set: { newUnit in
            let old = weightUnit
            if let v = parseNumber(weightInput) { weightInput = String(format: "%.1f", convertWeight(v, from: old, to: newUnit)) }
            weightUnitRaw = newUnit
        })
    }

    private var lengthUnitBinding: Binding<String> {
        Binding(get: { lengthUnit }, set: { newUnit in
            let old = lengthUnit
            if let v = parseNumber(waistInput) { waistInput = String(format: "%.1f", convertLength(v, from: old, to: newUnit)) }
            if let v = parseNumber(heightInput) { heightInput = String(format: "%.0f", convertLength(v, from: old, to: newUnit)) }
            lengthUnitRaw = newUnit
        })
    }

    private var unitsBar: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Label("Weight", systemImage: "scalemass.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Picker("Weight unit", selection: weightUnitBinding) {
                    Text("lbs").tag("lbs")
                    Text("kg").tag("kg")
                }
                .pickerStyle(.segmented)
            }
            VStack(alignment: .leading, spacing: 6) {
                Label("Waist / Height", systemImage: "ruler.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Picker("Length unit", selection: lengthUnitBinding) {
                    Text("in").tag("in")
                    Text("cm").tag("cm")
                }
                .pickerStyle(.segmented)
            }
        }
        .card()
    }

    private func unitHeader(_ title: String, unit: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 2) {
                Text(title)
                Text(unit)
                    .padding(.horizontal, 4)
                    .background(Capsule().fill(Theme.roadmapColor.opacity(0.15)))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(Theme.roadmapColor)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inputsValid: Bool {
        guard let w = parseNumber(weightInput), let bf = parseNumber(bodyFatInput), let goal = parseNumber(goalFatInput),
              parseNumber(waistInput) != nil else { return false }
        return w > 0 && bf > 2 && bf < 70 && goal > 2 && goal < bf
    }

    private var leanGoalWeight: Double? {
        guard let w = parseNumber(weightInput), let bf = parseNumber(bodyFatInput), let goal = parseNumber(goalFatInput), goal < 100 else { return nil }
        return w * (1 - bf / 100) / (1 - goal / 100)
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                VStack(spacing: 20) {
                    if let roadmap = store.roadmap, !showForm {
                        planHero(roadmap)
                        unitsBar
                        planChart(roadmap)
                        currentWeightChart(roadmap)
                        weeklyTable(roadmap)
                        tipsCard(roadmap)
                    } else {
                        introHero
                        unitsBar
                        formCard
                    }
                }
                .padding()
                .containerRelativeFrame(.horizontal)
                .lockHorizontalScroll()
            }
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Road Map")
            .keyboardDoneButton()
            .toolbar {
                if store.roadmap != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(showForm ? "View Plan" : "New Plan") {
                            withAnimation(.snappy) { showForm.toggle() }
                        }
                    }
                }
            }
            .tint(Theme.roadmapColor)
            .onAppear {
                if store.roadmap != nil { showForm = false }
                now = Date()
                prefill()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { now = Date() }
            }
            .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { date in
                if !Calendar.current.isDate(date, inSameDayAs: now) { now = date }
            }
        }
    }

    private func prefill() {
        if weightInput.isEmpty, let last = store.logs.last {
            weightInput = String(format: "%.1f", convertWeight(last.weightKg, from: "kg", to: weightUnit))
        }
        if bodyFatInput.isEmpty, let last = store.bodyFat.last { bodyFatInput = String(format: "%.1f", last.percent) }
        if waistInput.isEmpty, let last = store.waist.last {
            waistInput = String(format: "%.1f", convertLength(last.cm, from: "cm", to: lengthUnit))
        }
    }

    private var introHero: some View {
        HeroCard(gradient: Theme.roadmap) {
            Image(systemName: "map.fill")
                .font(.system(size: 30))
                .foregroundStyle(.white)
            Text("Build your shred roadmap")
                .font(.title2.weight(.heavy))
                .foregroundStyle(.white)
            Text("Tell me where you are and the body fat % you want. Mr Olympia will plan your weekly weight and waist targets to get there.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    private func field(_ title: String, text: Binding<String>, unit: String, keyboard: UIKeyboardType = .decimalPad) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack {
                TextField("0", text: text)
                    .keyboardType(keyboard)
                    .font(.headline)
                Text(unit).foregroundStyle(.secondary)
            }
            .inputField()
        }
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(title: "Your Stats", icon: "person.fill", color: Theme.roadmapColor)

            HStack(spacing: 12) {
                field("Current weight", text: $weightInput, unit: weightUnit)
                field("Waist", text: $waistInput, unit: lengthUnit)
            }
            HStack(spacing: 12) {
                field("Current body fat", text: $bodyFatInput, unit: "%")
                field("Goal body fat", text: $goalFatInput, unit: "%")
            }
            HStack(spacing: 12) {
                field("Height (optional)", text: $heightInput, unit: lengthUnit)
                field("Age (optional)", text: $ageInput, unit: "yrs", keyboard: .numberPad)
            }

            Picker("Sex", selection: $sex) {
                ForEach(Sex.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 6) {
                Text("Pace")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Picker("Pace", selection: $pace) {
                    ForEach(Pace.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Text("Loses about \(String(format: "%.2g", pace.weeklyPercent))% of body weight per week")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let goal = leanGoalWeight, inputsValid {
                HStack {
                    Image(systemName: "target")
                    Text("Estimated goal weight: **\(String(format: "%.1f", goal)) \(weightUnit)** (if you keep your lean mass)")
                        .font(.subheadline)
                }
                .foregroundStyle(Theme.roadmapColor)
            }

            if let errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            if apiKey.isEmpty {
                Text("Add your Gemini API key in the Mr Olympia tab first.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Button {
                generate()
            } label: {
                if isLoading {
                    HStack(spacing: 8) {
                        ProgressView().tint(.white)
                        Text("Drafting your roadmap...")
                    }
                } else {
                    Label("Generate Roadmap", systemImage: "sparkles")
                }
            }
            .buttonStyle(GradientButtonStyle(gradient: Theme.roadmap))
            .disabled(!inputsValid || isLoading || apiKey.isEmpty)
        }
        .card()
    }

    private func planHero(_ roadmap: Roadmap) -> some View {
        HeroCard(gradient: Theme.roadmap) {
            HStack {
                Text("Goal · Week \(min(roadmap.currentWeek(at: now), roadmap.plan.totalWeeks)) of \(roadmap.plan.totalWeeks)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                Text(roadmap.createdAt, format: .dateTime.month().day())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(String(format: "%.1f", convertWeight(roadmap.plan.goalWeight, from: roadmap.weightUnit, to: weightUnit)))
                    .font(.system(size: 48, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
                Text(weightUnit).font(.title3.weight(.bold))
                Spacer()
                Text("\(String(format: "%.0f", roadmap.startBodyFat))% → \(String(format: "%.0f", roadmap.goalBodyFat))%")
                    .font(.headline.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.white.opacity(0.2)))
            }
            .foregroundStyle(.white)

            ProgressView(value: Double(min(roadmap.currentWeek(at: now), roadmap.plan.totalWeeks)), total: Double(max(roadmap.plan.totalWeeks, 1)))
                .tint(.white)

            HStack(spacing: 10) {
                StatTile(title: "Calories", value: "\(roadmap.plan.dailyCalories)", icon: "flame.fill")
                StatTile(title: "Steps", value: roadmap.plan.dailySteps.formatted(), icon: "figure.walk")
                StatTile(title: "Protein", value: "\(roadmap.plan.proteinGrams)g", icon: "fork.knife")
            }

            let goalsSynced = store.calorieGoal == roadmap.plan.dailyCalories && store.stepGoal == roadmap.plan.dailySteps
            Button {
                store.calorieGoal = roadmap.plan.dailyCalories
                store.stepGoal = roadmap.plan.dailySteps
            } label: {
                Label(goalsSynced ? "Calorie & step goals synced" : "Use as my calorie & step goals",
                      systemImage: goalsSynced ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white.opacity(0.18)))
            }
            .buttonStyle(.plain)
        }
    }

    private func planChart(_ roadmap: Roadmap) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Planned Weight (\(weightUnit))", icon: "chart.xyaxis.line", color: Theme.roadmapColor)
            LineChart(points: roadmap.plan.milestones.map { ChartPoint(id: UUID(), value: convertWeight($0.weight, from: roadmap.weightUnit, to: weightUnit)) }, color: Theme.roadmapColor)
                .frame(height: 180)
        }
        .card()
    }

    /// Your average logged weight for each plan week (Sunday–Saturday) up to the current week, in the selected unit.
    private func actualWeekly(_ roadmap: Roadmap) -> [Int: Double] {
        let cal = Calendar.current
        var result: [Int: Double] = [:]
        for m in roadmap.plan.milestones where m.week <= roadmap.currentWeek(at: now) {
            let from = roadmap.weekStart(m.week)
            guard let to = cal.date(byAdding: .day, value: 7, to: from),
                  let avg = store.averageWeightKg(from: from, to: to) else { continue }
            result[m.week] = convertWeight(avg.kg, from: "kg", to: weightUnit)
        }
        return result
    }

    private func currentWeightChart(_ roadmap: Roadmap) -> some View {
        let actual = actualWeekly(roadmap)
        let targets = roadmap.plan.milestones.map { convertWeight($0.weight, from: roadmap.weightUnit, to: weightUnit) }
        let series = roadmap.plan.milestones.map { actual[$0.week] }
        let latest = roadmap.plan.milestones.last { actual[$0.week] != nil }

        return VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Current Weight (\(weightUnit))", icon: "scalemass.fill", color: Theme.weightColor)

            if actual.isEmpty {
                EmptyHint(icon: "scalemass", text: "Log your weight in the Weight tab. Your weekly averages will be charted against the plan here.")
            } else {
                ProgressChart(target: targets, actual: series, currentIndex: min(roadmap.currentWeek(at: now), targets.count) - 1,
                              targetColor: Theme.roadmapColor, actualColor: Theme.weightColor)
                    .frame(height: 180)

                HStack(spacing: 14) {
                    legendItem(color: Theme.weightColor, dashed: false, text: "Your weekly average")
                    legendItem(color: Theme.roadmapColor, dashed: true, text: "Target")
                    Spacer()
                }

                if let latest, let value = actual[latest.week] {
                    let target = convertWeight(latest.weight, from: roadmap.weightUnit, to: weightUnit)
                    let diff = value - target
                    Label(diff <= 0
                          ? String(format: "Week %d: %.1f %@ ahead of target", latest.week, -diff, weightUnit)
                          : String(format: "Week %d: %.1f %@ behind target", latest.week, diff, weightUnit),
                          systemImage: diff <= 0 ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(diff <= 0 ? .green : .orange)
                }
            }
        }
        .card()
    }

    private func legendItem(color: Color, dashed: Bool, text: String) -> some View {
        HStack(spacing: 6) {
            Path { path in
                path.move(to: CGPoint(x: 0, y: 1.5))
                path.addLine(to: CGPoint(x: 18, y: 1.5))
            }
            .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: dashed ? [4, 3] : []))
            .frame(width: 18, height: 3)
            Text(text).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func weeklyTable(_ roadmap: Roadmap) -> some View {
        let actual = actualWeekly(roadmap)

        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "Weekly Targets", icon: "calendar", color: Theme.roadmapColor)

            HStack(spacing: 6) {
                Text("Wk").frame(width: 30, alignment: .leading)
                unitHeader("Target", unit: weightUnit) {
                    weightUnitBinding.wrappedValue = weightUnit == "lbs" ? "kg" : "lbs"
                }
                Text("Current").lineLimit(1).minimumScaleFactor(0.7).frame(maxWidth: .infinity, alignment: .leading)
                Text("Fat %").lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                unitHeader("Waist", unit: lengthUnit) {
                    lengthUnitBinding.wrappedValue = lengthUnit == "in" ? "cm" : "in"
                }
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)

            ForEach(roadmap.plan.milestones) { m in
                let isCurrent = m.week == roadmap.currentWeek(at: now)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        let target = convertWeight(m.weight, from: roadmap.weightUnit, to: weightUnit)
                        Text("\(m.week)")
                            .font(.subheadline.weight(.heavy))
                            .frame(width: 30, alignment: .leading)
                        Text(String(format: "%.1f", target)).frame(maxWidth: .infinity, alignment: .leading)
                        Group {
                            if let current = actual[m.week] {
                                Text(String(format: "%.1f", current))
                                    .fontWeight(.bold)
                                    .foregroundStyle(current <= target ? .green : .orange)
                            } else {
                                Text("—").foregroundStyle(.tertiary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Text(String(format: "%.1f%%", m.bodyFat)).frame(maxWidth: .infinity, alignment: .leading)
                        Text(String(format: "%.1f", convertLength(m.waist, from: roadmap.waistUnit, to: lengthUnit))).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(.subheadline.monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    if isCurrent || (m.focus?.isEmpty == false) {
                        HStack(spacing: 6) {
                            if isCurrent {
                                Text("NOW")
                                    .font(.system(size: 9, weight: .heavy))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(Theme.roadmap))
                            }
                            if let focus = m.focus, !focus.isEmpty {
                                Text(focus)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.leading, 36)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isCurrent ? Theme.roadmapColor.opacity(0.15) : Color.clear)
                )
            }
        }
        .card()
    }

    private func tipsCard(_ roadmap: Roadmap) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Coach Notes", icon: "trophy.fill", color: Theme.olympiaColor)
            Text(roadmap.plan.summary)
                .font(.subheadline)
            ForEach(roadmap.plan.tips, id: \.self) { tip in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Theme.roadmapColor)
                    Text(tip).font(.subheadline)
                }
            }
            Text("Estimates only, not medical advice. Adjust based on real progress.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .card()
    }

    private func generate() {
        guard let weight = parseNumber(weightInput), let bf = parseNumber(bodyFatInput),
              let goal = parseNumber(goalFatInput), let waist = parseNumber(waistInput) else { return }
        hideKeyboard()
        isLoading = true
        errorText = nil

        let leanGoal = weight * (1 - bf / 100) / (1 - goal / 100)
        let height = parseNumber(heightInput).map { "\(String(format: "%.0f", $0)) \(lengthUnit)" } ?? "unknown"
        let age = Int(ageInput).map { "\($0)" } ?? "unknown"
        let recentCalories = store.calories(on: Date())

        let system = """
        You are "Mr Olympia", an expert physique and fat-loss coach. Build a realistic, safe fat-loss roadmap. \
        Assume the user preserves most lean mass with high protein and resistance training. \
        Use weekly weight loss of about \(pace.weeklyPercent)% of current body weight (\(pace.title) pace), slowing slightly as the user gets leaner. \
        Estimate waist reduction realistically (roughly 1 \(lengthUnit == "in" ? "inch" : "2.5 cm") per ~8-10 lbs of fat lost, less when very lean). \
        Respond ONLY with JSON matching exactly this schema:
        {"summary": string, "goalWeight": number, "totalWeeks": integer, "dailyCalories": integer, "dailySteps": integer, "proteinGrams": integer, \
        "milestones": [{"week": integer, "weight": number, "bodyFat": number, "waist": number, "focus": string}], "tips": [string]}
        Rules: milestones start at week 1 and include EVERY week up to totalWeeks (max 52), weight in \(weightUnit), waist in \(lengthUnit), \
        bodyFat as percent number. "focus" is a short (under 12 words) training/diet focus for that week. Give 4-6 tips.
        """

        let prompt = """
        Sex: \(sex.title). Age: \(age). Height: \(height).
        Current weight: \(String(format: "%.1f", weight)) \(weightUnit). Current body fat: \(String(format: "%.1f", bf))%. Waist: \(String(format: "%.1f", waist)) \(lengthUnit).
        Goal body fat: \(String(format: "%.1f", goal))%. Lean-mass-preserved goal weight estimate: \(String(format: "%.1f", leanGoal)) \(weightUnit).
        Current daily calorie goal in app: \(store.calorieGoal) kcal (eaten today: \(recentCalories) kcal).
        """

        sendToGemini(system: system, prompt: prompt, image: nil, apiKey: apiKey, jsonMode: true) { result in
            DispatchQueue.main.async {
                isLoading = false
                var plan: RoadmapPlan?
                if case .success(let text) = result {
                    let cleaned = text
                        .replacingOccurrences(of: "```json", with: "")
                        .replacingOccurrences(of: "```", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if var decoded = try? JSONDecoder().decode(RoadmapPlan.self, from: Data(cleaned.utf8)), !decoded.milestones.isEmpty {
                        decoded.milestones.sort { $0.week < $1.week }
                        plan = decoded
                    }
                }
                let finalPlan = plan ?? localPlan(weight: weight, bf: bf, goal: goal, waist: waist)
                withAnimation(.snappy) {
                    store.roadmap = Roadmap(createdAt: Date(), weightUnit: weightUnit, waistUnit: lengthUnit,
                                            startWeight: weight, startBodyFat: bf, goalBodyFat: goal, startWaist: waist, plan: finalPlan)
                    showForm = false
                }
            }
        }
    }

    /// Math-based roadmap used when Gemini is unavailable.
    private func localPlan(weight: Double, bf: Double, goal: Double, waist: Double) -> RoadmapPlan {
        let lbs = convertWeight(weight, from: weightUnit, to: "lbs")
        let lean = lbs * (1 - bf / 100)
        let goalLbs = lean / (1 - goal / 100)

        var milestones: [Milestone] = []
        var current = lbs
        var week = 0
        while current > goalLbs + 0.05 && week < 52 {
            week += 1
            let leanFactor = max(0.6, min(1.0, (current - goalLbs) / max(lbs - goalLbs, 1) + 0.5))
            current = max(goalLbs, current - current * pace.weeklyPercent / 100 * leanFactor)
            let lostInches = (lbs - current) / 9
            let waistNow = convertLength(convertLength(waist, from: lengthUnit, to: "in") - lostInches, from: "in", to: lengthUnit)
            milestones.append(Milestone(week: week, weight: convertWeight(current, from: "lbs", to: weightUnit),
                                        bodyFat: (1 - lean / current) * 100, waist: waistNow, focus: nil))
        }
        for i in milestones.indices {
            let phase = Double(i + 1) / Double(milestones.count)
            milestones[i].focus = phase < 0.34 ? "Build habits: hit protein, steps, 3-4 lifts"
                : phase < 0.67 ? "Keep lifting heavy, tighten food tracking"
                : "Final push: dial in sleep, sodium, recovery"
        }

        var maintenance = lbs * 15
        if let h = parseNumber(heightInput), let age = Double(ageInput) {
            let cm = convertLength(h, from: lengthUnit, to: "cm")
            let bmr = 10 * (lbs / 2.20462262) + 6.25 * cm - 5 * age + (sex == .male ? 5 : -161)
            maintenance = bmr * 1.5
        }
        let deficit = lbs * pace.weeklyPercent / 100 * 3500 / 7
        let calories = Int(max(maintenance - deficit, sex == .male ? 1500 : 1200) / 10) * 10

        return RoadmapPlan(
            summary: "Mr Olympia (AI) was busy, so this is a standard math-based plan that keeps your lean mass. Tap New Plan later for an AI-personalized version.",
            goalWeight: convertWeight(goalLbs, from: "lbs", to: weightUnit),
            totalWeeks: milestones.count,
            dailyCalories: calories,
            dailySteps: 10000,
            proteinGrams: Int(goalLbs.rounded()),
            milestones: milestones,
            tips: [
                "Eat about 1 g of protein per lb of goal weight every day.",
                "Lift weights 3-4x per week to keep muscle while cutting.",
                "Walk 8-10k steps daily; it burns fat without hurting recovery.",
                "Weigh in daily and track the weekly average, not single days.",
                "If weight stalls for 2+ weeks, cut 100-150 kcal or add 2k steps."
            ]
        )
    }
}

// MARK: - Mr Olympia (AI Coach)

struct MrOlympiaView: View {
    @ObservedObject var store: Store
    @AppStorage("geminiAPIKey") private var apiKey: String = ""
    @AppStorage("showAPIKeyPanel") private var showKeyPanel: Bool = true
    @State private var keyInput: String = ""
    @State private var revealKey = false
    @State private var input = ""
    @State private var isLoading = false
    @State private var selectedImage: UIImage?
    @State private var showSourcePicker = false

    private var messages: [ChatMessage] { store.chat }

    private let suggestions = [
        "Rate my physique and what to improve",
        "How many calories should I eat per day?",
        "How many steps should I walk daily?",
        "Give me a weekly workout plan"
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if showKeyPanel || apiKey.isEmpty { keyPanel }

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            if messages.isEmpty { welcome }
                            ForEach(messages) { msg in
                                MessageBubble(msg: msg).id(msg.id)
                            }
                            if isLoading {
                                HStack(spacing: 8) {
                                    ProgressView()
                                    Text("Mr Olympia is thinking...")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .id("loading")
                            }
                        }
                        .padding()
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: messages.count) { _, _ in
                        withAnimation { proxy.scrollTo(messages.last?.id, anchor: .bottom) }
                    }
                }

                composer
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Mr Olympia")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !messages.isEmpty {
                        Button {
                            withAnimation { store.clearChat() }
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation(.snappy) { showKeyPanel.toggle() }
                    } label: {
                        Image(systemName: showKeyPanel ? "key.fill" : "key")
                    }
                    .disabled(apiKey.isEmpty)
                }
            }
            .tint(Theme.olympiaColor)
            .onAppear { keyInput = apiKey }
            .photoSourcePicker(title: "Attach a photo", isPresented: $showSourcePicker, image: $selectedImage)
        }
    }

    private var keyPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Gemini API Key", systemImage: "key.fill")
                    .font(.subheadline.weight(.bold))
                Spacer()
                if !apiKey.isEmpty {
                    Button("Hide") {
                        withAnimation(.snappy) { showKeyPanel = false }
                    }
                    .font(.subheadline.weight(.semibold))
                }
            }

            HStack(spacing: 10) {
                Group {
                    if revealKey {
                        TextField("Paste your key", text: $keyInput)
                    } else {
                        SecureField("Paste your key", text: $keyInput)
                    }
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .inputField()

                Button {
                    revealKey.toggle()
                } label: {
                    Image(systemName: revealKey ? "eye.slash" : "eye")
                }

                Button("Save") {
                    apiKey = keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    hideKeyboard()
                    withAnimation(.snappy) { showKeyPanel = false }
                }
                .font(.headline)
                .disabled(keyInput.isEmpty)
            }

            if apiKey.isEmpty {
                Text("Get a free key at aistudio.google.com/app/apikey")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Key saved. Tap Hide or the key icon to tuck this away.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .card()
        .padding([.horizontal, .top])
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 16) {
            HeroCard(gradient: Theme.olympia) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.white)
                Text("Hey champ, I'm Mr Olympia.")
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(.white)
                Text("Send me a physique photo or ask about calories, steps, training, and diet. I can see your weight, calorie, and body fat logs.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
            }

            ForEach(suggestions, id: \.self) { text in
                Button {
                    input = text
                    performSend()
                } label: {
                    HStack {
                        Text(text)
                            .font(.subheadline.weight(.medium))
                            .multilineTextAlignment(.leading)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                    .foregroundStyle(.primary)
                    .card()
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
            }
        }
    }

    private var composer: some View {
        VStack(spacing: 8) {
            if let selectedImage {
                HStack {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    Text("Photo attached")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        self.selectedImage = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill").font(.title3).foregroundStyle(.secondary)
                    }
                }
            }

            HStack(alignment: .bottom, spacing: 10) {
                Button {
                    showSourcePicker = true
                } label: {
                    Image(systemName: "camera.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.olympiaColor)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(Theme.olympiaColor.opacity(0.15)))
                }

                TextField("Ask Mr Olympia...", text: $input, axis: .vertical)
                    .lineLimit(1...5)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 21, style: .continuous).fill(Color(.tertiarySystemFill)))

                Button {
                    performSend()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(Theme.olympia))
                }
                .disabled((input.isEmpty && selectedImage == nil) || isLoading)
                .opacity((input.isEmpty && selectedImage == nil) || isLoading ? 0.4 : 1)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private func performSend() {
        guard !apiKey.isEmpty else {
            store.chat.append(ChatMessage(role: "assistant", content: "Please save your Gemini API key first. Get a free one at aistudio.google.com/app/apikey", image: nil))
            showKeyPanel = true
            return
        }

        let prompt = input.isEmpty ? "What do you think of my physique and what should I improve?" : input
        // Everything before this message is history the coach should remember.
        let history = Array(store.chat.suffix(40))
        store.chat.append(ChatMessage(role: "user", content: prompt, image: selectedImage))
        input = ""
        isLoading = true
        hideKeyboard()

        let unit = store.unit.title
        let logsText = store.logs.suffix(10).map {
            "\($0.date.formatted(date: .abbreviated, time: .omitted)): \(store.display(weightKg: $0.weightKg)) \(unit)"
        }.joined(separator: ", ")
        let fatText = store.bodyFat.suffix(5).map {
            "\($0.date.formatted(date: .abbreviated, time: .omitted)): \(String(format: "%.1f", $0.percent))%"
        }.joined(separator: ", ")
        let calorieText = (0..<7).reversed().compactMap { offset -> String? in
            guard let day = Calendar.current.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
            let total = store.calories(on: day)
            return total > 0 ? "\(day.formatted(date: .abbreviated, time: .omitted)): \(total) kcal" : nil
        }.joined(separator: ", ")
        let stepsText = store.dailySteps.map {
            "\($0.date.formatted(date: .abbreviated, time: .omitted)): \($0.steps)"
        }.joined(separator: ", ")
        let waistLogText = store.waist.suffix(6).map {
            "\($0.date.formatted(date: .abbreviated, time: .omitted)): \(String(format: "%.1f", $0.cm)) cm (\(String(format: "%.1f", $0.cm / 2.54)) in)"
        }.joined(separator: ", ")
        let roadmapText = store.roadmap.map {
            "Active roadmap: from \(String(format: "%.1f", $0.startWeight)) \($0.weightUnit) at \(String(format: "%.1f", $0.startBodyFat))% to \(String(format: "%.1f", $0.plan.goalWeight)) \($0.weightUnit) at \(String(format: "%.1f", $0.goalBodyFat))% over \($0.plan.totalWeeks) weeks; currently week \($0.currentWeek)."
        } ?? "No roadmap yet."

        let system = """
        You are "Mr Olympia", a supportive, motivating fitness, nutrition, and physique coach. The user uses \(unit). \
        Recent weight logs: \(logsText.isEmpty ? "none yet" : logsText). \
        Recent body fat logs: \(fatText.isEmpty ? "none yet" : fatText). \
        Weekly Sunday waist logs: \(waistLogText.isEmpty ? "none yet" : waistLogText). \
        Daily calorie goal: \(store.calorieGoal) kcal. Calories eaten last 7 days: \(calorieText.isEmpty ? "none logged" : calorieText). \
        Daily step goal: \(store.stepGoal). Steps last 7 days (Apple Health): \(stepsText.isEmpty ? "not connected" : stepsText). \
        \(roadmapText) \
        Give concise, encouraging, actionable advice using short bullet points. For calories and steps, provide reasonable estimates and explain. \
        Do not give medical diagnoses. \
        Memory: this is an ongoing conversation that continues across days. The earlier messages are your shared history; remember what the user told you \
        (goals, injuries, preferences, schedule, past advice you gave) and build on it. Refer back to it when relevant and notice progress or changes. \
        Style: \(history.isEmpty ? "This is the very first message, so a brief one-line hello is fine." : "You are mid-conversation. Do NOT greet, reintroduce yourself, or open with 'Hey champ' or any stock opener.") \
        Never start two replies the same way. Vary how you open: sometimes dive straight into the answer, sometimes react to what they said, sometimes ask a quick follow-up first. \
        Today is \(Date().formatted(date: .complete, time: .shortened)).
        """

        let image = selectedImage
        selectedImage = nil
        sendToGemini(system: system, prompt: prompt, image: image, history: history, apiKey: apiKey) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let reply):
                    store.chat.append(ChatMessage(role: "assistant", content: reply, image: nil))
                case .failure(let error):
                    store.chat.append(ChatMessage(role: "assistant", content: "Sorry, I hit an error: \(error.localizedDescription)", image: nil))
                }
            }
        }
    }
}

struct MessageBubble: View {
    let msg: ChatMessage
    private var isUser: Bool { msg.role == "user" }

    private var rendered: AttributedString {
        (try? AttributedString(markdown: msg.content, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(msg.content)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isUser {
                Spacer(minLength: 40)
            } else {
                Image(systemName: "trophy.fill")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Theme.olympia))
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                if let image = msg.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 160, height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                Text(rendered)
                    .font(.subheadline)
                    .textSelection(.enabled)
                    .padding(12)
                    .foregroundStyle(isUser ? .white : .primary)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(isUser ? AnyShapeStyle(Theme.olympia) : AnyShapeStyle(Color(.secondarySystemGroupedBackground)))
                    )
            }

            if !isUser { Spacer(minLength: 20) }
        }
    }
}

struct ChatMessage: Identifiable, Codable {
    var id = UUID()
    var role: String
    var content: String
    var imageFileName: String? = nil
    var date = Date()

    var image: UIImage? {
        guard let imageFileName else { return nil }
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent(imageFileName)
        return UIImage(contentsOfFile: url.path)
    }

    init(role: String, content: String, image: UIImage?) {
        self.role = role
        self.content = content
        if let image, let resized = resizeImage(image, maxSide: 800), let data = resized.jpegData(compressionQuality: 0.7) {
            let name = "chat-\(UUID().uuidString).jpg"
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent(name)
            try? data.write(to: url)
            imageFileName = name
        }
    }
}

// MARK: - Gemini

func sendToGemini(system: String, prompt: String, image: UIImage?, history: [ChatMessage] = [], apiKey: String, jsonMode: Bool = false, completion: @escaping (Result<String, Error>) -> Void) {
    var parts: [[String: Any]] = [["text": prompt]]

    if let image = image, let resized = resizeImage(image, maxSide: 512), let data = resized.jpegData(compressionQuality: 0.6) {
        let base64 = data.base64EncodedString()
        parts.append(["inline_data": ["mime_type": "image/jpeg", "data": base64]])
    }

    // Earlier turns go in as real conversation history so the model can remember them.
    // Past photos are summarised as text to keep requests small.
    var contents: [[String: Any]] = history
        .filter { !$0.content.hasPrefix("Sorry, I hit an error") && !$0.content.hasPrefix("Please save your Gemini API key") }
        .map { msg in
            let text = msg.imageFileName == nil ? msg.content : "[photo attached] \(msg.content)"
            return ["role": msg.role == "user" ? "user" : "model", "parts": [["text": text]]]
        }
    contents.append(["role": "user", "parts": parts])

    var body: [String: Any] = [
        "systemInstruction": ["parts": [["text": system]]],
        "contents": contents
    ]
    if jsonMode {
        body["generationConfig"] = ["responseMimeType": "application/json"]
    }

    let bodyData: Data
    do {
        bodyData = try JSONSerialization.data(withJSONObject: body, options: [])
    } catch {
        completion(.failure(error))
        return
    }

    geminiAttempt(bodyData: bodyData, apiKey: apiKey, modelIndex: 0, tryNumber: 1, completion: completion)
}

let geminiModels = ["gemini-3.5-flash", "gemini-3.5-flash-lite", "gemini-3.1-flash-lite"]
private let retryableStatuses: Set<Int> = [429, 500, 502, 503, 504]

private func geminiAttempt(bodyData: Data, apiKey: String, modelIndex: Int, tryNumber: Int, completion: @escaping (Result<String, Error>) -> Void) {
    let encodedKey = apiKey.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? apiKey
    let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/\(geminiModels[modelIndex]):generateContent?key=\(encodedKey)"
    guard let url = URL(string: endpoint) else { return }
    var request = URLRequest(url: url, timeoutInterval: 90)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = bodyData

    URLSession.shared.dataTask(with: request) { data, response, error in
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let retrySameModel = retryableStatuses.contains(status) && status != 429 && tryNumber < 2
        let tryNextModel = (retryableStatuses.contains(status) || status == 404) && modelIndex + 1 < geminiModels.count

        if retrySameModel || tryNextModel {
            let delay = retrySameModel ? 1.5 : 0.5
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                geminiAttempt(bodyData: bodyData, apiKey: apiKey,
                              modelIndex: retrySameModel ? modelIndex : modelIndex + 1,
                              tryNumber: retrySameModel ? tryNumber + 1 : 1,
                              completion: completion)
            }
            return
        }

        if let error = error {
            completion(.failure(error))
            return
        }
        guard let data = data else {
            completion(.failure(NSError(domain: "Gemini", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data"])))
            return
        }
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let errorObj = json["error"] as? [String: Any],
                   let message = errorObj["message"] as? String {
                    let friendly = retryableStatuses.contains(status)
                        ? "Gemini is busy right now (all models tried). Please wait a minute and try again."
                        : message
                    completion(.failure(NSError(domain: "Gemini", code: status, userInfo: [NSLocalizedDescriptionKey: friendly])))
                } else if let candidates = json["candidates"] as? [[String: Any]],
                          let first = candidates.first,
                          let content = first["content"] as? [String: Any],
                          let cParts = content["parts"] as? [[String: Any]] {
                    let text = cParts.filter { ($0["thought"] as? Bool) != true }.compactMap { $0["text"] as? String }.joined()
                    if text.isEmpty {
                        let raw = String(data: data, encoding: .utf8) ?? ""
                        completion(.failure(NSError(domain: "Gemini", code: -1, userInfo: [NSLocalizedDescriptionKey: "Empty reply: \(raw)"])))
                    } else {
                        completion(.success(text))
                    }
                } else {
                    let raw = String(data: data, encoding: .utf8) ?? ""
                    completion(.failure(NSError(domain: "Gemini", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unexpected response: \(raw)"])))
                }
            } else {
                let raw = String(data: data, encoding: .utf8) ?? ""
                completion(.failure(NSError(domain: "Gemini", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response: \(raw)"])))
            }
        } catch {
            let raw = String(data: data, encoding: .utf8) ?? ""
            completion(.failure(NSError(domain: "Gemini", code: -1, userInfo: [NSLocalizedDescriptionKey: "Decode failed: \(raw)"])))
        }
    }.resume()
}

func resizeImage(_ image: UIImage, maxSide: CGFloat) -> UIImage? {
    let size = image.size
    let scale = min(maxSide / size.width, maxSide / size.height, 1.0)
    if scale == 1.0 { return image }
    let newSize = CGSize(width: size.width * scale, height: size.height * scale)
    return UIGraphicsImageRenderer(size: newSize).image { _ in
        image.draw(in: CGRect(origin: .zero, size: newSize))
    }
}

func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

// MARK: - Chart

struct LineChart: View {
    let points: [ChartPoint]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height - 16
            let values = points.map(\.value)
            let minV = values.min() ?? 0
            let maxV = values.max() ?? 0
            let pad = max(1.0, maxV - minV) * 0.15
            let yMin = minV - pad
            let yRange = (maxV + pad) - yMin
            let stepX = width / CGFloat(max(points.count - 1, 1))
            let coords = values.enumerated().map { index, value in
                CGPoint(x: CGFloat(index) * stepX, y: 8 + height - ((value - yMin) / yRange) * height)
            }

            ZStack {
                ForEach(0..<4) { i in
                    Path { path in
                        let y = 8 + height * CGFloat(i) / 3
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                    }
                    .stroke(Color.secondary.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [4]))
                }

                Path { path in
                    guard let first = coords.first, let last = coords.last else { return }
                    path.move(to: CGPoint(x: first.x, y: geo.size.height))
                    coords.forEach { path.addLine(to: $0) }
                    path.addLine(to: CGPoint(x: last.x, y: geo.size.height))
                    path.closeSubpath()
                }
                .fill(LinearGradient(colors: [color.opacity(0.35), color.opacity(0.02)], startPoint: .top, endPoint: .bottom))

                Path { path in
                    guard let first = coords.first else { return }
                    path.move(to: first)
                    coords.dropFirst().forEach { path.addLine(to: $0) }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                ForEach(Array(coords.enumerated()), id: \.offset) { index, point in
                    Circle()
                        .fill(.white)
                        .overlay(Circle().stroke(color, lineWidth: 2.5))
                        .frame(width: index == coords.count - 1 ? 12 : 8, height: index == coords.count - 1 ? 12 : 8)
                        .position(point)
                }

                VStack {
                    HStack {
                        Spacer()
                        Text(String(format: "%.1f", maxV)).font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    HStack {
                        Spacer()
                        Text(String(format: "%.1f", minV)).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

/// Target line (dashed) with actual values (solid) on the same week axis; `actual` may have gaps.
struct ProgressChart: View {
    let target: [Double]
    let actual: [Double?]
    let currentIndex: Int
    let targetColor: Color
    let actualColor: Color

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height - 16
            let all = target + actual.compactMap { $0 }
            let minV = all.min() ?? 0
            let maxV = all.max() ?? 0
            let pad = max(1.0, maxV - minV) * 0.15
            let yMin = minV - pad
            let yRange = (maxV + pad) - yMin
            let stepX = width / CGFloat(max(target.count - 1, 1))
            let point = { (i: Int, v: Double) in CGPoint(x: CGFloat(i) * stepX, y: 8 + height - ((v - yMin) / yRange) * height) }
            let targetPts = target.enumerated().map { point($0.offset, $0.element) }
            let actualPts = actual.enumerated().compactMap { i, v in v.map { point(i, $0) } }

            ZStack {
                ForEach(0..<4) { i in
                    Path { path in
                        let y = 8 + height * CGFloat(i) / 3
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                    }
                    .stroke(Color.secondary.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [4]))
                }

                if currentIndex >= 0 {
                    Path { path in
                        let x = CGFloat(currentIndex) * stepX
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geo.size.height))
                    }
                    .stroke(actualColor.opacity(0.25), lineWidth: 1.5)
                }

                Path { path in
                    guard let first = targetPts.first else { return }
                    path.move(to: first)
                    targetPts.dropFirst().forEach { path.addLine(to: $0) }
                }
                .stroke(targetColor.opacity(0.7), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 4]))

                Path { path in
                    guard let first = actualPts.first, let last = actualPts.last else { return }
                    path.move(to: CGPoint(x: first.x, y: geo.size.height))
                    actualPts.forEach { path.addLine(to: $0) }
                    path.addLine(to: CGPoint(x: last.x, y: geo.size.height))
                    path.closeSubpath()
                }
                .fill(LinearGradient(colors: [actualColor.opacity(0.3), actualColor.opacity(0.02)], startPoint: .top, endPoint: .bottom))

                Path { path in
                    guard let first = actualPts.first else { return }
                    path.move(to: first)
                    actualPts.dropFirst().forEach { path.addLine(to: $0) }
                }
                .stroke(actualColor, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                ForEach(Array(actualPts.enumerated()), id: \.offset) { index, p in
                    Circle()
                        .fill(.white)
                        .overlay(Circle().stroke(actualColor, lineWidth: 2.5))
                        .frame(width: index == actualPts.count - 1 ? 12 : 8, height: index == actualPts.count - 1 ? 12 : 8)
                        .position(p)
                }

                VStack {
                    HStack {
                        Spacer()
                        Text(String(format: "%.1f", maxV)).font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    HStack {
                        Spacer()
                        Text(String(format: "%.1f", minV)).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Physique (AI Body Fat & Projections)

struct PhysiqueView: View {
    @ObservedObject var store: Store
    @AppStorage("geminiAPIKey") private var apiKey: String = ""
    @State private var photoImage: UIImage?
    @State private var photoFileName: String?
    @State private var weightInput = ""
    @State private var heightInput = ""
    @State private var ageInput = ""
    @State private var sex = "male"
    @State private var estimating = false
    @State private var estimateError: String?
    @State private var scan: PhysiqueScan?
    @State private var generating = false
    @State private var generatingTarget: Double?
    @State private var generateError: String?
    @State private var selectedTarget: Double?
    @State private var viewerStart: UUID?
    @State private var previewPage = 0
    @State private var sliderPosition: CGFloat = 0.5
    @State private var showCompare = false

    private var currentPhoto: UIImage? { photoImage }
    private var availableTargets: [Double] {
        guard let s = scan else { return [] }
        var targets: [Double] = []
        for bf in stride(from: Int(s.bodyFat) - 2, through: 8, by: -2) {
            if bf >= 8 { targets.append(Double(bf)) }
        }
        return targets
    }

    private var previewItems: [(label: String, image: UIImage?, fileName: String?)] {
        var items: [(String, UIImage?, String?)] = []
        if let img = photoImage { items.append(("Current", img, photoFileName)) }
        if let s = scan {
            for (bf, fname) in s.generated.sorted(by: { Double($0.key) ?? 0 < Double($1.key) ?? 0 }) {
                let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent(fname)
                items.append(("AI preview · \(bf)% · \(targetWeight(for: Double(bf) ?? 0))", UIImage(contentsOfFile: url.path), fname))
            }
        }
        return items
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    heroCard
                    photoCard
                    if let s = scan { resultCard(s) }
                    if let s = scan { planCard(s) }
                    if let s = scan { compareCard(s) }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Physique")
            .navigationDestination(item: $viewerStart) { id in
                PhotoViewer(store: store, logs: store.photoLogs, startID: id)
            }
            .keyboardDoneButton()
            .onAppear { restoreLatestScan() }
            .toolbar {
                if scan != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("New scan") {
                            withAnimation(.snappy) { scan = nil; photoImage = nil; photoFileName = nil; selectedTarget = nil; generateError = nil }
                        }
                    }
                }
            }
        }
    }

    private var heroCard: some View {
        HeroCard(gradient: Theme.weight) {
            HStack {
                Label("AI Body Fat", systemImage: "figure")
                    .font(.headline.weight(.bold))
                Spacer()
                Text("Powered by Gemini")
                    .font(.caption.weight(.semibold))
                    .opacity(0.85)
            }
            .foregroundStyle(.white)
        }
    }

    private var photoCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "Your Photo", icon: "camera.fill", color: Theme.weightColor)

            if let img = photoImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(alignment: .topTrailing) {
                        Button {
                            photoImage = nil
                            photoFileName = nil
                            scan = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .background(Circle().fill(.black.opacity(0.5)))
                        }
                        .padding(8)
                    }
            } else {
                PhotoSourceButton(
                    image: $photoImage,
                    fileName: $photoFileName,
                    recentLogs: store.photoLogs,
                    onSelect: { img, fname in photoImage = img; photoFileName = fname }
                )
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading) {
                    TextField("Weight", text: $weightInput)
                        .keyboardType(.decimalPad)
                        .font(.subheadline.weight(.medium))
                    Text(store.unit.title).font(.caption).foregroundStyle(.secondary)
                }
                .inputField()

                VStack(alignment: .leading) {
                    TextField("Height (cm, opt.)", text: $heightInput)
                        .keyboardType(.decimalPad)
                        .font(.subheadline.weight(.medium))
                }
                .inputField()

                VStack(alignment: .leading) {
                    TextField("Age (opt.)", text: $ageInput)
                        .keyboardType(.numberPad)
                        .font(.subheadline.weight(.medium))
                }
                .inputField()
            }

            Picker("Sex", selection: $sex) {
                Text("Male").tag("male")
                Text("Female").tag("female")
            }
            .pickerStyle(.segmented)

            Button {
                estimateBodyFat()
            } label: {
                HStack {
                    if estimating { ProgressView().tint(.white) }
                    Label("Estimate My Body Fat", systemImage: "sparkles")
                }
            }
            .buttonStyle(GradientButtonStyle(gradient: Theme.weight))
            .disabled(photoImage == nil || weightInput.isEmpty || estimating)

            if let err = estimateError {
                Label(err, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .card()
    }

    private func resultCard(_ s: PhysiqueScan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Estimate", icon: "percent", color: Theme.weightColor)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", s.bodyFat))
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.weightColor)
                Text("%")
                    .font(.title.weight(.bold))
                    .foregroundStyle(Theme.weightColor)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("likely range")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.0f–%.0f%%", s.low, s.high))
                        .font(.subheadline.weight(.bold))
                }
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading) {
                    Text("Weight").font(.caption).foregroundStyle(.secondary)
                    Text(store.display(weightKg: s.weightKg)).font(.headline.weight(.semibold))
                }
                VStack(alignment: .leading) {
                    Text("Lean Mass").font(.caption).foregroundStyle(.secondary)
                    Text(String(format: "%.1f kg", s.weightKg * (1 - s.bodyFat / 100))).font(.headline.weight(.semibold))
                }
                VStack(alignment: .leading) {
                    Text("Fat Mass").font(.caption).foregroundStyle(.secondary)
                    Text(String(format: "%.1f kg", s.weightKg * s.bodyFat / 100)).font(.headline.weight(.semibold))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(s.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !s.cues.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(s.cues, id: \.self) { cue in
                        Label(cue, systemImage: "checkmark.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Button {
                store.addBodyFat(date: Date(), percent: s.bodyFat)
            } label: {
                Label("Save to my body fat log", systemImage: "arrow.down.doc.fill")
            }
            .buttonStyle(.bordered)
            .tint(Theme.weightColor)
        }
        .card()
    }

    private func planCard(_ s: PhysiqueScan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Body Fat → Weight Plan", icon: "target", color: Theme.weightColor)

            VStack(spacing: 0) {
                ForEach(availableTargets, id: \.self) { bf in
                    let targetKg = targetWeightKg(for: bf)
                    let lossKg = s.weightKg - targetKg
                    let weeks = lossKg / (s.weightKg * 0.0075)
                    HStack {
                        Text(String(format: "%.0f%%", bf))
                            .font(.headline.weight(.bold))
                            .frame(width: 40, alignment: .leading)
                        Spacer()
                        Text(store.display(weightKg: targetKg))
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text(String(format: "−%.1f kg", lossKg))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.green)
                        Spacer()
                        Text(String(format: "~%.0f wks", weeks))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedTarget = bf }
                    .background(selectedTarget == bf ? Theme.weightColor.opacity(0.08) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .card()
    }

    private func compareCard(_ s: PhysiqueScan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Side by Side", icon: "rectangle.split.2x1", color: Theme.weightColor)

            Text("Pick a body fat level, then Generate to see an AI photo of you at that level.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(availableTargets, id: \.self) { bf in
                        let key = String(format: "%.0f", bf)
                        let done = s.generated[key] != nil
                        let active = selectedTarget == bf
                        Button {
                            withAnimation(.snappy) { selectedTarget = bf }
                            UISelectionFeedbackGenerator().selectionChanged()
                        } label: {
                            HStack(spacing: 4) {
                                if done { Image(systemName: "checkmark").font(.caption2.weight(.bold)) }
                                if generating && generatingTarget == bf { ProgressView().controlSize(.mini) }
                                Text("\(key)%").font(.subheadline.weight(.bold))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .foregroundStyle(active ? .white : Theme.weightColor)
                            .background(Capsule().fill(active ? AnyShapeStyle(Theme.weight) : AnyShapeStyle(Theme.weightColor.opacity(0.12))))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if let err = generateError {
                Label(err, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if let bf = selectedTarget {
                let hasImage = s.generated[String(format: "%.0f", bf)] != nil
                if hasImage, let img = generatedImage(for: bf) {
                    VStack(spacing: 8) {
                        Picker("Mode", selection: $showCompare) {
                            Text("Slider").tag(false)
                            Text("Side by side").tag(true)
                        }
                        .pickerStyle(.segmented)

                        if showCompare {
                            HStack(spacing: 8) {
                                comparePane(photoImage ?? UIImage(), label: "Now · \(String(format: "%.0f", s.bodyFat))%")
                                comparePane(img, label: "AI · \(String(format: "%.0f", bf))% · \(targetWeight(for: bf))")
                            }
                        } else {
                            GeometryReader { geo in
                                let w = geo.size.width
                                ZStack(alignment: .leading) {
                                    Image(uiImage: img).resizable().scaledToFill()
                                        .frame(width: w, height: geo.size.height).clipped()
                                    Image(uiImage: photoImage ?? UIImage()).resizable().scaledToFill()
                                        .frame(width: w, height: geo.size.height).clipped()
                                        .mask(alignment: .leading) { Rectangle().frame(width: w * sliderPosition) }
                                    Rectangle().fill(.white).frame(width: 3)
                                        .shadow(radius: 3)
                                        .offset(x: w * sliderPosition - 1.5)
                                    Circle().fill(.white).frame(width: 32, height: 32)
                                        .overlay(Image(systemName: "arrow.left.and.right").font(.caption.weight(.bold)).foregroundStyle(.black))
                                        .shadow(radius: 3)
                                        .offset(x: w * sliderPosition - 16, y: 0)
                                        .frame(maxHeight: .infinity, alignment: .center)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                                    sliderPosition = min(max(value.location.x / w, 0), 1)
                                })
                            }
                            .aspectRatio(3/4, contentMode: .fit)

                            HStack {
                                Text("Now · \(String(format: "%.0f", s.bodyFat))%")
                                Spacer()
                                Text("Drag to compare")
                                Spacer()
                                Text("AI · \(String(format: "%.0f", bf))% · \(targetWeight(for: bf))")
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        }

                        HStack {
                            Button { generateImage(for: bf) } label: {
                                Label("Regenerate", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.bordered)
                            .disabled(generating)
                            Spacer()
                            Text("~7¢ per image")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    if generating, let img = photoImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .blur(radius: 6)
                            .overlay {
                                VStack(spacing: 10) {
                                    ProgressView().tint(.white).controlSize(.large)
                                    Text("Sculpting \(String(format: "%.0f", bf))%…")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    Text("Usually 5–15 seconds")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.8))
                                }
                                .padding()
                                .background(RoundedRectangle(cornerRadius: 14).fill(.black.opacity(0.45)))
                            }
                            .frame(maxHeight: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        Button {
                            generateImage(for: bf)
                        } label: {
                            Label("Generate \(String(format: "%.0f", bf))% Preview", systemImage: "wand.and.stars")
                        }
                        .buttonStyle(GradientButtonStyle(gradient: Theme.weight))
                        .disabled(generating)
                        Text("You at \(String(format: "%.0f", bf))% would weigh about \(targetWeight(for: bf)) \(store.unit.title). Costs about 7¢ (paid Gemini).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("Tap a body fat level above to see your AI preview.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !s.generated.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your AI previews")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(s.generated.keys.sorted(), id: \.self) { key in
                                if let img = generatedImage(for: Double(key) ?? 0) {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 60, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(selectedTarget == (Double(key) ?? 0) ? RoundedRectangle(cornerRadius: 8).stroke(Theme.weightColor, lineWidth: 2) : nil)
                                        .onTapGesture { selectedTarget = Double(key) ?? 0 }
                                }
                            }
                        }
                    }
                }
            }
        }
        .card()
    }

    private func comparePane(_ img: UIImage, label: String) -> some View {
        VStack(spacing: 6) {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .aspectRatio(3/4, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private func targetWeightKg(for bf: Double) -> Double {
        guard let s = scan else { return 0 }
        let leanKg = s.weightKg * (1 - s.bodyFat / 100)
        return leanKg / (1 - bf / 100)
    }

    private func targetWeight(for bf: Double) -> String {
        store.display(weightKg: targetWeightKg(for: bf))
    }

    private func generatedImage(for bf: Double) -> UIImage? {
        guard let s = scan, let fname = s.generated[String(format: "%.0f", bf)] else { return nil }
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent(fname)
        return UIImage(contentsOfFile: url.path)
    }

    private func estimateBodyFat() {
        guard let img = photoImage, let weight = parseNumber(weightInput) else { return }
        estimating = true
        estimateError = nil

        Task {
            do {
                let kg = store.unit == .lb ? weight / 2.20462262 : weight
                let result = try await GeminiService.estimateBodyFat(
                    image: img,
                    weightKg: kg,
                    sex: sex,
                    age: Int(ageInput),
                    heightCm: Double(heightInput),
                    apiKey: apiKey
                )

                let fname = savePhoto(img)
                let newScan = PhysiqueScan(
                    id: UUID(),
                    date: Date(),
                    photoFileName: fname,
                    weightKg: kg,
                    sex: sex,
                    bodyFat: result.bodyFat,
                    low: result.low,
                    high: result.high,
                    summary: result.summary,
                    cues: result.cues
                )
                store.scans.append(newScan)
                withAnimation(.snappy) { scan = newScan; selectedTarget = availableTargetsFor(newScan).first }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                estimating = false
            } catch {
                estimateError = error.localizedDescription
                estimating = false
            }
        }
    }

    private func availableTargetsFor(_ s: PhysiqueScan) -> [Double] {
        stride(from: Int(s.bodyFat) - 2, through: 8, by: -2).filter { $0 >= 8 }.map(Double.init)
    }

    private func generateImage(for bf: Double) {
        guard let img = photoImage, let s = scan else { return }
        generating = true
        generatingTarget = bf
        generateError = nil

        Task {
            do {
                let result = try await GeminiService.generateBodyImage(
                    image: img,
                    currentBF: s.bodyFat,
                    targetBF: bf,
                    sex: sex,
                    apiKey: apiKey
                )

                let fname = savePhoto(result)
                var updated = s
                updated.generated[String(format: "%.0f", bf)] = fname
                withAnimation(.snappy) { scan = updated }
                if let idx = store.scans.firstIndex(where: { $0.id == s.id }) { store.scans[idx] = updated } else { store.scans.append(updated) }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch {
                generateError = error.localizedDescription
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
            generating = false
            generatingTarget = nil
        }
    }

    /// Restore the most recent scan (and its previews) when the tab opens.
    private func restoreLatestScan() {
        guard scan == nil, let latest = store.scans.last else { return }
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent(latest.photoFileName)
        guard let img = UIImage(contentsOfFile: url.path) else { return }
        photoImage = img
        photoFileName = latest.photoFileName
        sex = latest.sex
        weightInput = store.display(weightKg: latest.weightKg)
        scan = latest
        selectedTarget = latest.generated.keys.compactMap(Double.init).max() ?? availableTargetsFor(latest).first
    }

    private func savePhoto(_ img: UIImage) -> String {
        let name = "\(UUID().uuidString).jpg"
        if let data = img.jpegData(compressionQuality: 0.85) {
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent(name)
            try? data.write(to: url)
        }
        return name
    }
}

// MARK: - Photo Source Button

struct PhotoSourceButton: View {
    @Binding var image: UIImage?
    @Binding var fileName: String?
    let recentLogs: [WeightLog]
    var onSelect: (UIImage, String?) -> Void
    @State private var showPicker = false
    @State private var showCamera = false
    @State private var showRecent = false

    var body: some View {
        VStack(spacing: 8) {
            Button { showPicker = true } label: {
                HStack {
                    Image(systemName: "photo.on.rectangle.angled")
                    Text("Choose Photo")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray5)))
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button { showCamera = true } label: {
                        Label("Take Photo", systemImage: "camera.fill")
                    }
                    .buttonStyle(.bordered)
                }
                if !recentLogs.isEmpty {
                    Button { showRecent = true } label: {
                        Label("Recent", systemImage: "clock.fill")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .sheet(isPresented: $showPicker) {
            ImagePicker(image: $image, sourceType: .photoLibrary)
        }
        .fullScreenCover(isPresented: $showCamera) {
            TimerCameraView(image: $image)
        }
        .confirmationDialog("Recent Photos", isPresented: $showRecent) {
            ForEach(recentLogs.prefix(5)) { log in
                if let name = log.photoFileName {
                    Button("\(log.date.formatted(date: .abbreviated, time: .omitted))") {
                        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent(name)
                        if let img = UIImage(contentsOfFile: url.path) {
                            image = img
                            fileName = name
                            onSelect(img, name)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Progress Photos (thumbnails, viewer, gallery)

struct PhotoViewerStart: Identifiable {
    let id: UUID
}

/// Loads a downscaled copy of a stored photo off the main thread so grids and lists stay smooth.
struct PhotoThumbnail: View {
    let url: URL?
    private static let cache = NSCache<NSURL, UIImage>()
    @State private var image: UIImage?

    var body: some View {
        Rectangle()
            .fill(Theme.weightColor.opacity(0.12))
            .overlay {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    ProgressView()
                }
            }
            .clipped()
            .task(id: url) {
                guard let url else { return }
                if let cached = Self.cache.object(forKey: url as NSURL) { image = cached; return }
                let loaded = await Task.detached(priority: .userInitiated) { () -> UIImage? in
                    guard let full = UIImage(contentsOfFile: url.path), full.size.width > 0 else { return nil }
                    let width: CGFloat = 400
                    return full.preparingThumbnail(of: CGSize(width: width, height: width * full.size.height / full.size.width))
                }.value
                if let loaded { Self.cache.setObject(loaded, forKey: url as NSURL) }
                image = loaded
            }
    }
}

/// Full-resolution photo with pinch-to-zoom, double-tap zoom, and panning while zoomed.
struct ZoomablePhoto: View {
    let url: URL?
    @State private var image: UIImage?
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(offset)
                        .frame(width: geo.size.width, height: geo.size.height)
                } else {
                    ProgressView().tint(.white)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                MagnifyGesture()
                    .onChanged { value in scale = min(max(1, lastScale * value.magnification), 5) }
                    .onEnded { _ in
                        lastScale = scale
                        if scale == 1 { withAnimation(.snappy) { offset = .zero }; lastOffset = .zero }
                    }
            )
            .gesture(
                DragGesture()
                    .onChanged { value in
                        offset = CGSize(width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height)
                    }
                    .onEnded { _ in lastOffset = offset },
                including: scale > 1 ? .all : .none
            )
            .onTapGesture(count: 2) {
                withAnimation(.snappy) {
                    scale = scale > 1 ? 1 : 2.5
                    lastScale = scale
                    offset = .zero
                    lastOffset = .zero
                }
            }
        }
        .task(id: url) {
            guard let url else { return }
            image = await Task.detached(priority: .userInitiated) { UIImage(contentsOfFile: url.path) }.value
        }
    }
}

struct PhotoViewer: View {
    @ObservedObject var store: Store
    let logs: [WeightLog]
    @State private var selection: UUID
    @State private var currentAngle: String = "front"
    @State private var shareImages: [UIImage] = []
    @State private var showShare = false
    @Environment(\.dismiss) private var dismiss

    init(store: Store, logs: [WeightLog], startID: UUID) {
        self.store = store
        self.logs = logs
        _selection = State(initialValue: startID)
    }

    private var current: WeightLog? { logs.first { $0.id == selection } }
    private var position: Int { (logs.firstIndex { $0.id == selection } ?? 0) + 1 }
    private var availableAngles: [String] {
        guard let current = current else { return [] }
        var angles: [String] = []
        if current.photoFileName != nil { angles.append("front") }
        angles.append(contentsOf: current.additionalPhotos.keys)
        return angles
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let current, let url = store.photoURL(for: current, angle: currentAngle) {
                ZoomablePhoto(url: url)
            } else {
                Color.black
            }

            VStack {
                HStack(alignment: .top) {
                    viewerButton("xmark") { dismiss() }
                    Spacer()
                    if let current {
                        VStack(spacing: 2) {
                            Text(current.date, format: .dateTime.weekday(.wide).month().day().year())
                                .font(.subheadline.weight(.semibold))
                            Text("\(store.display(weightKg: current.weightKg)) \(store.unit.title)")
                                .font(.headline.weight(.heavy))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(.black.opacity(0.45)))
                    }
                    Spacer()
                    viewerButton("square.and.arrow.up") {
                        if let current, let url = store.photoURL(for: current, angle: currentAngle), let image = UIImage(contentsOfFile: url.path) {
                            shareImages = [image]
                            showShare = true
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

                Spacer()

                if availableAngles.count > 1 {
                    Picker("Angle", selection: $currentAngle) {
                        ForEach(availableAngles, id: \.self) { angle in
                            Text(angle.capitalized).tag(angle)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }

                HStack(spacing: 16) {
                    if position > 1 {
                        viewerButton("chevron.left") {
                            if let idx = logs.firstIndex(where: { $0.id == selection }), idx > 0 {
                                selection = logs[idx - 1].id
                                currentAngle = "front"
                            }
                        }
                    }
                    Spacer()
                    Text("\(position) of \(logs.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    if position < logs.count {
                        viewerButton("chevron.right") {
                            if let idx = logs.firstIndex(where: { $0.id == selection }), idx < logs.count - 1 {
                                selection = logs[idx + 1].id
                                currentAngle = "front"
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 12)
            }
        }
        .statusBarHidden()
        .sheet(isPresented: $showShare) { ShareSheet(items: shareImages) }
        .onChange(of: selection) { _, _ in currentAngle = "front" }
    }

    private func viewerButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(.black.opacity(0.45)))
        }
    }
}

struct PhotoGalleryView: View {
    @ObservedObject var store: Store
    @State private var selecting = false
    @State private var selected: Set<UUID> = []
    @State private var viewerStart: PhotoViewerStart?
    @State private var shareImages: [UIImage] = []
    @State private var showShare = false
    @State private var confirmDelete = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 3)

    var body: some View {
        let photos = store.photoLogs

        ScrollView {
            if photos.isEmpty {
                EmptyHint(icon: "photo.on.rectangle.angled", text: "No progress photos yet. Add one when you log your weight.")
                    .padding(.top, 60)
            } else {
                LazyVGrid(columns: columns, spacing: 3) {
                    ForEach(photos) { log in
                        Button {
                            if selecting {
                                if selected.contains(log.id) { selected.remove(log.id) } else { selected.insert(log.id) }
                            } else {
                                viewerStart = PhotoViewerStart(id: log.id)
                            }
                        } label: {
                            PhotoThumbnail(url: store.photoURL(for: log))
                                .aspectRatio(3 / 4, contentMode: .fit)
                                .overlay(alignment: .bottomLeading) {
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text(log.date, format: .dateTime.month(.abbreviated).day())
                                        Text("\(store.display(weightKg: log.weightKg)) \(store.unit.title)")
                                    }
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white)
                                    .shadow(color: .black.opacity(0.6), radius: 3)
                                    .padding(6)
                                }
                                .overlay(alignment: .topTrailing) {
                                    if selecting {
                                        Image(systemName: selected.contains(log.id) ? "checkmark.circle.fill" : "circle")
                                            .font(.title3)
                                            .foregroundStyle(selected.contains(log.id) ? Theme.weightColor : .white)
                                            .background(Circle().fill(.white).padding(3).opacity(selected.contains(log.id) ? 1 : 0))
                                            .shadow(radius: 2)
                                            .padding(6)
                                    }
                                }
                                .overlay {
                                    if selecting && selected.contains(log.id) {
                                        Rectangle().stroke(Theme.weightColor, lineWidth: 3)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 3)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(selecting ? "\(selected.count) Selected" : "Progress Photos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !photos.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(selecting ? "Done" : "Select") {
                        withAnimation(.snappy) {
                            selecting.toggle()
                            selected.removeAll()
                        }
                    }
                }
            }
            if selecting {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button(selected.count == photos.count ? "Deselect All" : "Select All") {
                        selected = selected.count == photos.count ? [] : Set(photos.map(\.id))
                    }
                    Spacer()
                    Button {
                        shareImages = photos.filter { selected.contains($0.id) }
                            .compactMap { store.photoURL(for: $0) }
                            .compactMap { UIImage(contentsOfFile: $0.path) }
                        showShare = !shareImages.isEmpty
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(selected.isEmpty)
                    Spacer()
                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(selected.isEmpty)
                }
            }
        }
        .tint(Theme.weightColor)
        .fullScreenCover(item: $viewerStart) { start in
            PhotoViewer(store: store, logs: photos, startID: start.id)
        }
        .sheet(isPresented: $showShare) { ShareSheet(items: shareImages) }
        .confirmationDialog("Delete \(selected.count) photo\(selected.count == 1 ? "" : "s")?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete Photos", role: .destructive) {
                store.removePhotos(selected)
                selected.removeAll()
                if store.photoLogs.isEmpty { selecting = false }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Only the photos are deleted. Your weight entries stay.")
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Photo Source + Timer Camera

struct PhotoSourcePicker: ViewModifier {
    let title: String
    @Binding var isPresented: Bool
    @Binding var image: UIImage?
    @State private var showLibrary = false
    @State private var showCamera = false

    func body(content: Content) -> some View {
        content
            .confirmationDialog(title, isPresented: $isPresented, titleVisibility: .visible) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Take Photo") { showCamera = true }
                }
                Button("Photo Library") { showLibrary = true }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showLibrary) {
                ImagePicker(image: $image, sourceType: .photoLibrary)
            }
            .fullScreenCover(isPresented: $showCamera) {
                TimerCameraView(image: $image)
            }
    }
}

extension View {
    func photoSourcePicker(title: String, isPresented: Binding<Bool>, image: Binding<UIImage?>) -> some View {
        modifier(PhotoSourcePicker(title: title, isPresented: isPresented, image: image))
    }
}

final class CameraController: NSObject, ObservableObject {
    let session = AVCaptureSession()
    @Published var position: AVCaptureDevice.Position = .front
    @Published var permissionDenied = false
    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "wlt.camera.session")
    private var photoDelegate: PhotoCaptureDelegate?

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configure()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted { self.configure() } else { self.permissionDenied = true }
                }
            }
        default:
            permissionDenied = true
        }
    }

    func stop() {
        let session = session
        queue.async { session.stopRunning() }
    }

    func flip() {
        position = position == .front ? .back : .front
        configure()
    }

    private func configure() {
        let session = session, output = output, position = position
        queue.async {
            session.beginConfiguration()
            session.sessionPreset = .photo
            session.inputs.forEach { session.removeInput($0) }
            if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
               let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) {
                session.addInput(input)
            }
            if !session.outputs.contains(output), session.canAddOutput(output) {
                session.addOutput(output)
            }
            session.commitConfiguration()
            if !session.isRunning { session.startRunning() }
        }
    }

    func capture(_ completion: @escaping (UIImage?) -> Void) {
        if let connection = output.connection(with: .video) {
            if connection.isVideoRotationAngleSupported(90) { connection.videoRotationAngle = 90 }
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = position == .front
            }
        }
        let delegate = PhotoCaptureDelegate { image in
            DispatchQueue.main.async {
                completion(image)
                self.photoDelegate = nil
            }
        }
        photoDelegate = delegate
        output.capturePhoto(with: AVCapturePhotoSettings(), delegate: delegate)
    }
}

nonisolated final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: @Sendable (UIImage?) -> Void

    init(completion: @escaping @Sendable (UIImage?) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        completion(photo.fileDataRepresentation().flatMap { UIImage(data: $0) })
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}
}

struct TimerCameraView: View {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = CameraController()
    @AppStorage("cameraTimerSeconds") private var timerSeconds = 5
    @State private var countdown: Int?
    @State private var countdownTask: Task<Void, Never>?
    @State private var captured: UIImage?
    @State private var flash = false

    private let timerOptions = [0, 3, 5, 10, 15]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let captured {
                Image(uiImage: captured)
                    .resizable()
                    .scaledToFit()
                    .ignoresSafeArea()
                reviewControls
            } else if camera.permissionDenied {
                permissionMessage
            } else {
                CameraPreview(session: camera.session)
                    .ignoresSafeArea()
                if let countdown {
                    Text("\(countdown)")
                        .font(.system(size: 160, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 12)
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.snappy, value: countdown)
                }
                Color.white.opacity(flash ? 0.8 : 0).ignoresSafeArea().allowsHitTesting(false)
                captureControls
            }
        }
        .statusBarHidden()
        .onAppear { camera.start() }
        .onDisappear {
            countdownTask?.cancel()
            camera.stop()
        }
    }

    private var captureControls: some View {
        VStack {
            HStack {
                circleButton("xmark") { dismiss() }
                Spacer()
                Menu {
                    Picker("Timer", selection: $timerSeconds) {
                        ForEach(timerOptions, id: \.self) { s in
                            Text(s == 0 ? "Off" : "\(s) seconds").tag(s)
                        }
                    }
                } label: {
                    Label(timerSeconds == 0 ? "Off" : "\(timerSeconds)s", systemImage: "timer")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(timerSeconds == 0 ? .white : .yellow)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(.black.opacity(0.45)))
                }
                .disabled(countdown != nil)
                Spacer()
                circleButton("arrow.triangle.2.circlepath.camera") { camera.flip() }
                    .disabled(countdown != nil)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            Spacer()

            Button {
                countdown == nil ? startCapture() : cancelCountdown()
            } label: {
                ZStack {
                    Circle().stroke(.white, lineWidth: 5).frame(width: 82, height: 82)
                    if countdown == nil {
                        Circle().fill(.white).frame(width: 66, height: 66)
                    } else {
                        RoundedRectangle(cornerRadius: 8).fill(.red).frame(width: 32, height: 32)
                    }
                }
            }
            .padding(.bottom, 12)

            Text(countdown == nil
                 ? (timerSeconds == 0 ? "Tap to take photo" : "Tap to start \(timerSeconds)s timer")
                 : "Tap to cancel")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.bottom, 24)
        }
    }

    private var reviewControls: some View {
        VStack {
            Spacer()
            HStack(spacing: 16) {
                Button {
                    captured = nil
                } label: {
                    Label("Retake", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(.black.opacity(0.55)))
                        .foregroundStyle(.white)
                }
                Button {
                    image = captured
                    dismiss()
                } label: {
                    Label("Use Photo", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(Theme.weight))
                        .foregroundStyle(.white)
                }
            }
            .font(.headline)
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }

    private var permissionMessage: some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.fill").font(.system(size: 40))
            Text("Camera access is off for this app.")
                .font(.headline)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            .buttonStyle(.borderedProminent)
            Button("Close") { dismiss() }
        }
        .foregroundStyle(.white)
        .padding()
    }

    private func circleButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(.black.opacity(0.45)))
        }
    }

    private func startCapture() {
        let seconds = timerSeconds
        countdownTask = Task {
            for remaining in stride(from: seconds, to: 0, by: -1) {
                countdown = remaining
                AudioServicesPlaySystemSound(1103)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
            }
            countdown = nil
            withAnimation(.easeOut(duration: 0.1)) { flash = true }
            camera.capture { photo in
                withAnimation(.easeOut(duration: 0.3)) { flash = false }
                captured = photo
            }
        }
    }

    private func cancelCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
        countdown = nil
    }
}

/// Camera for capturing front, back, and side photos.
struct MultiAngleCameraView: View {
    @Binding var images: [String: UIImage]
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = CameraController()
    @AppStorage("cameraTimerSeconds") private var timerSeconds = 5
    @State private var countdown: Int?
    @State private var countdownTask: Task<Void, Never>?
    @State private var captured: UIImage?
    @State private var flash = false
    @State private var currentAngle: AngleStep = .front

    enum AngleStep: String, CaseIterable, Identifiable {
        case front, back, side
        var id: String { rawValue }
        var title: String { rawValue.capitalized }
        var instruction: String {
            switch self {
            case .front: return "Face the camera directly"
            case .back: return "Turn around fully"
            case .side: return "Face sideways (profile view)"
            }
        }
        var icon: String {
            switch self {
            case .front: return "figure.stand"
            case .back: return "figure.stand.reverse"
            case .side: return "figure.stand.sidebar.left"
            }
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let captured {
                Image(uiImage: captured).resizable().scaledToFit().ignoresSafeArea()
                reviewControls
            } else if camera.permissionDenied {
                permissionMessage
            } else {
                CameraPreview(session: camera.session).ignoresSafeArea()
                if let countdown {
                    Text("\(countdown)").font(.system(size: 160, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                }
                Color.white.opacity(flash ? 0.8 : 0).ignoresSafeArea().allowsHitTesting(false)
                captureControls
            }
        }
        .statusBarHidden()
        .onAppear { camera.start() }
        .onDisappear { countdownTask?.cancel(); camera.stop() }
    }

    private var captureControls: some View {
        VStack {
            HStack {
                circleButton("xmark") { dismiss() }
                Spacer()
                HStack(spacing: 6) {
                    ForEach(AngleStep.allCases) { step in
                        let isCurrent = step == currentAngle, isDone = images[step.rawValue] != nil
                        Circle().fill(isCurrent ? .white : (isDone ? Theme.weightColor : .white.opacity(0.3))).frame(width: 24, height: 24)
                            .overlay(Group {
                                if isDone { Image(systemName: "checkmark").font(.caption2.weight(.bold)).foregroundStyle(.white) }
                            })
                    }
                }
                Spacer()
                circleButton("arrow.triangle.2.circlepath.camera") { camera.flip() }.disabled(countdown != nil)
            }.padding(.horizontal).padding(.top, 8)
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: currentAngle.icon).font(.system(size: 48)).foregroundStyle(.white)
                Text(currentAngle.title).font(.title2.weight(.heavy)).foregroundStyle(.white)
                Text(currentAngle.instruction).font(.subheadline).foregroundStyle(.white.opacity(0.85))
            }
            Spacer()
            Button { countdown == nil ? startCapture() : cancelCountdown() } label: {
                ZStack {
                    Circle().stroke(.white, lineWidth: 5).frame(width: 82, height: 82)
                    if countdown == nil { Circle().fill(.white).frame(width: 66, height: 66) }
                    else { RoundedRectangle(cornerRadius: 8).fill(.red).frame(width: 32, height: 32) }
                }
            }.padding(.bottom, 12)
            Text(countdown == nil ? (timerSeconds == 0 ? "Tap to take photo" : "Tap to start \(timerSeconds)s timer") : "Tap to cancel").font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.85)).padding(.bottom, 24)
        }
    }

    private var reviewControls: some View {
        VStack {
            Spacer()
            HStack(spacing: 16) {
                Button { captured = nil } label: { Label("Retake", systemImage: "arrow.counterclockwise").frame(maxWidth: .infinity).padding(.vertical, 14).background(Capsule().fill(.black.opacity(0.55))).foregroundStyle(.white) }
                Button {
                    images[currentAngle.rawValue] = captured
                    if let idx = AngleStep.allCases.firstIndex(of: currentAngle), let next = AngleStep.allCases[idx + 1..<AngleStep.allCases.count].first(where: { images[$0.rawValue] == nil }) {
                        currentAngle = next; captured = nil
                    } else { dismiss() }
                } label: {
                    let allDone = AngleStep.allCases.allSatisfy { images[$0.rawValue] != nil }
                    Label(allDone ? "Done" : "Next Angle", systemImage: allDone ? "checkmark" : "arrow.right").frame(maxWidth: .infinity).padding(.vertical, 14).background(Capsule().fill(Theme.weight)).foregroundStyle(.white)
                }
            }.font(.headline).padding(.horizontal).padding(.bottom, 24)
        }
    }

    private var permissionMessage: some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.fill").font(.system(size: 40))
            Text("Camera access is off for this app.").font(.headline)
            Button("Open Settings") { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }.buttonStyle(.borderedProminent)
            Button("Close") { dismiss() }
        }.foregroundStyle(.white).padding()
    }

    private func circleButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: icon).font(.headline).foregroundStyle(.white).frame(width: 44, height: 44).background(Circle().fill(.black.opacity(0.45))) }
    }

    private func startCapture() {
        guard timerSeconds > 0 else { takePhoto(); return }
        countdown = timerSeconds
        countdownTask = Task {
            for i in (1...timerSeconds).reversed() {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if !Task.isCancelled { countdown = i }
            }
            if !Task.isCancelled { countdown = nil; takePhoto() }
        }
    }

    private func cancelCountdown() { countdownTask?.cancel(); countdown = nil }

    private func takePhoto() {
        flash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { flash = false }
        camera.capture { if let img = $0 { captured = img } }
    }
}

// MARK: - Image Picker

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var sourceType: UIImagePickerController.SourceType

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Gemini API Service

struct GeminiService {
    private static let visionModels = [
        "gemini-2.0-flash",
        "gemini-2.5-flash",
        "gemini-3.1-flash-lite",
        "gemini-3.1-flash"
    ]
    private static let imageModels = [
        "gemini-nano-banana-2.1",
        "gemini-3.1-flash-image",
        "gemini-3.1-flash-lite-image"
    ]

    struct BodyFatResult {
        let bodyFat: Double
        let low: Double
        let high: Double
        let summary: String
        let cues: [String]
    }

    static func estimateBodyFat(image: UIImage, weightKg: Double, sex: String, age: Int?, heightCm: Double?, apiKey: String) async throws -> BodyFatResult {
        guard !apiKey.isEmpty else { throw GeminiError.noAPIKey }

        let base64 = image.jpegData(compressionQuality: 0.7)?.base64EncodedString() ?? ""
        var parts: [[String: Any]] = [
            ["text": """
            You are an expert fitness analyst. Estimate this person's body fat percentage.
            Provide: bodyFat (number), low (number), high (number), summary (2-3 sentences), cues (array of 2-4 observations).
            Person: \(sex), weight: \(String(format: "%.1f", weightKg)) kg\(age.map { ", age: \($0)" } ?? "")\(heightCm.map { ", height: \($0) cm" } ?? "")
            Respond with ONLY valid JSON.
            """],
            ["inline_data": ["mime_type": "image/jpeg", "data": base64]]
        ]

        for model in visionModels {
            do {
                let result = try await callGemini(model: model, parts: parts, apiKey: apiKey)
                if let json = parseJSON(result), let bf = json["bodyFat"] as? Double {
                    let low = json["low"] as? Double ?? max(bf - 3, 5)
                    let high = json["high"] as? Double ?? min(bf + 3, 50)
                    let summary = json["summary"] as? String ?? "Estimate based on visual analysis."
                    let cues = json["cues"] as? [String] ?? []
                    return BodyFatResult(bodyFat: bf, low: low, high: high, summary: summary, cues: cues)
                }
            } catch { continue }
        }
        throw GeminiError.allFailed
    }

    static func generateBodyImage(image: UIImage, currentBF: Double, targetBF: Double, sex: String, apiKey: String) async throws -> UIImage {
        guard !apiKey.isEmpty else { throw GeminiError.noAPIKey }

        let source = resizeImage(image, maxSide: 1024) ?? image
        let base64 = source.jpegData(compressionQuality: 0.85)?.base64EncodedString() ?? ""
        let prompt = """
        Edit this photo to show the same person at \(String(format: "%.0f", targetBF))% body fat (currently about \(String(format: "%.0f", currentBF))%).
        Keep the face, identity, pose, clothing, background, lighting, camera angle and skin tone exactly the same.
        Change only body composition: a leaner face and neck, smaller waist, flatter stomach, more visible muscle definition in arms, shoulders and torso, in proportion to the body fat drop.
        Keep it realistic and natural for a \(sex) at \(String(format: "%.0f", targetBF))% body fat. Do not exaggerate muscle size or add new clothing.
        Return only the edited photo.
        """

        // Interactions API (current Nano Banana endpoint); falls back through models on failure.
        var lastError: Error = GeminiError.allFailed
        for model in imageModels {
            do {
                return try await createImageInteraction(model: model, prompt: prompt, imageBase64: base64, apiKey: apiKey)
            } catch {
                lastError = error
                if case GeminiError.billing = error { throw error }
                if case GeminiError.blocked = error { throw error }
            }
        }
        throw lastError
    }

    private static func createImageInteraction(model: String, prompt: String, imageBase64: String, apiKey: String) async throws -> UIImage {
        var request = URLRequest(url: URL(string: "https://generativelanguage.googleapis.com/v1beta/interactions")!, timeoutInterval: 120)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": model,
            "input": [
                ["type": "text", "text": prompt],
                ["type": "image", "mime_type": "image/jpeg", "data": imageBase64]
            ]
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]

        if status != 200 {
            let message = ((json["error"] as? [String: Any])?["message"] as? String) ?? "HTTP \(status)"
            if status == 429 || message.localizedCaseInsensitiveContains("quota") || message.localizedCaseInsensitiveContains("billing") {
                throw GeminiError.billing(message)
            }
            throw GeminiError.server(message)
        }

        for step in json["steps"] as? [[String: Any]] ?? [] {
            for block in step["content"] as? [[String: Any]] ?? [] {
                if block["type"] as? String == "image", let b64 = block["data"] as? String,
                   let imgData = Data(base64Encoded: b64), let img = UIImage(data: imgData) {
                    return img
                }
            }
        }
        // No image came back: usually a safety refusal. Surface the model's text if it gave one.
        let text = (json["steps"] as? [[String: Any]])?
            .flatMap { $0["content"] as? [[String: Any]] ?? [] }
            .compactMap { $0["text"] as? String }.joined(separator: " ") ?? ""
        throw GeminiError.blocked(text)
    }

    private static func callGemini(model: String, parts: [[String: Any]], apiKey: String, expectImage: Bool = false) async throws -> String {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "contents": [["parts": parts]],
            "generationConfig": ["temperature": 0.4, "maxOutputTokens": 4096] as [String: Any]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw GeminiError.httpError
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let respParts = content["parts"] as? [[String: Any]] else {
            throw GeminiError.parseError
        }

        for part in respParts {
            if expectImage {
                if let inline = part["inline_data"] as? [String: Any], let b64 = inline["data"] as? String {
                    return b64
                }
            } else {
                if let text = part["text"] as? String {
                    return text
                }
            }
        }
        throw GeminiError.parseError
    }

    private static func parseJSON(_ text: String) -> [String: Any]? {
        let cleaned = text.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = cleaned.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return json
    }

    enum GeminiError: Error, LocalizedError {
        case noAPIKey, httpError, parseError, allFailed
        case billing(String), blocked(String), server(String)
        var errorDescription: String? {
            switch self {
            case .noAPIKey: return "Add your Gemini API key in Mr Olympia first."
            case .httpError: return "Network request failed. Check your connection."
            case .parseError: return "Could not read AI response."
            case .allFailed: return "AI service is currently unavailable. Try again later."
            case .billing(let m): return "Image generation needs billing enabled on your Gemini key (Google AI Studio → Billing). \(m)"
            case .blocked(let m): return m.isEmpty ? "Gemini declined to edit this photo (safety filter). Try a photo in a fitted shirt or sports top." : "Gemini didn't return an image: \(m)"
            case .server(let m): return m
            }
        }
    }
}

#Preview {
    ContentView()
}
