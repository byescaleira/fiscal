import FeatureCore
import Foundation

#if canImport(CoreSpotlight)
    import CoreSpotlight
    import UniformTypeIdentifiers
#endif

protocol PeopleIndexing: Sendable {
    func replace(with people: [SpotlightPerson]) async
}

struct SpotlightPeopleIndex: PeopleIndexing {
    func replace(with people: [SpotlightPerson]) async {
        #if canImport(CoreSpotlight)
            let index = CSSearchableIndex.default()
            try? await index.deleteSearchableItems(withDomainIdentifiers: [SpotlightPerson.domain])
            guard !people.isEmpty else { return }
            try? await index.indexSearchableItems(people.map(Self.item))
        #endif
    }

    #if canImport(CoreSpotlight)
        static func item(_ person: SpotlightPerson) -> CSSearchableItem {
            let attributes = CSSearchableItemAttributeSet(contentType: .content)
            attributes.title = person.title
            attributes.displayName = person.title
            attributes.contentDescription = person.detail
            attributes.keywords = person.keywords
            let item = CSSearchableItem(
                uniqueIdentifier: person.id, domainIdentifier: SpotlightPerson.domain,
                attributeSet: attributes)
            item.expirationDate = .distantFuture
            return item
        }
    #endif

    static func url(from activity: NSUserActivity) -> URL? {
        #if canImport(CoreSpotlight)
            guard activity.activityType == CSSearchableItemActionType,
                let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String
            else { return nil }
            return SpotlightPerson.url(forIdentifier: identifier)
        #else
            return nil
        #endif
    }
}
