import Foundation

public struct ContentDetail: Hashable, Identifiable, Sendable {
    public enum Kind: String, Hashable, Sendable {
        case proposal, vote, speech, money, indicator, event

        public var title: String {
            switch self {
            case .proposal: String(appLocalized: "Proposal")
            case .vote: String(appLocalized: "Vote")
            case .speech: String(appLocalized: "Speech")
            case .money: String(appLocalized: "Money")
            case .indicator: String(appLocalized: "Indicator")
            case .event: String(appLocalized: "Today in Congress")
            }
        }
    }

    public let id: String
    public let kind: Kind
    public let title: String
    public let plainSummary: String?
    public let officialSummary: String?
    public let reference: String?
    public let stage: String?
    public let stageNote: String?
    public let effect: String?
    public let date: CalendarDay?
    public let url: URL?
    public let person: PersonCard?
    public let themes: [Theme]
    public let weight: Int?
    public let coverage: WeightCoverage?
    public let method: WeightMethod?
    public let sourceLine: String?
    public let shareHighlightID: String?

    public init(
        id: String, kind: Kind, title: String, plainSummary: String? = nil,
        officialSummary: String? = nil, reference: String? = nil, stage: String? = nil,
        stageNote: String? = nil, effect: String? = nil, date: CalendarDay? = nil, url: URL? = nil,
        person: PersonCard? = nil, themes: [Theme] = [], weight: Int? = nil,
        coverage: WeightCoverage? = nil, method: WeightMethod? = nil, sourceLine: String? = nil,
        shareHighlightID: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.plainSummary = Self.meaningful(plainSummary, besides: title)
        self.officialSummary = Self.meaningful(officialSummary, besides: title)
        self.reference = Self.meaningful(reference, besides: title)
        self.stage = Self.meaningful(stage, besides: title)
        self.stageNote = Self.meaningful(stageNote, besides: title)
        self.effect = Self.meaningful(effect, besides: title)
        self.date = date
        self.url = url.flatMap(Self.webPage)
        self.person = person
        self.themes = themes
        self.weight = weight
        self.coverage = coverage
        self.method = method
        self.sourceLine = Self.meaningful(sourceLine, besides: title)
        self.shareHighlightID = shareHighlightID
    }

    private static func meaningful(_ text: String?, besides title: String) -> String? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty,
            text != title
        else { return nil }
        return text
    }

    private static func webPage(_ url: URL) -> URL? {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
            url.host()?.isEmpty == false
        else { return nil }
        return url
    }

    private static func stage(_ key: String?, in method: WeightMethod?) -> WeightMethod.Value? {
        guard let key else { return nil }
        return method?.stages.first { $0.key == key }
    }
}

extension ContentDetail {
    public init(
        highlight: Highlight, method: WeightMethod?, sourceLine: String?,
        shareHighlightID: String? = nil
    ) {
        let stage = Self.stage(highlight.stage, in: method)
        let describes = highlight.kind == .money || highlight.kind == .indicator
        self.init(
            id: highlight.id, kind: Kind(highlight.kind),
            title: highlight.plainSummary ?? highlight.title,
            plainSummary: describes ? highlight.subtitle : nil,
            officialSummary: highlight.title,
            reference: highlight.proposition, stage: stage?.label, stageNote: stage?.note,
            date: highlight.date, url: highlight.url, person: highlight.person,
            themes: highlight.themes ?? [], weight: highlight.weight,
            coverage: highlight.coverage, method: method, sourceLine: sourceLine,
            shareHighlightID: shareHighlightID)
    }

    public init(
        action: ActionItem, person: PersonCard?, method: WeightMethod?, sourceLine: String?
    ) {
        let stage = Self.stage(action.stage, in: method)
        self.init(
            id: action.id, kind: Kind(action.kind), title: action.title,
            reference: action.proposition, stage: stage?.label, stageNote: stage?.note,
            date: action.date, url: action.url, person: person, themes: action.themes,
            weight: action.weight, coverage: action.coverage, method: method,
            sourceLine: sourceLine)
    }

    public init(proposal: Proposal, effect: String?, person: PersonCard?, sourceLine: String?) {
        self.init(
            id: proposal.id, kind: .proposal, title: proposal.plainSummary ?? proposal.summary,
            officialSummary: proposal.summary, reference: proposal.reference, effect: effect,
            url: proposal.url, person: person, themes: proposal.themes, sourceLine: sourceLine)
    }
}

extension ContentDetail.Kind {
    fileprivate init(_ kind: Highlight.Kind) {
        switch kind {
        case .action: self = .proposal
        case .vote: self = .vote
        case .money: self = .money
        case .indicator: self = .indicator
        }
    }

    fileprivate init(_ kind: ActionItem.Kind) {
        switch kind {
        case .proposal: self = .proposal
        case .vote: self = .vote
        case .speech: self = .speech
        }
    }
}
