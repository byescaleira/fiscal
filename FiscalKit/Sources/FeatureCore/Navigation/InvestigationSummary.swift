import FiscalDomain
import Foundation

public struct InvestigationSummary: Codable, Hashable, Identifiable, Sendable {
    public struct KeyNumber: Codable, Hashable, Identifiable, Sendable {
        public let value: String
        public let label: String

        public init(value: String, label: String) {
            self.value = value
            self.label = label
        }

        public var id: String { "\(label)-\(value)" }
    }

    public struct Face: Codable, Hashable, Identifiable, Sendable {
        public let slug: String
        public let name: String
        public let party: String

        public init(slug: String, name: String, party: String) {
            self.slug = slug
            self.name = name
            self.party = party
        }

        public var id: String { slug }
    }

    public let id: String
    public let question: String
    public let conclusion: String
    public let numbers: [KeyNumber]
    public let faces: [Face]
    public let compared: String?
    public let uncertainty: String?
    public let sources: [String]
    public let updatedAt: Date?

    public init(
        id: String, question: String, conclusion: String, numbers: [KeyNumber], faces: [Face],
        compared: String?, uncertainty: String?, sources: [String], updatedAt: Date?
    ) {
        self.id = id
        self.question = question
        self.conclusion = conclusion
        self.numbers = numbers
        self.faces = faces
        self.compared = compared
        self.uncertainty = uncertainty
        self.sources = sources
        self.updatedAt = updatedAt
    }
}
