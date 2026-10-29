import FeatureCore
import FiscalDomain
import Foundation

extension PastPick {
    var displayName: String { MemoryText.name(ballotName) }
    var portraitSlug: String { MemoryText.slug(ballotName) }
    var shareText: String { MemoryText.percent(share) }
    var shortShareText: String { MemoryText.shortPercent(share) }
}

extension PastCandidate {
    var displayName: String { MemoryText.name(ballotName) }
    var portraitSlug: String { MemoryText.slug(ballotName) }
    var shareText: String { MemoryText.percent(share) }
    var votesText: String { MemoryText.votes(votes) }
}

extension PastRoundBreakdown.Bar {
    var shareText: String { MemoryText.percent(share) }
    var shortShareText: String { MemoryText.shortPercent(share) }
    var votesText: String { MemoryText.votes(votes) }
    var accessibilityValue: String { "\(shareText), \(votesText)" }
}

extension PastRoundBreakdown.Tile {
    var shortShareText: String { MemoryText.shortPercent(share) }
}

extension PastRoundBreakdown {
    var leaderNames: String {
        let elected = winners.filter(\.elected)
        guard elected.count > 1 else { return leader?.displayName ?? "" }
        return elected.map(\.displayName).formatted(.list(type: .and).locale(.app))
    }

    func accessibilityValue(_ tile: Tile) -> String {
        guard let winner = candidate(number: tile.winner) else { return PublicFormat.missing }
        return "\(winner.displayName), \(tile.shortShareText)"
    }
}

extension PeriodPresident {
    var portraitSlug: String { MemoryText.slug(name) }
}

extension PoliticalPeriod {
    var yearsText: String { MemoryText.years(start: startDay, end: endDay) }
    var eraTitle: String { era.uppercased(with: .app) }
    var presidentsSourceLine: String { MemoryText.sources(presidents.flatMap(\.sources)) ?? "" }
}

extension PeriodMilestone {
    var symbol: String { MilestoneStyle.symbol(kind) }
    var dateLine: String { "\(MemoryText.day(day)) · \(MilestoneStyle.label(kind))" }
}

extension PeriodIndicator {
    func valueText(_ value: Double) -> String {
        let number = value.formatted(.number.precision(.fractionLength(0...2)).locale(.app))
        return unit.hasPrefix("%") ? "\(number)%" : number
    }
}

extension HistoryPoint {
    static func yearText(_ year: Int) -> String { String(year) }

    var yearText: String { Self.yearText(year) }
}

extension PeriodDivergence {
    func positionText(_ index: Int) -> String { String(index + 1) }
}

extension StudyCard {
    var sourceLine: String { MemoryText.sources(sources) ?? "" }
}

extension StudyGuide {
    var symbol: String { StudySymbols.symbol(for: id) }
    var countText: String { StudySymbols.count(self) }

    func cardPosition(_ index: Int) -> String {
        "\(index + 1)/\(cards.count)"
    }

    func questionTitle(_ index: Int) -> String {
        quiz.indices.contains(index) ? "\(index + 1). \(quiz[index].question)" : ""
    }
}
