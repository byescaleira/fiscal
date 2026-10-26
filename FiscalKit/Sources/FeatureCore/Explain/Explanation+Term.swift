import FiscalDomain
import Foundation

extension Explanation {
    static var attendanceMeaning: String {
        String(
            appLocalized:
                "Attendance counts the sessions with roll call where they were present, not how they voted."
        )
    }

    static var proposalsMeaning: String {
        String(
            appLocalized:
                "A bill is a text sent to the house to be analyzed, and it only becomes law after being approved in the votes."
        )
    }

    static var allowanceMeaning: String {
        String(
            appLocalized:
                "The office allowance reimburses term expenses, such as travel and office rent, and is not salary."
        )
    }

    public static func attendance(_ attendance: Profile.Attendance?, houseAverage: Double? = nil)
        -> Explanation
    {
        guard let attendance, let fraction = attendance.fraction else {
            return Explanation(
                topic: .attendance, facts: [String(appLocalized: "Attendance: not published")],
                sentences: [
                    String(appLocalized: "The house hasn't published attendance for this term.")
                ])
        }
        return Explanation(
            topic: .attendance, facts: attendanceFacts(attendance, houseAverage: houseAverage),
            sentences: [
                attendanceMeaning,
                String(
                    appLocalized:
                        "\(PublicFormat.percent(fraction)) means \(PublicFormat.number(attendance.present)) of \(PublicFormat.number(attendance.eligible)) sessions."
                ),
                houseAverage.map {
                    String(appLocalized: "The house average is \(PublicFormat.percent($0)).")
                } ?? "",
            ])
    }

    public static func proposals(_ count: Int?, laws: Int?) -> Explanation {
        guard let count else { return Explanation(topic: .proposals, facts: [], fixed: "") }
        let total = PublicFormat.number(count)
        let detail: String
        if count == 0 {
            detail = String(
                appLocalized: "No bill was presented in the period the house publishes.")
        } else if let laws {
            detail = String(
                appLocalized:
                    "Of the \(total) bills presented, \(PublicFormat.number(laws)) became law.")
        } else {
            detail = String(appLocalized: "Presented \(total) bills in this term.")
        }
        return Explanation(
            topic: .proposals, facts: proposalFacts(count, laws: laws),
            sentences: [proposalsMeaning, detail])
    }

    public static func speeches(_ count: Int?) -> Explanation {
        guard let count else { return Explanation(topic: .speeches, facts: [], fixed: "") }
        return Explanation(
            topic: .speeches, facts: speechFacts(count),
            sentences: [
                String(
                    appLocalized:
                        "Speeches count how many times they spoke on record at the house, not what they said."
                ),
                String(appLocalized: "Gave \(PublicFormat.number(count)) speeches on record."),
            ])
    }

    public static func allowance(cents: Int?) -> Explanation {
        guard let cents else {
            return Explanation(
                topic: .allowance, facts: [String(appLocalized: "Office allowance: not published")],
                sentences: [
                    String(
                        appLocalized:
                            "The house doesn't publish the office allowance spending for this term."
                    )
                ])
        }
        return Explanation(
            topic: .allowance, facts: allowanceFacts(cents),
            sentences: [
                allowanceMeaning,
                String(appLocalized: "Each expense needs a receipt, and the house publishes it."),
            ])
    }

    public static func term(_ numbers: Profile.Numbers, houseAverage: Double? = nil)
        -> Explanation
    {
        var facts: [String] = []
        var sentences: [String] = []
        if let attendance = numbers.attendance, attendance.eligible > 0 {
            facts += attendanceFacts(attendance, houseAverage: houseAverage)
            sentences.append(attendanceMeaning)
        }
        if let proposals = numbers.proposals {
            facts += proposalFacts(proposals, laws: numbers.laws)
        }
        if let speeches = numbers.speeches {
            facts += speechFacts(speeches)
        }
        switch (numbers.proposals, numbers.speeches) {
        case (.some, .some):
            sentences.append(
                String(
                    appLocalized:
                        "Bills are texts sent to the house to be analyzed, and speeches count the times they spoke on record, not what they said."
                ))
        case (.some, nil):
            sentences.append(proposalsMeaning)
        case (nil, .some):
            sentences.append(
                String(
                    appLocalized:
                        "Speeches count how many times they spoke on record at the house, not what they said."
                ))
        case (nil, nil):
            break
        }
        if let votes = numbers.votes {
            facts.append(
                String(
                    appLocalized: "Roll-call votes taken part in: \(PublicFormat.number(votes))"))
        }
        if let cents = numbers.quotaCents {
            facts += allowanceFacts(cents)
            sentences.append(allowanceMeaning)
        }
        return Explanation(topic: .termNumbers, facts: facts, sentences: sentences)
    }

    private static func attendanceFacts(
        _ attendance: Profile.Attendance, houseAverage: Double?
    ) -> [String] {
        let present = PublicFormat.number(attendance.present)
        let eligible = PublicFormat.number(attendance.eligible)
        let percent = PublicFormat.percent(attendance.fraction)
        return [
            String(
                appLocalized:
                    "Attendance: \(present) of \(eligible) sessions with roll call (\(percent))"),
            houseAverage.map {
                String(appLocalized: "House average attendance: \(PublicFormat.percent($0))")
            } ?? "",
        ]
    }

    private static func proposalFacts(_ count: Int, laws: Int?) -> [String] {
        [
            String(appLocalized: "Bills presented: \(PublicFormat.number(count))"),
            laws.map { String(appLocalized: "Bills that became law: \(PublicFormat.number($0))") }
                ?? "",
        ]
    }

    private static func speechFacts(_ count: Int) -> [String] {
        [String(appLocalized: "Speeches on record: \(PublicFormat.number(count))")]
    }

    private static func allowanceFacts(_ cents: Int) -> [String] {
        [String(appLocalized: "Office allowance used: \(PublicFormat.compactMoney(cents: cents))")]
    }
}
