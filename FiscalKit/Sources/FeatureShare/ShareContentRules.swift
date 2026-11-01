import FiscalDomain
import Foundation

extension String {
    var isPublished: Bool { !isEmpty && self != PublicFormat.missing }

    var isZero: Bool {
        guard contains(where: \.isNumber) else { return false }
        return !contains { $0.isNumber && $0 != "0" }
    }

    var isMeaningful: Bool { isPublished && !isZero }
}

extension ShareTally {
    var hasCount: Bool { yes.isMeaningful || no.isMeaningful }

    var name: String? {
        let name = proposition.components(separatedBy: " · ").first ?? proposition
        return name.isEmpty ? nil : name
    }

    var relevantOthers: String? { others.isMeaningful ? others : nil }
}

extension ShareHighlight {
    var relevance: String? {
        weight.components(separatedBy: " · ").first.flatMap { $0.isEmpty ? nil : $0 }
    }

    var countedTally: ShareTally? { tally?.hasCount == true ? tally : nil }

    var relevanceDetail: String {
        let parts = weight.components(separatedBy: " · ")
        return parts.count > 1 ? parts[1] : String(appLocalized: "Relevance")
    }

    var shortUncertainty: String? {
        uncertainty?.components(separatedBy: ";").first
    }
}

extension ShareCardContent {
    public var published: ShareCardContent? {
        guard !source.contains(PublicFormat.missing), let body = body.published else { return nil }
        return replacing(body)
    }

    func replacing(_ body: Body) -> ShareCardContent {
        ShareCardContent(
            eyebrow: eyebrow, headline: headline, faces: faces, body: body, source: source,
            stamp: stamp, link: link)
    }
}

extension ShareCardContent.Body {
    fileprivate var published: ShareCardContent.Body? {
        switch self {
        case .person(let metrics):
            let shown = metrics.filter { $0.value.isPublished }
            let leads = shown.filter { !$0.value.isZero }
            guard !leads.isEmpty else { return nil }
            return .person(leads + shown.filter { $0.value.isZero })
        case .vote(let tally):
            return tally.hasCount || tally.result != nil || tally.name != nil ? self : nil
        case .expenses(let spending):
            guard spending.total.isMeaningful else { return nil }
            return .expenses(spending.withoutEmptyCategories)
        case .race(let race):
            let candidates = race.candidates.filter { $0.percent.isMeaningful }
            return candidates.isEmpty ? nil : .race(race.with(candidates))
        case .compare(let rows):
            let shown = rows.filter { row in
                row.values.count >= 2 && row.values.allSatisfy(\.isPublished)
                    && row.values.contains { !$0.isZero }
            }
            return shown.isEmpty ? nil : .compare(shown)
        case .representatives(let groups):
            let shown = groups.filter { $0.count.isMeaningful }
            return shown.isEmpty ? nil : .representatives(shown)
        case .highlight(let highlight):
            return highlight.title.isEmpty ? nil : .highlight(highlight.withCountedTally)
        case .victory(let victory):
            return victory.percent.isMeaningful ? .victory(victory.withoutEmptyBallots) : nil
        case .investigation(let investigation):
            return .investigation(investigation.withPublishedNumbers)
        case .following(let faces):
            return faces.isEmpty ? nil : self
        }
    }
}

extension ShareSpending {
    fileprivate var withoutEmptyCategories: ShareSpending {
        ShareSpending(
            total: total, caption: caption, receipts: receipts,
            categories: categories.filter { $0.value.isMeaningful })
    }
}

extension ShareRace {
    fileprivate func with(_ candidates: [Candidate]) -> ShareRace {
        ShareRace(
            counted: counted, countedShare: countedShare, candidates: candidates,
            footnote: footnote)
    }
}

extension ShareHighlight {
    fileprivate var withCountedTally: ShareHighlight {
        ShareHighlight(
            title: title, person: person, place: place, tally: countedTally, weight: weight,
            uncertainty: uncertainty)
    }
}

extension ShareVictory {
    fileprivate var withoutEmptyBallots: ShareVictory {
        ShareVictory(
            winner: winner, percent: percent, statement: statement, runnerUp: runnerUp,
            ballots: ballots.filter { $0.percent.isMeaningful }, context: context)
    }
}

extension ShareInvestigation {
    fileprivate var withPublishedNumbers: ShareInvestigation {
        ShareInvestigation(
            question: question, conclusion: conclusion,
            numbers: numbers.filter { $0.value.isPublished }, faces: faces, compared: compared,
            uncertainty: uncertainty)
    }
}
