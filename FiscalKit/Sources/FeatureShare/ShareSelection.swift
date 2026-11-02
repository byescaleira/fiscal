import FiscalDomain
import Foundation

public struct ShareFact: Hashable, Sendable, Identifiable {
    public enum Group: String, Hashable, Sendable {
        case metric, row, category, weight, code
    }

    public static let code = ShareFact(
        id: Group.code.rawValue, title: String(appLocalized: "QR code"), group: .code)

    public let id: String
    public let title: String
    public let group: Group

    public init(id: String, title: String, group: Group) {
        self.id = id
        self.title = title
        self.group = group
    }

    public var isOptional: Bool { true }

    static func metric(_ label: String) -> ShareFact {
        ShareFact(id: "\(Group.metric.rawValue).\(label)", title: label, group: .metric)
    }

    static func row(_ label: String) -> ShareFact {
        ShareFact(id: "\(Group.row.rawValue).\(label)", title: label, group: .row)
    }

    static let largestCategory = ShareFact(
        id: Group.category.rawValue, title: String(appLocalized: "Largest category"),
        group: .category)

    static let weight = ShareFact(
        id: Group.weight.rawValue, title: String(appLocalized: "Relevance"), group: .weight)
}

public struct ShareSelection: Hashable, Sendable {
    public private(set) var hidden: Set<String>
    public private(set) var showsCode: Bool

    public init(hidden: Set<String> = [], showsCode: Bool = true) {
        self.hidden = hidden
        self.showsCode = showsCode
    }

    public func isOn(_ fact: ShareFact) -> Bool {
        fact.group == .code ? showsCode : !hidden.contains(fact.id)
    }

    public func canToggle(_ fact: ShareFact, among facts: [ShareFact]) -> Bool {
        guard isOn(fact), fact.group == .metric || fact.group == .row else { return true }
        return facts.contains { $0.group == fact.group && $0.id != fact.id && isOn($0) }
    }

    public mutating func toggle(_ fact: ShareFact, among facts: [ShareFact]) {
        guard canToggle(fact, among: facts) else { return }
        if fact.group == .code {
            showsCode.toggle()
        } else if hidden.contains(fact.id) {
            hidden.remove(fact.id)
        } else {
            hidden.insert(fact.id)
        }
    }
}

extension ShareCardContent {
    public var optionalFacts: [ShareFact] {
        switch body {
        case .person(let metrics): metrics.map { ShareFact.metric($0.label) }
        case .compare(let rows): rows.map { ShareFact.row($0.label) }
        case .expenses(let spending): spending.categories.isEmpty ? [] : [.largestCategory]
        case .highlight(let highlight): highlight.weight.isEmpty ? [] : [.weight]
        case .vote, .race, .representatives, .victory, .investigation, .following, .receipt,
            .ballot, .proposal:
            []
        }
    }

    public func applying(_ selection: ShareSelection) -> ShareCardContent {
        let filtered: Body =
            switch body {
            case .person(let metrics):
                .person(metrics.filter { selection.isOn(.metric($0.label)) })
            case .compare(let rows):
                .compare(rows.filter { selection.isOn(.row($0.label)) })
            case .expenses(let spending) where !selection.isOn(.largestCategory):
                .expenses(
                    ShareSpending(
                        total: spending.total, caption: spending.caption,
                        receipts: spending.receipts, categories: []))
            case .highlight(let highlight) where !selection.isOn(.weight):
                .highlight(
                    ShareHighlight(
                        title: highlight.title, person: highlight.person, place: highlight.place,
                        tally: highlight.tally, weight: "", uncertainty: highlight.uncertainty))
            default: body
            }
        return ShareCardContent(
            eyebrow: eyebrow, headline: headline, faces: faces, body: filtered, source: source,
            stamp: stamp, link: link)
    }
}
