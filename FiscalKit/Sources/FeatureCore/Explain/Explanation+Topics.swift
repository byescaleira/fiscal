import FiscalDomain
import Foundation

extension Explanation {
    public struct TopicCount: Hashable, Sendable {
        public let title: String
        public let count: Int
        public let approved: Int

        public init(title: String, count: Int, approved: Int) {
            self.title = title
            self.count = count
            self.approved = approved
        }
    }

    public static func topicBars(_ topics: [TopicCount], total: Int) -> Explanation {
        var facts = [
            String(appLocalized: "Latest votes in the update: \(PublicFormat.number(total))")
        ]
        facts += topics.map { topic in
            String(
                appLocalized:
                    "\(topic.title): \(PublicFormat.number(topic.count)) votes, \(PublicFormat.number(topic.approved)) approved"
            )
        }
        var sentences = [
            String(
                appLocalized:
                    "Each bar counts the latest votes that touched a topic, and one vote can count in more than one topic."
            ),
            String(appLocalized: "Votes that touch none of these topics are left out."),
        ]
        if topics.contains(where: { $0.approved > 0 && $0.approved < $0.count }) {
            sentences.append(
                String(appLocalized: "“Approved” counts how many of those votes ended approved."))
        }
        return Explanation(topic: .topicBars, facts: facts, sentences: sentences)
    }

    public static func topicCadence(
        weekly: Bool, average: Double?, busiest: String?, busiestCount: Int?
    ) -> Explanation {
        var facts = [
            weekly
                ? String(appLocalized: "Each bar: one week")
                : String(appLocalized: "Each bar: one day")
        ]
        var sentences =
            weekly
            ? [
                String(
                    appLocalized:
                        "Each bar is a week, and its height is the number of votes on these topics."
                ),
                String(appLocalized: "A week without a bar had no votes on these topics."),
            ]
            : [
                String(
                    appLocalized:
                        "Each bar is a day, and its height is the number of votes on these topics."),
                String(appLocalized: "A day without a bar had no votes on these topics."),
            ]
        if let average {
            let value = average.formatted(.number.precision(.fractionLength(0...1)).locale(.app))
            facts.append(String(appLocalized: "Average per bar: \(value)"))
        }
        if let busiest, let busiestCount, busiestCount > 0 {
            let count = PublicFormat.number(busiestCount)
            facts.append(String(appLocalized: "Bar with the most votes: \(busiest), \(count)"))
            sentences.append(
                String(appLocalized: "The bar with the most votes is \(busiest), with \(count)."))
        }
        return Explanation(topic: .topicCadence, facts: facts, sentences: sentences)
    }
}
