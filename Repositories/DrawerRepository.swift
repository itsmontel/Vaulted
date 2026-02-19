import CoreData
import Foundation

// MARK: - DrawerRepository
final class DrawerRepository {
    private let pc: PersistenceController

    init(pc: PersistenceController = .shared) {
        self.pc = pc
    }

    var context: NSManagedObjectContext { pc.viewContext }

    // MARK: - Fetch all drawers sorted by creation
    func fetchAllDrawers() -> [DrawerEntity] {
        let req: NSFetchRequest<DrawerEntity> = DrawerEntity.fetchRequest()
        req.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        return (try? context.fetch(req)) ?? []
    }

    func fetchDrawer(bySystemKey key: String) -> DrawerEntity? {
        let req: NSFetchRequest<DrawerEntity> = DrawerEntity.fetchRequest()
        req.predicate = NSPredicate(format: "systemKey == %@", key)
        req.fetchLimit = 1
        return try? context.fetch(req).first
    }

    @discardableResult
    func createCustomDrawer(name: String,
                            isLocked: Bool = false,
                            requiresBiometric: Bool = false) -> DrawerEntity {
        let drawer = DrawerEntity(context: context)
        drawer.uuid = UUID()
        drawer.name = name
        drawer.isLocked = isLocked
        drawer.requiresBiometric = requiresBiometric
        drawer.createdAt = Date()
        pc.save()
        return drawer
    }

    func update(drawer: DrawerEntity, name: String? = nil,
                isLocked: Bool? = nil, requiresBiometric: Bool? = nil) {
        if let n = name { drawer.name = n }
        if let l = isLocked { drawer.isLocked = l }
        if let b = requiresBiometric { drawer.requiresBiometric = b }
        pc.save()
    }
}
