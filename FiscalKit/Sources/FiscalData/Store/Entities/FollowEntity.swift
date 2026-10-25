import FiscalDomain
import Foundation
import SwiftData

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

    public init(card: PersonCard, followedAt: Date) {
        slug = card.slug
        self.followedAt = followedAt
        update(with: card)
    }

    func update(with card: PersonCard) {
        name = card.name
        office = card.office.rawValue
        uf = card.uf
        party = card.party
        photo = card.photo?.absoluteString
        status = card.status.rawValue
    }

    var followed: FollowedPerson? {
        guard let office = Office(rawValue: office) else { return nil }
        let card = PersonCard(
            slug: slug, name: name, office: office, uf: uf, party: party,
            photo: photo.flatMap(URL.init(string:)),
            status: PersonStatus(rawValue: status) ?? .inOffice)
        return FollowedPerson(card: card, followedAt: followedAt)
    }
}
