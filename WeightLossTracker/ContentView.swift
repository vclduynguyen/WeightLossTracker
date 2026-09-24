import SwiftUI
import UIKit
import Combine
import UserNotifications

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

    var currentWeek: Int {
        max(1, Int(Date().timeIntervalSince(createdAt) / 604_800) + 1)
    }
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
    private let docDir: URL

    init() {
        docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        unit = WeightUnit(rawValue: UserDefaults.standard.string(forKey: unitKey) ?? "kg") ?? .kg
        let goal = UserDefaults.standard.integer(forKey: goalKey)
        calorieGoal = goal > 0 ? goal : 2000
        logs = load(logsKey) ?? []
        foods = load(foodsKey) ?? []
        bodyFat = load(bodyFatKey) ?? []
        roadmap = load(roadmapKey)
        waist = load(waistKey) ?? []
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

    func deleteLog(_ log: WeightLog) {
        if let name = log.photoFileName {
            try? FileManager.default.removeItem(at: docDir.appendingPathComponent(name))
        }
        logs.removeAll { $0.id == log.id }
        persist(logs, logsKey)
    }

    func image(for fileName: String?) -> UIImage? {
        guard let fileName else { return nil }
        return UIImage(contentsOfFile: docDir.appendingPathComponent(fileName).path)
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
        foods(on: date).reduce(0) { $0 + $1.calories }
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
    @State private var selectedImage: UIImage?
    @State private var showSourcePicker = false
    @State private var showImagePicker = false
    @State private var imagePickerSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var waistInput = ""
    @State private var waistSunday = sundayOnOrBefore(Date())
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
                    if store.logs.count > 1 { graphCard }
                    if !store.logs.isEmpty { historyCard }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Weight")
            .toolbar {
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
            .confirmationDialog("Photo", isPresented: $showSourcePicker, titleVisibility: .visible) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Take Photo") {
                        imagePickerSource = .camera
                        showImagePicker = true
                    }
                }
                Button("Photo Library") {
                    imagePickerSource = .photoLibrary
                    showImagePicker = true
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage, sourceType: imagePickerSource)
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
        }
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
                    showSourcePicker = true
                } label: {
                    Group {
                        if let selectedImage {
                            Image(uiImage: selectedImage)
                                .resizable()
                                .scaledToFill()
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
                store.addLog(date: date, weight: weightInput, photo: selectedImage)
                weightInput = ""
                selectedImage = nil
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
                    if let uiImage = store.image(for: log.photoFileName) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 54, height: 54)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
        }
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
                prefill()
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
                Text("Goal · Week \(min(roadmap.currentWeek, roadmap.plan.totalWeeks)) of \(roadmap.plan.totalWeeks)")
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

            ProgressView(value: Double(min(roadmap.currentWeek, roadmap.plan.totalWeeks)), total: Double(max(roadmap.plan.totalWeeks, 1)))
                .tint(.white)

            HStack(spacing: 10) {
                StatTile(title: "Calories", value: "\(roadmap.plan.dailyCalories)", icon: "flame.fill")
                StatTile(title: "Steps", value: roadmap.plan.dailySteps.formatted(), icon: "figure.walk")
                StatTile(title: "Protein", value: "\(roadmap.plan.proteinGrams)g", icon: "fork.knife")
            }

            Button {
                store.calorieGoal = roadmap.plan.dailyCalories
            } label: {
                Label(store.calorieGoal == roadmap.plan.dailyCalories ? "Calorie goal synced" : "Use as my calorie goal",
                      systemImage: store.calorieGoal == roadmap.plan.dailyCalories ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
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

    private func weeklyTable(_ roadmap: Roadmap) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "Weekly Targets", icon: "calendar", color: Theme.roadmapColor)

            HStack(spacing: 6) {
                Text("Wk").frame(width: 36, alignment: .leading)
                unitHeader("Weight", unit: weightUnit) {
                    weightUnitBinding.wrappedValue = weightUnit == "lbs" ? "kg" : "lbs"
                }
                Text("Fat %").lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                unitHeader("Waist", unit: lengthUnit) {
                    lengthUnitBinding.wrappedValue = lengthUnit == "in" ? "cm" : "in"
                }
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)

            ForEach(roadmap.plan.milestones) { m in
                let isCurrent = m.week == roadmap.currentWeek
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("\(m.week)")
                            .font(.subheadline.weight(.heavy))
                            .frame(width: 36, alignment: .leading)
                        Text(String(format: "%.1f", convertWeight(m.weight, from: roadmap.weightUnit, to: weightUnit))).frame(maxWidth: .infinity, alignment: .leading)
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
                        .padding(.leading, 42)
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
    @State private var messages: [ChatMessage] = []
    @State private var isLoading = false
    @State private var selectedImage: UIImage?
    @State private var showSourcePicker = false
    @State private var showImagePicker = false
    @State private var imagePickerSource: UIImagePickerController.SourceType = .photoLibrary

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
                            withAnimation { messages.removeAll() }
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
            .confirmationDialog("Attach a photo", isPresented: $showSourcePicker, titleVisibility: .visible) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Take Photo") {
                        imagePickerSource = .camera
                        showImagePicker = true
                    }
                }
                Button("Photo Library") {
                    imagePickerSource = .photoLibrary
                    showImagePicker = true
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage, sourceType: imagePickerSource)
            }
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
            messages.append(ChatMessage(role: "assistant", content: "Please save your Gemini API key first. Get a free one at aistudio.google.com/app/apikey", image: nil))
            showKeyPanel = true
            return
        }

        let prompt = input.isEmpty ? "What do you think of my physique and what should I improve?" : input
        messages.append(ChatMessage(role: "user", content: prompt, image: selectedImage))
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
        \(roadmapText) \
        Give concise, encouraging, actionable advice using short bullet points. For calories and steps, provide reasonable estimates and explain. \
        Do not give medical diagnoses.
        """

        let image = selectedImage
        selectedImage = nil
        sendToGemini(system: system, prompt: prompt, image: image, apiKey: apiKey) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let reply):
                    messages.append(ChatMessage(role: "assistant", content: reply, image: nil))
                case .failure(let error):
                    messages.append(ChatMessage(role: "assistant", content: "Sorry, I hit an error: \(error.localizedDescription)", image: nil))
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

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: String
    let content: String
    let image: UIImage?
}

// MARK: - Gemini

func sendToGemini(system: String, prompt: String, image: UIImage?, apiKey: String, jsonMode: Bool = false, completion: @escaping (Result<String, Error>) -> Void) {
    var parts: [[String: Any]] = [["text": "\(system)\n\n\(prompt)"]]

    if let image = image, let resized = resizeImage(image, maxSide: 512), let data = resized.jpegData(compressionQuality: 0.6) {
        let base64 = data.base64EncodedString()
        parts.append(["inline_data": ["mime_type": "image/jpeg", "data": base64]])
    }

    var body: [String: Any] = [
        "contents": [
            ["role": "user", "parts": parts]
        ]
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

#Preview {
    ContentView()
}
