import Foundation

public struct SupportChoice: Codable, Hashable, Sendable {
    public static let peopleLimit = 5
    public static let causeLimit = 5

    public private(set) var people: [String]
    public private(set) var causes: [Theme]

    public init(people: [String] = [], causes: [Theme] = []) {
        self.people = Array(Self.unique(people).prefix(Self.peopleLimit))
        self.causes = Array(Self.unique(causes).prefix(Self.causeLimit))
    }

    public var isEmpty: Bool { people.isEmpty && causes.isEmpty }

    public var canAddPerson: Bool { people.count < Self.peopleLimit }

    public var canAddCause: Bool { causes.count < Self.causeLimit }

    public func supports(_ slug: String?) -> Bool {
        slug.map(people.contains) ?? false
    }

    public func contains(_ cause: Theme) -> Bool { causes.contains(cause) }

    public func rank(of slug: String?) -> Int {
        slug.flatMap { people.firstIndex(of: $0) } ?? people.count
    }

    public mutating func togglePerson(_ slug: String) {
        if let index = people.firstIndex(of: slug) {
            people.remove(at: index)
        } else if canAddPerson {
            people.append(slug)
        }
    }

    public mutating func toggleCause(_ cause: Theme) {
        if let index = causes.firstIndex(of: cause) {
            causes.remove(at: index)
        } else if canAddCause {
            causes.append(cause)
        }
    }

    private static func unique<Value: Equatable>(_ values: [Value]) -> [Value] {
        var seen: [Value] = []
        for value in values where !seen.contains(value) { seen.append(value) }
        return seen
    }
}
