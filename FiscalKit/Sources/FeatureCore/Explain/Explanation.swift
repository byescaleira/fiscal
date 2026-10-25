import FiscalDomain
import Foundation

public struct Explanation: Hashable, Identifiable, Sendable {
    public enum Topic: String, Sendable {
        case attendance, proposals, speeches, allowance, termNumbers, vote, count, price,
            topicBars, topicCadence

        var promptName: String {
            switch self {
            case .attendance: "attendance at sessions"
            case .proposals: "bills presented"
            case .speeches: "speeches on record"
            case .allowance: "office allowance spending"
            case .termNumbers: "a legislator's term in numbers"
            case .vote: "the result of a vote in Congress"
            case .count: "the live election count"
            case .price: "a price change"
            case .topicBars: "a bar chart of recent votes by topic"
            case .topicCadence: "a bar chart of votes over time"
            }
        }
    }

    public static let sentenceLimit = 3

    public let topic: Topic
    public let facts: [String]
    public let fixed: String

    public init(topic: Topic, facts: [String], fixed: String) {
        self.topic = topic
        self.facts = facts.filter { !$0.isEmpty }
        self.fixed = fixed
    }

    public init(topic: Topic, facts: [String], sentences: [String]) {
        self.init(
            topic: topic, facts: facts,
            fixed: sentences.filter { !$0.isEmpty }.prefix(Self.sentenceLimit).joined(
                separator: " "))
    }

    public var id: String { ([topic.rawValue] + facts).joined(separator: "\n") }

    public var isEmpty: Bool { fixed.isEmpty }
}
