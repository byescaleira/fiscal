import FiscalDomain
import Foundation
import SwiftData

@Model
public class ItemEntity {
    #Index<ItemEntity>([\.id])
    public var id: String = ""
    public var title: String = ""
    public var createdAt: Date = Date.distantPast

    public init(id: String, title: String, createdAt: Date) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
    }

    var item: Item {
        Item(id: id, title: title, createdAt: createdAt)
    }
}
