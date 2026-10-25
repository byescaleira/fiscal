import AppIntents
import FeatureCore
import FiscalDomain
import Foundation

public struct PersonEntity: AppEntity {
    public static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Politician")
    }

    public static var defaultQuery: PersonQuery { PersonQuery() }

    public let id: String
    public let name: String
    public let detail: String

    public init(id: String, name: String, detail: String) {
        self.id = id
        self.name = name
        self.detail = detail
    }

    init(_ card: PersonCard) {
        let person = SpotlightPerson(card)
        self.init(id: person.id, name: person.title, detail: person.detail)
    }

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)", subtitle: "\(detail)",
            image: DisplayRepresentation.Image(
                systemName: "person.crop.circle"))
    }
}

public struct PersonQuery: EntityStringQuery {
    public init() {}

    @MainActor
    public func entities(for identifiers: [PersonEntity.ID]) async throws -> [PersonEntity] {
        try await IntentWorkspace.actions().people(slugs: identifiers).map(PersonEntity.init)
    }

    @MainActor
    public func entities(matching string: String) async throws -> [PersonEntity] {
        try await IntentWorkspace.actions().people(matching: string).map(PersonEntity.init)
    }

    @MainActor
    public func suggestedEntities() async throws -> [PersonEntity] {
        let slugs = RecentPeople().slugs
        guard !slugs.isEmpty else { return [] }
        return try await IntentWorkspace.actions().people(slugs: slugs).map(PersonEntity.init)
    }
}

enum IntentWorkspace {
    @MainActor
    static func actions() throws -> IntegrationActions {
        guard let service = FiscalServices.shared.publicData() else {
            throw IntegrationError.unavailable
        }
        return IntegrationActions(service: service)
    }
}

enum IntegrationError: Error, CustomLocalizedStringResourceConvertible {
    case unavailable
    case noState

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .unavailable: "Fiscal couldn't reach the public data now. Try again in a moment."
        case .noState: "Pick your state in Fiscal, in the Mine tab."
        }
    }
}
