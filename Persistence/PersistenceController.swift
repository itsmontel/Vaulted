import CoreData

// MARK: - Persistence Controller
final class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    // MARK: - Init
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Vaulted")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Core Data failed to load: \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        seedDefaultDrawersIfNeeded()
        migrateTagsToTagEntitiesIfNeeded()
    }

    // MARK: - One-time migration: populate tagItems from tags string
    private func migrateTagsToTagEntitiesIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: "Vaulted.didMigrateTagItems") else { return }
        let ctx = container.viewContext
        let req: NSFetchRequest<CardEntity> = CardEntity.fetchRequest()
        guard let cards = try? ctx.fetch(req) else { return }
        let cardRepo = CardRepository(pc: self)
        for card in cards {
            let tagStr = card.tags ?? ""
            if tagStr.isEmpty { continue }
            let count = (card.tagItems as? Set<TagEntity>)?.count ?? 0
            if count > 0 { continue }
            let names = tagStr.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            if names.isEmpty { continue }
            cardRepo.syncTagItems(for: card, tagNames: names)
        }
        UserDefaults.standard.set(true, forKey: "Vaulted.didMigrateTagItems")
    }

    var viewContext: NSManagedObjectContext { container.viewContext }

    // MARK: - Background context
    func newBackgroundContext() -> NSManagedObjectContext {
        container.newBackgroundContext()
    }

    func save(_ context: NSManagedObjectContext? = nil) {
        let ctx = context ?? container.viewContext
        guard ctx.hasChanges else { return }
        do { try ctx.save() }
        catch { print("Core Data save error: \(error)") }
    }

    // MARK: - Preview
    static var preview: PersistenceController = {
        let pc = PersistenceController(inMemory: true)
        let ctx = pc.viewContext
        // seed sample cards
        let inbox = pc.fetchOrCreateDrawer(systemKey: "inbox", name: "Inbox",
                                           isLocked: false, requiresBiometric: false, ctx: ctx)
        let c1 = CardEntity(context: ctx)
        c1.uuid = UUID(); c1.type = "voice"; c1.title = "Morning thoughts"
        c1.snippet = "Voice note"; c1.durationSec = 42; c1.createdAt = Date()
        c1.updatedAt = Date(); c1.starred = false; c1.isLocked = false
        c1.tags = "morning,ideas"; c1.drawer = inbox

        let c2 = CardEntity(context: ctx)
        c2.uuid = UUID(); c2.type = "text"; c2.title = "App redesign notes"
        c2.snippet = "The new onboarding flow should feel..."
        c2.bodyText = "The new onboarding flow should feel warm and analog."
        c2.createdAt = Date().addingTimeInterval(-3600); c2.updatedAt = Date()
        c2.starred = true; c2.isLocked = false; c2.tags = "work,design"; c2.drawer = inbox
        pc.save(ctx)
        return pc
    }()

    // MARK: - Default Drawer Seeding
    private func seedDefaultDrawersIfNeeded() {
        let ctx = container.viewContext
        let request: NSFetchRequest<DrawerEntity> = DrawerEntity.fetchRequest()
        request.fetchLimit = 1
        let count = (try? ctx.count(for: request)) ?? 0
        guard count == 0 else { return }

        let defaults: [(name: String, key: String, locked: Bool, bio: Bool)] = [
            ("Inbox",   "inbox",   false, false),
            ("Ideas",   "ideas",   false, false),
            ("Work",    "work",    false, false),
            ("Journal", "journal", false, false),
            ("Private", "private", true,  true),
        ]
        for d in defaults {
            _ = fetchOrCreateDrawer(systemKey: d.key, name: d.name,
                                    isLocked: d.locked, requiresBiometric: d.bio, ctx: ctx)
        }
        save(ctx)
    }

    @discardableResult
    func fetchOrCreateDrawer(systemKey: String, name: String,
                             isLocked: Bool, requiresBiometric: Bool,
                             ctx: NSManagedObjectContext) -> DrawerEntity {
        let req: NSFetchRequest<DrawerEntity> = DrawerEntity.fetchRequest()
        req.predicate = NSPredicate(format: "systemKey == %@", systemKey)
        if let existing = try? ctx.fetch(req).first { return existing }

        let drawer = DrawerEntity(context: ctx)
        drawer.uuid = UUID()
        drawer.name = name
        drawer.systemKey = systemKey
        drawer.isLocked = isLocked
        drawer.requiresBiometric = requiresBiometric
        drawer.createdAt = Date()
        return drawer
    }
}
