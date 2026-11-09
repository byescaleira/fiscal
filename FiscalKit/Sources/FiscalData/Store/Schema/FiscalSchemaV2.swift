import Foundation
import SwiftData

public enum FiscalSchemaV2: VersionedSchema {
    public static var versionIdentifier: Schema.Version { .init(2, 0, 0) }
    public static var models: [any PersistentModel.Type] {
        cloudModels + deviceModels
    }
    public static var cloudModels: [any PersistentModel.Type] {
        [FollowEntity.self]
    }
    public static var deviceModels: [any PersistentModel.Type] {
        [LensEntity.self]
    }

    @Model
    public class FollowEntity {
        #Index<FollowEntity>([\.slug])
        public var slug: String = ""
        public var name: String = ""
        public var office: String = ""
        public var uf: String = ""
        public var party: String = ""
        public var photo: String?
        public var status: String = ""
        public var followedAt: Date = Date.distantPast

        public init(slug: String, followedAt: Date) {
            self.slug = slug
            self.followedAt = followedAt
        }
    }

    @Model
    public class LensEntity {
        public var id: String = "lens"
        public var themeKeys: String = ""
        public var supportedKeys: String = ""
        public var prefersNotToSay: Bool = false
        public var artCollection: String?
        public var palette: String?
        public var icon: String?
        public var updatedAt: Date = Date.distantPast

        public init(updatedAt: Date) {
            self.updatedAt = updatedAt
        }
    }
}
