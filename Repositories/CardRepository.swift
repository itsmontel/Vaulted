import CoreData
import Foundation

// MARK: - CardRepository
final class CardRepository {
    private let pc: PersistenceController

    init(pc: PersistenceController = .shared) {
        self.pc = pc
    }

    var context: NSManagedObjectContext { pc.viewContext }

    // MARK: - Create voice card
    @discardableResult
    func createVoiceCard(drawer: DrawerEntity,
                         audioFileName: String,
                         duration: Double,
                         title: String = "New card",
                         snippet: String = "Voice note",
                         tags: String = "") -> CardEntity {
        let card = CardEntity(context: context)
        card.uuid = UUID()
        card.type = "voice"
        card.title = title
        card.snippet = snippet
        card.audioFileName = audioFileName
        card.durationSec = duration
        card.createdAt = Date()
        card.updatedAt = Date()
        card.starred = false
        card.isLocked = false
        card.tags = tags
        card.drawer = drawer
        pc.save()
        syncTagItems(for: card, tagNames: (tags.isEmpty ? [] : (tags.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })))
        return card
    }

    // MARK: - Create text card
    @discardableResult
    func createTextCard(drawer: DrawerEntity,
                        bodyText: String,
                        title: String = "New card",
                        tags: String = "") -> CardEntity {
        let snippet = String(bodyText.prefix(80))
        let card = CardEntity(context: context)
        card.uuid = UUID()
        card.type = "text"
        card.title = title
        card.snippet = snippet.isEmpty ? "Text note" : snippet
        card.bodyText = bodyText
        card.durationSec = 0
        card.createdAt = Date()
        card.updatedAt = Date()
        card.starred = false
        card.isLocked = false
        card.tags = tags
        card.drawer = drawer
        pc.save()
        syncTagItems(for: card, tagNames: (tags.isEmpty ? [] : (tags.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })))
        return card
    }

    // MARK: - Fetch card by UUID
    func fetchCard(byUUID uuid: UUID) -> CardEntity? {
        let req: NSFetchRequest<CardEntity> = CardEntity.fetchRequest()
        req.predicate = NSPredicate(format: "uuid == %@", uuid as CVarArg)
        req.fetchLimit = 1
        return (try? context.fetch(req))?.first
    }

    // MARK: - Fetch cards for a drawer
    func fetchCards(drawer: DrawerEntity,
                    searchQuery: String = "",
                    onlyStarred: Bool = false) -> [CardEntity] {
        let req: NSFetchRequest<CardEntity> = CardEntity.fetchRequest()
        var predicates: [NSPredicate] = [NSPredicate(format: "drawer == %@", drawer)]
        if onlyStarred { predicates.append(NSPredicate(format: "starred == YES")) }
        if !searchQuery.isEmpty {
            predicates.append(NSPredicate(format: "title CONTAINS[cd] %@ OR snippet CONTAINS[cd] %@ OR typedCopy CONTAINS[cd] %@ OR tags CONTAINS[cd] %@",
                                          searchQuery, searchQuery, searchQuery, searchQuery))
        }
        req.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        req.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        return (try? context.fetch(req)) ?? []
    }

    // MARK: - Fetch all cards (across drawers)
    func fetchAllCards(searchQuery: String = "") -> [CardEntity] {
        let req: NSFetchRequest<CardEntity> = CardEntity.fetchRequest()
        if !searchQuery.isEmpty {
            req.predicate = NSPredicate(format: "title CONTAINS[cd] %@ OR snippet CONTAINS[cd] %@ OR typedCopy CONTAINS[cd] %@ OR tags CONTAINS[cd] %@",
                                        searchQuery, searchQuery, searchQuery, searchQuery)
        }
        req.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        return (try? context.fetch(req)) ?? []
    }

    // MARK: - Move card
    func moveCard(_ card: CardEntity, toDrawer drawer: DrawerEntity) {
        card.drawer = drawer
        card.updatedAt = Date()
        pc.save()
    }

    // MARK: - Toggle star
    func toggleStar(_ card: CardEntity) {
        card.starred.toggle()
        card.updatedAt = Date()
        pc.save()
    }

    // MARK: - Update title/body/tags/snippet/typedCopy
    func update(card: CardEntity,
                title: String? = nil,
                bodyText: String? = nil,
                tags: String? = nil,
                snippet: String? = nil,
                typedCopy: String? = nil) {
        if let t = title { card.title = t }
        if let b = bodyText {
            card.bodyText = b
            card.snippet = String(b.prefix(80))
        }
        if let s = snippet { card.snippet = String(s.prefix(200)) }
        if let tc = typedCopy { card.typedCopy = tc }
        if let tg = tags {
            card.tags = tg
            let names = tg.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            syncTagItems(for: card, tagNames: names)
        }
        card.updatedAt = Date()
        pc.save()
    }

    // MARK: - Tag entity sync (many-to-many)
    private func fetchOrCreateTag(name: String) -> TagEntity {
        let req: NSFetchRequest<TagEntity> = TagEntity.fetchRequest()
        req.predicate = NSPredicate(format: "name ==[cd] %@", name)
        req.fetchLimit = 1
        if let existing = try? context.fetch(req).first { return existing }
        let tag = TagEntity(context: context)
        tag.name = name
        return tag
    }

    func syncTagItems(for card: CardEntity, tagNames: [String]) {
        let tagEntities = tagNames.map { fetchOrCreateTag(name: $0) }
        card.tagItems = NSSet(array: tagEntities)
        pc.save()
    }

    // MARK: - Reminder
    func setReminder(_ card: CardEntity, date: Date?) {
        let cardId = card.uuid?.uuidString ?? card.objectID.uriRepresentation().absoluteString
        ReminderService.shared.cancelReminder(cardId: cardId)

        card.reminderDate = date
        card.updatedAt = Date()
        pc.save()

        if let d = date {
            Task {
                await ReminderService.shared.scheduleReminder(
                    cardId: cardId,
                    title: card.title ?? "Note",
                    date: d
                )
            }
        }
    }

    func clearReminder(_ card: CardEntity) {
        setReminder(card, date: nil)
    }

    // MARK: - Lock / unlock card
    func setLocked(_ card: CardEntity, locked: Bool) {
        card.isLocked = locked
        card.updatedAt = Date()
        pc.save()
    }

    // MARK: - Delete card (removes audio file too, cancels reminder)
    func delete(_ card: CardEntity) {
        let cardId = card.uuid?.uuidString ?? card.objectID.uriRepresentation().absoluteString
        ReminderService.shared.cancelReminder(cardId: cardId)
        if let url = card.audioURL {
            try? FileManager.default.removeItem(at: url)
        }
        context.delete(card)
        pc.save()
    }

    // MARK: - Count helpers
    func cardCount(drawer: DrawerEntity) -> Int {
        let req: NSFetchRequest<CardEntity> = CardEntity.fetchRequest()
        req.predicate = NSPredicate(format: "drawer == %@", drawer)
        return (try? context.count(for: req)) ?? 0
    }

    func todayCardCount() -> Int {
        let req: NSFetchRequest<CardEntity> = CardEntity.fetchRequest()
        let start = Calendar.current.startOfDay(for: Date())
        req.predicate = NSPredicate(format: "createdAt >= %@", start as NSDate)
        return (try? context.count(for: req)) ?? 0
    }
}
