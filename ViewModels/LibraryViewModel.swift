import SwiftUI
import CoreData
import Combine
import Foundation

// MARK: - Library View Mode
enum LibraryViewMode: String, CaseIterable {
    case drawer = "Drawers"
    case shelf  = "Bookshelf"
    case stack  = "Stack"

    var systemImage: String {
        switch self {
        case .drawer: return "archivebox"
        case .shelf:  return "books.vertical"
        case .stack:  return "square.stack"
        }
    }
}

// MARK: - Bookshelf chronological pattern (weekly / daily / monthly)
enum BookshelfPeriod: String, CaseIterable {
    case weekly  = "Weekly"
    case daily   = "Daily"
    case monthly = "Monthly"
}

// MARK: - LibraryViewModel
@MainActor
final class LibraryViewModel: ObservableObject {

    @Published var viewMode: LibraryViewMode = .stack
    @Published var bookshelfPeriod: BookshelfPeriod = .weekly
    @Published var cards: [CardEntity] = []
    @Published var drawers: [DrawerEntity] = []
    @Published var searchQuery = ""
    @Published var isPrivateUnlocked = false

    let cardRepo: CardRepository
    let drawerRepo: DrawerRepository
    let securityService: SecurityService
    let filterDrawerKey: String?   // nil = all drawers

    private var cancellables = Set<AnyCancellable>()

    init(filterDrawerKey: String? = nil,
         cardRepo: CardRepository = CardRepository(),
         drawerRepo: DrawerRepository = DrawerRepository(),
         securityService: SecurityService) {
        self.filterDrawerKey = filterDrawerKey
        self.cardRepo = cardRepo
        self.drawerRepo = drawerRepo
        self.securityService = securityService

        // Reload whenever the tutorial step changes so mock data appears/disappears
        // on the real screen without the user needing to navigate away and back.
        VaultedTutorialManager.shared.$step
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.reloadCards() }
            .store(in: &cancellables)

        VaultedTutorialManager.shared.$isActive
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.reloadCards() }
            .store(in: &cancellables)
    }

    func load() {
        drawers = drawerRepo.fetchAllDrawers()
        isPrivateUnlocked = securityService.privateDrawerIsUnlocked
        reloadCards()
    }

    func reloadCards() {
        // During tutorial library steps, inject real CardEntity objects from
        // TutorialMockSeeder so the actual screen looks populated. The seeder
        // uses a throw-away context that is never saved — no CoreData side effects.
        if VaultedTutorialManager.shared.isActive {
            switch VaultedTutorialManager.shared.step {
            case .ideas, .stackView:
                if filterDrawerKey == "ideas" || filterDrawerKey == nil {
                    cards = TutorialMockSeeder.shared.ideasCards
                    return
                }
            case .work:
                if filterDrawerKey == "work" || filterDrawerKey == nil {
                    cards = TutorialMockSeeder.shared.workCards
                    return
                }
            case .journal:
                if filterDrawerKey == "journal" || filterDrawerKey == nil {
                    cards = TutorialMockSeeder.shared.journalCards
                    return
                }
            default:
                break
            }
        }

        if let key = filterDrawerKey,
           let drawer = drawerRepo.fetchDrawer(bySystemKey: key) {
            cards = cardRepo.fetchCards(drawer: drawer, searchQuery: searchQuery)
        } else {
            cards = cardRepo.fetchAllCards(searchQuery: searchQuery)
        }
    }

    // MARK: - Grouped for timeline
    var groupedByTime: [(label: String, cards: [CardEntity])] {
        let cal = Calendar.current
        let now = Date()
        var groups: [(String, [CardEntity])] = []

        let today = cards.filter { cal.isDateInToday($0.createdAt ?? .distantPast) }
        let yesterday = cards.filter { cal.isDateInYesterday($0.createdAt ?? .distantPast) }
        let thisWeek = cards.filter {
            guard let d = $0.createdAt else { return false }
            return !cal.isDateInToday(d) && !cal.isDateInYesterday(d) &&
                   cal.isDate(d, equalTo: now, toGranularity: .weekOfYear)
        }
        let older = cards.filter {
            guard let d = $0.createdAt else { return false }
            return !cal.isDateInToday(d) && !cal.isDateInYesterday(d) &&
                   !cal.isDate(d, equalTo: now, toGranularity: .weekOfYear)
        }

        if !today.isEmpty     { groups.append(("Today", today)) }
        if !yesterday.isEmpty { groups.append(("Yesterday", yesterday)) }
        if !thisWeek.isEmpty  { groups.append(("This Week", thisWeek)) }
        if !older.isEmpty     { groups.append(("Earlier", older)) }
        return groups
    }

    // MARK: - Grouped for drawer cabinet (by weekday)
    var groupedByWeekday: [(label: String, cards: [CardEntity])] {
        let cal = Calendar.current
        let weekdays = ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"]
        var dict: [Int: [CardEntity]] = [:]
        for card in cards {
            let wd = cal.component(.weekday, from: card.createdAt ?? Date())
            dict[wd, default: []].append(card)
        }
        return dict.keys.sorted().map { wd in
            (weekdays[wd - 1], dict[wd]!)
        }
    }

    // MARK: - Grouped for bookshelf (by month)
    var groupedByMonth: [(label: String, cards: [CardEntity])] {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        var dict: [String: [CardEntity]] = [:]
        for card in cards {
            let key = fmt.string(from: card.createdAt ?? Date())
            dict[key, default: []].append(card)
        }
        return dict.keys.sorted(by: >).map { key in (key, dict[key]!) }
    }

    // MARK: - Grouped by week (e.g. "Jan 12–18")
    var groupedByWeek: [(label: String, cards: [CardEntity])] {
        let cal = Calendar.current
        var dict: [Date: [CardEntity]] = [:]
        for card in cards {
            guard let d = card.createdAt else { continue }
            let startOfWeek = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: d)) ?? d
            dict[startOfWeek, default: []].append(card)
        }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return dict.keys.sorted(by: >).map { start in
            let end = cal.date(byAdding: .day, value: 6, to: start) ?? start
            let label = "\(fmt.string(from: start))–\(fmt.string(from: end))"
            return (label, dict[start]!.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) })
        }
    }

    // MARK: - Grouped by day (e.g. "Jan 17")
    var groupedByDay: [(label: String, cards: [CardEntity])] {
        let cal = Calendar.current
        var dict: [Date: [CardEntity]] = [:]
        for card in cards {
            let d = card.createdAt ?? Date()
            let start = cal.startOfDay(for: d)
            dict[start, default: []].append(card)
        }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return dict.keys.sorted(by: >).map { start in
            (fmt.string(from: start), dict[start]!.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) })
        }
    }

    /// Bookshelf spines: one entry per period (week/day/month) for current bookshelfPeriod.
    var groupedForBookshelf: [(label: String, cards: [CardEntity])] {
        switch bookshelfPeriod {
        case .weekly:  return groupedByWeek
        case .daily:   return groupedByDay
        case .monthly: return groupedByMonth
        }
    }

    // MARK: - Unlock private drawer
    func unlockPrivate() async -> Bool {
        let success = await securityService.authenticateAndUnlock()
        isPrivateUnlocked = success
        if success { load() }
        return success
    }

    func toggleStar(_ card: CardEntity) {
        cardRepo.toggleStar(card)
    }

    func deleteCard(_ card: CardEntity) {
        cardRepo.delete(card)
        reloadCards()
    }
}