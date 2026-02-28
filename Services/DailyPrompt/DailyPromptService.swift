import Foundation

// MARK: - Daily Prompt Category
enum DailyPromptCategory: String, CaseIterable, Codable {
    case ideas = "ideas"
    case work = "work"
    case journal = "journal"
    
    var displayName: String {
        switch self {
        case .ideas: return "Ideas"
        case .work: return "Work"
        case .journal: return "Journal"
        }
    }
    
    var icon: String {
        switch self {
        case .ideas: return "lightbulb"
        case .work: return "briefcase"
        case .journal: return "book"
        }
    }
    
    var drawerKey: String { rawValue }
}

// MARK: - Daily Prompt
struct DailyPrompt: Codable, Identifiable {
    let id: String
    let category: DailyPromptCategory
    let text: String
    
    init(category: DailyPromptCategory, text: String) {
        self.id = "\(category.rawValue)_\(text.hashValue)"
        self.category = category
        self.text = text
    }
}

// MARK: - Daily Prompt Service
@MainActor
final class DailyPromptService: ObservableObject {
    static let shared = DailyPromptService()
    
    @Published var todaysPrompt: DailyPrompt
    @Published var currentStreak: Int = 0
    @Published var answeredToday: Bool = false
    @Published var longestStreak: Int = 0
    /// Last saved daily prompt card (for "View Answer" navigation)
    @Published var lastSavedCardId: UUID?
    @Published var lastSavedDrawerKey: String?
    
    private let defaults = UserDefaults.standard
    private let lastPromptDateKey = "Vaulted.dailyPrompt.lastDate"
    private let lastPromptIdKey = "Vaulted.dailyPrompt.lastPromptId"
    private let currentStreakKey = "Vaulted.dailyPrompt.currentStreak"
    private let longestStreakKey = "Vaulted.dailyPrompt.longestStreak"
    private let lastAnsweredDateKey = "Vaulted.dailyPrompt.lastAnsweredDate"
    private let graceDaysUsedKey = "Vaulted.dailyPrompt.graceDaysUsed"
    
    private init() {
        self.todaysPrompt = Self.promptPools[.journal]![0]
        loadState()
        refreshTodaysPrompt()
    }
    
    // MARK: - Prompt Pools
    private static let promptPools: [DailyPromptCategory: [DailyPrompt]] = [
        .ideas: [
            DailyPrompt(category: .ideas, text: "What's one idea you've been sitting on that deserves attention?"),
            DailyPrompt(category: .ideas, text: "If you had unlimited resources, what would you build?"),
            DailyPrompt(category: .ideas, text: "What problem have you noticed lately that needs a solution?"),
            DailyPrompt(category: .ideas, text: "What's something you wish existed but doesn't?"),
            DailyPrompt(category: .ideas, text: "Describe an idea that excites you right now."),
            DailyPrompt(category: .ideas, text: "What's a crazy idea you'd try if failure wasn't possible?"),
            DailyPrompt(category: .ideas, text: "What could you create that would help someone you know?"),
            DailyPrompt(category: .ideas, text: "What skill would you love to turn into a product or service?"),
            DailyPrompt(category: .ideas, text: "What's an idea you've dismissed that might actually work?"),
            DailyPrompt(category: .ideas, text: "If you started a side project tomorrow, what would it be?"),
        ],
        .work: [
            DailyPrompt(category: .work, text: "What's the one thing that would make today a win?"),
            DailyPrompt(category: .work, text: "What task have you been avoiding that needs to get done?"),
            DailyPrompt(category: .work, text: "What's blocking your progress right now?"),
            DailyPrompt(category: .work, text: "What did you accomplish today that you're proud of?"),
            DailyPrompt(category: .work, text: "What's your top priority for tomorrow?"),
            DailyPrompt(category: .work, text: "What decision do you need to make this week?"),
            DailyPrompt(category: .work, text: "What's one thing you could delegate or let go of?"),
            DailyPrompt(category: .work, text: "What lesson did you learn from a recent challenge?"),
            DailyPrompt(category: .work, text: "What skill do you want to improve at work?"),
            DailyPrompt(category: .work, text: "What would make your work life easier?"),
        ],
        .journal: [
            DailyPrompt(category: .journal, text: "What are you grateful for today?"),
            DailyPrompt(category: .journal, text: "How are you really feeling right now?"),
            DailyPrompt(category: .journal, text: "What's on your mind that you haven't told anyone?"),
            DailyPrompt(category: .journal, text: "What was the best part of your day?"),
            DailyPrompt(category: .journal, text: "What's one thing you'd like to let go of?"),
            DailyPrompt(category: .journal, text: "What's something you're looking forward to?"),
            DailyPrompt(category: .journal, text: "Describe a moment today that made you smile."),
            DailyPrompt(category: .journal, text: "What would you tell your past self from a year ago?"),
            DailyPrompt(category: .journal, text: "What's a small win you had recently?"),
            DailyPrompt(category: .journal, text: "What do you need more of in your life right now?"),
            DailyPrompt(category: .journal, text: "What are you worried about, and what can you do about it?"),
            DailyPrompt(category: .journal, text: "What made today different from yesterday?"),
        ]
    ]
    
