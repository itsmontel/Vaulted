import CoreData
import Foundation

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
    @NSManaged public var starred: Bool
    @NSManaged public var isLocked: Bool
    @NSManaged public var tags: String?          // comma-separated
    @NSManaged public var drawer: DrawerEntity?

    var tagList: [String] {
        get { (tags ?? "").split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
        set { tags = newValue.joined(separator: ",") }
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
