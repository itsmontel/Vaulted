import CoreData
import Foundation

// MARK: - TagEntity
@objc(TagEntity)
public class TagEntity: NSManagedObject {}

extension TagEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<TagEntity> {
        NSFetchRequest<TagEntity>(entityName: "TagEntity")
    }
    @NSManaged public var name: String?
    @NSManaged public var cards: NSSet?
}

// MARK: - DrawerEntity
@objc(DrawerEntity)
public class DrawerEntity: NSManagedObject {}

extension DrawerEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<DrawerEntity> {
        NSFetchRequest<DrawerEntity>(entityName: "DrawerEntity")
    }

    @NSManaged public var uuid: UUID?
    @NSManaged public var name: String?
    @NSManaged public var systemKey: String?
    @NSManaged public var isLocked: Bool
    @NSManaged public var requiresBiometric: Bool
    @NSManaged public var createdAt: Date?
    @NSManaged public var cards: NSSet?

    var displayName: String { name ?? "Unnamed" }
    var isPrivate: Bool { systemKey == "private" }
}

// MARK: - CardEntity
@objc(CardEntity)
public class CardEntity: NSManagedObject {}

extension CardEntity: Identifiable {
    public var id: NSManagedObjectID { objectID }
}

extension CardEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CardEntity> {
        NSFetchRequest<CardEntity>(entityName: "CardEntity")
    }

    @NSManaged public var uuid: UUID?
    @NSManaged public var type: String?          // "voice" | "text"
    @NSManaged public var title: String?
    @NSManaged public var typedCopy: String?
    @NSManaged public var snippet: String?
    @NSManaged public var bodyText: String?
    @NSManaged public var audioFileName: String?
    @NSManaged public var durationSec: Double
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var reminderDate: Date?
    @NSManaged public var starred: Bool
    @NSManaged public var isLocked: Bool
    @NSManaged public var tags: String?          // legacy comma-separated; kept for search + migration
    @NSManaged public var drawer: DrawerEntity?
    @NSManaged public var tagItems: NSSet?        // TagEntity many-to-many

    var tagList: [String] {
        get {
            if let items = tagItems as? Set<TagEntity>, !items.isEmpty {
                return items.compactMap { $0.name }.filter { !$0.isEmpty }.sorted()
            }
            return (tags ?? "").split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        }
        set {
            tags = newValue.joined(separator: ",")
            // tagItems updated via CardRepository.syncTagItems(from:tags:)
        }
    }

    var isVoice: Bool { type == "voice" }
    var audioURL: URL? {
        guard let fn = audioFileName else { return nil }
        return AudioDirectoryHelper.audioDirectory.appendingPathComponent(fn)
    }
}

// MARK: - Audio directory helper
enum AudioDirectoryHelper {
    static var audioDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Audio", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
}