    // MARK: - Public Methods
    
    func refreshTodaysPrompt() {
        let today = Calendar.current.startOfDay(for: Date())
        let lastDate = defaults.object(forKey: lastPromptDateKey) as? Date
        let lastDateStart = lastDate.map { Calendar.current.startOfDay(for: $0) }
        
        if lastDateStart == today, let lastId = defaults.string(forKey: lastPromptIdKey) {
            if let prompt = findPrompt(byId: lastId) {
                todaysPrompt = prompt
                return
            }
        }
        
        todaysPrompt = selectPromptForDate(today)
        defaults.set(today, forKey: lastPromptDateKey)
        defaults.set(todaysPrompt.id, forKey: lastPromptIdKey)
        
        checkAndUpdateStreak()
    }
    
    func setLastSavedCard(id: UUID, drawerKey: String) {
        lastSavedCardId = id
        lastSavedDrawerKey = drawerKey
    }
    
    func markPromptAnswered() {
        let today = Calendar.current.startOfDay(for: Date())
        let lastAnswered = defaults.object(forKey: lastAnsweredDateKey) as? Date
        let lastAnsweredStart = lastAnswered.map { Calendar.current.startOfDay(for: $0) }
        
        if lastAnsweredStart != today {
            currentStreak += 1
            if currentStreak > longestStreak {
                longestStreak = currentStreak
                defaults.set(longestStreak, forKey: longestStreakKey)
            }
            defaults.set(currentStreak, forKey: currentStreakKey)
            defaults.set(today, forKey: lastAnsweredDateKey)
        }
        
        answeredToday = true
    }
    
    func skipPrompt() -> DailyPrompt {
        let allPrompts = Self.promptPools[todaysPrompt.category] ?? []
        let otherPrompts = allPrompts.filter { $0.id != todaysPrompt.id }
        if let newPrompt = otherPrompts.randomElement() {
            todaysPrompt = newPrompt
            defaults.set(todaysPrompt.id, forKey: lastPromptIdKey)
            return newPrompt
        }
        return todaysPrompt
    }
    
    // MARK: - Private Methods
    
    private func loadState() {
        currentStreak = defaults.integer(forKey: currentStreakKey)
        longestStreak = defaults.integer(forKey: longestStreakKey)
        
        let today = Calendar.current.startOfDay(for: Date())
        if let lastAnswered = defaults.object(forKey: lastAnsweredDateKey) as? Date {
            let lastAnsweredStart = Calendar.current.startOfDay(for: lastAnswered)
            answeredToday = (lastAnsweredStart == today)
        }
    }
    
    private func checkAndUpdateStreak() {
        let today = Calendar.current.startOfDay(for: Date())
        guard let lastAnswered = defaults.object(forKey: lastAnsweredDateKey) as? Date else {
            answeredToday = false
            return
        }
        
        let lastAnsweredStart = Calendar.current.startOfDay(for: lastAnswered)
        let daysSince = Calendar.current.dateComponents([.day], from: lastAnsweredStart, to: today).day ?? 0
        
        if daysSince == 0 {
            answeredToday = true
        } else if daysSince == 1 {
            answeredToday = false
        } else if daysSince == 2 {
            let graceDaysUsed = defaults.integer(forKey: graceDaysUsedKey)
            let weekOfYear = Calendar.current.component(.weekOfYear, from: today)
            let lastGraceWeek = defaults.integer(forKey: "Vaulted.dailyPrompt.lastGraceWeek")
            
            if lastGraceWeek != weekOfYear && graceDaysUsed < 1 {
                defaults.set(weekOfYear, forKey: "Vaulted.dailyPrompt.lastGraceWeek")
                answeredToday = false
            } else {
                currentStreak = 0
                defaults.set(0, forKey: currentStreakKey)
                answeredToday = false
            }
        } else {
            currentStreak = 0
            defaults.set(0, forKey: currentStreakKey)
            answeredToday = false
        }
    }
    
    private func selectPromptForDate(_ date: Date) -> DailyPrompt {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        let categories = DailyPromptCategory.allCases
        let categoryIndex = dayOfYear % categories.count
        let category = categories[categoryIndex]
        
        let prompts = Self.promptPools[category] ?? []
        let promptIndex = (dayOfYear / categories.count) % prompts.count
        return prompts[promptIndex]
    }
    
    private func findPrompt(byId id: String) -> DailyPrompt? {
        for (_, prompts) in Self.promptPools {
            if let prompt = prompts.first(where: { $0.id == id }) {
                return prompt
            }
        }
        return nil
    }
}
