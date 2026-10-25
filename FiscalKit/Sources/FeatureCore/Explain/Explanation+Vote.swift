import FiscalDomain
import Foundation

extension Explanation {
    public static func vote(_ vote: VoteSummary, requiredYes: Int? = nil) -> Explanation {
        let yes = PublicFormat.number(vote.yes)
        let no = PublicFormat.number(vote.no)
        let others = PublicFormat.number(vote.others)
        var facts = [
            String(appLocalized: "House: \(vote.house.title)"),
            String(appLocalized: "Proposition: \(vote.proposition)"),
            vote.kind.map { String(appLocalized: "Kind: \($0)") } ?? "",
            String(appLocalized: "Official summary: \(vote.summary)"),
            vote.plainSummary.map { String(appLocalized: "Plain summary: \($0)") } ?? "",
        ]
        if vote.nominal, vote.yes != nil {
            facts += [
                String(appLocalized: "Yes votes: \(yes)"), String(appLocalized: "No votes: \(no)"),
                String(appLocalized: "Other votes, such as abstention and obstruction: \(others)"),
            ]
        }
        if let requiredYes {
            facts.append(
                String(
                    appLocalized:
                        "Yes votes a constitutional amendment needs: \(PublicFormat.number(requiredYes))"
                ))
        }
        let sentences: [String]
        switch vote.approved {
        case true?:
            facts.append(String(appLocalized: "Result: approved"))
            sentences = [
                scoreboardMeaning(vote),
                String(
                    appLocalized: "Approved means the text got the votes it needed in this vote."),
                requiredYes == nil
                    ? String(
                        appLocalized:
                            "Being approved here doesn't mean it is law yet: the text may still go through other votes or be signed into law."
                    ) : amendmentRule,
            ]
        case false?:
            facts.append(String(appLocalized: "Result: rejected"))
            sentences = [
                scoreboardMeaning(vote),
                String(
                    appLocalized:
                        "Rejected means the text didn't get the votes it needed in this vote."),
                requiredYes != nil
                    ? amendmentRule
                    : (vote.others ?? 0) > 0
                        ? String(
                            appLocalized:
                                "Other votes are people present who chose neither yes nor no, such as abstention."
                        ) : "",
            ]
        case nil where vote.nominal:
            facts.append(String(appLocalized: "Result: not published yet"))
            sentences = [
                scoreboardMeaning(vote),
                String(appLocalized: "The house hasn't published the result of this vote yet."),
            ]
        case nil:
            facts.append(String(appLocalized: "Result: voice vote, without names"))
            sentences = [
                String(
                    appLocalized:
                        "It was a voice vote: the result was announced without recording each person's vote."
                ),
                String(appLocalized: "That's why this vote has no list of names."),
            ]
        }
        return Explanation(topic: .vote, facts: facts, sentences: sentences)
    }

    static var amendmentRule: String {
        String(
            appLocalized:
                "A constitutional amendment needs three fifths of the seats voting yes, not just more yes than no."
        )
    }

    static func scoreboardMeaning(_ vote: VoteSummary) -> String {
        switch vote.house {
        case .camara:
            String(
                appLocalized:
                    "The scoreboard shows how deputies voted on \(vote.proposition): yes is for the text and no is against it."
            )
        case .senado:
            String(
                appLocalized:
                    "The scoreboard shows how senators voted on \(vote.proposition): yes is for the text and no is against it."
            )
        }
    }

    public static func count(
        office: String, place: String?, counted: Double, leader: String?, leaderShare: Double?,
        needsMajority: Bool
    ) -> Explanation {
        let progress = PublicFormat.percent(counted)
        var facts = [
            String(appLocalized: "Office: \(office)"),
            place.map { String(appLocalized: "Place: \($0)") } ?? "",
            String(appLocalized: "Ballot boxes counted: \(progress)"),
        ]
        var sentences: [String] = []
        let isFinal = counted >= 1
        if let leader, let leaderShare {
            let share = PublicFormat.percent(leaderShare)
            facts.append(String(appLocalized: "First place: \(leader), \(share) of valid votes"))
            sentences.append(
                isFinal
                    ? String(
                        appLocalized:
                            "With all ballot boxes counted, \(leader) finished first with \(share) of valid votes."
                    )
                    : String(
                        appLocalized:
                            "With \(progress) of ballot boxes counted, \(leader) is first with \(share) of valid votes."
                    ))
        } else {
            sentences.append(String(appLocalized: "\(progress) of ballot boxes have been counted."))
        }
        sentences.append(
            String(appLocalized: "Valid votes don't include blank and spoiled ballots."))
        if needsMajority {
            sentences.append(
                String(
                    appLocalized:
                        "To win in the first round, a candidate needs more than half of the valid votes."
                ))
        } else if !isFinal {
            sentences.append(
                String(
                    appLocalized: "The order can still change until every ballot box is counted."))
        }
        return Explanation(topic: .count, facts: facts, sentences: sentences)
    }

    public static func price(
        item: String, before: String, after: String, change: Double?, period: String? = nil
    ) -> Explanation {
        var facts = [
            String(appLocalized: "Item: \(item)"), String(appLocalized: "Before: \(before)"),
            String(appLocalized: "After: \(after)"),
            period.map { String(appLocalized: "Period: \($0)") } ?? "",
        ]
        let first: String
        if let change, change != 0 {
            let amount = PublicFormat.percent(abs(change))
            let signed = (change > 0 ? "+" : "−") + amount
            facts.append(String(appLocalized: "Change: \(signed)"))
            first =
                change > 0
                ? String(
                    appLocalized:
                        "The price of \(item) went from \(before) to \(after), up \(amount)."
                )
                : String(
                    appLocalized:
                        "The price of \(item) went from \(before) to \(after), down \(amount).")
        } else {
            first = String(appLocalized: "The price of \(item) stayed at \(after).")
        }
        return Explanation(
            topic: .price, facts: facts,
            sentences: [
                first,
                String(
                    appLocalized:
                        "The change shows how much the price moved in the period, not why."),
            ])
    }
}
