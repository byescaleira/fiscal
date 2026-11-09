import FiscalDomain
import Foundation

public enum ShareCaption {
    public static let limit = 280

    public static func make(_ content: ShareCardContent, selection: ShareSelection = .init())
        -> String
    {
        let shown = content.applying(selection)
        let link = shown.link.absoluteString
        let tail = [clipped(dated(shown), to: limit - link.count - 1), link]
        let room = limit - tail.reduce(0) { $0 + $1.count } - tail.count
        return ([clipped(fact(shown), to: room)] + tail).filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    static func fact(_ content: ShareCardContent) -> String {
        switch content.body {
        case .person(let metrics):
            let lead = metrics.first { $0.value != PublicFormat.missing } ?? metrics.first
            return joined(person(content), lead.map { "\($0.label): \($0.value)" })
        case .vote(let tally):
            let score = String(appLocalized: "Yes \(tally.yes), No \(tally.no)")
            return joined(
                content.headline ?? tally.proposition,
                [score, tally.result].compactMap(\.self).joined(separator: " · "))
        case .expenses(let spending):
            return joined(person(content), "\(spending.caption): \(spending.total)")
        case .race(let race):
            let lead = race.candidates.first.map { "\($0.name) (\($0.party)) \($0.percent)" }
            return joined(content.headline, lead)
        case .victory(let victory):
            return "\(victory.winner.name) (\(victory.winner.party)): \(victory.statement)"
        case .compare(let rows):
            let names = content.faces.map(\.name).joined(separator: " x ")
            let row = rows.first.map { "\($0.label): \($0.values.joined(separator: " x "))" }
            return joined(names, row)
        case .representatives(let groups):
            let counts = groups.map { "\($0.title) \($0.count)" }.joined(separator: ", ")
            return joined(content.headline, counts)
        case .highlight(let highlight):
            return joined(highlight.title, highlight.place.isEmpty ? nil : highlight.place)
        case .investigation(let investigation):
            return joined(investigation.question, investigation.conclusion)
        case .following(let faces):
            let names = faces.map { "\($0.name) (\($0.party))" }.joined(separator: ", ")
            return joined(content.headline, names)
        case .receipt(let receipt):
            return joined(
                person(content),
                "\(receipt.supplier), \(receipt.amount). \(receipt.context)")
        case .ballot(let ballot):
            return joined(
                person(content),
                String(
                    appLocalized:
                        "Voted \(ballot.vote) on \(ballot.proposition): \(ballot.summary)"))
        case .proposal(let proposal):
            return joined(person(content), "\(proposal.reference): \(proposal.summary)")
        }
    }

    static func person(_ content: ShareCardContent) -> String? {
        content.faces.first.map { "\($0.name) (\($0.party))" }
    }

    static func joined(_ first: String?, _ second: String?) -> String {
        [first, second].compactMap(\.self).filter { !$0.isEmpty }.joined(separator: ": ")
    }

    static func dated(_ content: ShareCardContent) -> String {
        guard !content.source.contains(where: \.isNumber), let day = day(in: content.stamp)
        else { return content.source }
        return "\(content.source) · \(day)"
    }

    static func day(in stamp: String) -> String? {
        guard let range = stamp.range(of: #"\d{4}-\d{2}-\d{2}"#, options: .regularExpression)
        else { return nil }
        let parts = stamp[range].split(separator: "-")
        return [parts[2], parts[1], parts[0]].joined(separator: "/")
    }

    static func clipped(_ text: String, to room: Int) -> String {
        guard text.count > room else { return text }
        guard room > 1 else { return "" }
        return text.prefix(room - 1).trimmingCharacters(in: .whitespaces) + "…"
    }
}
