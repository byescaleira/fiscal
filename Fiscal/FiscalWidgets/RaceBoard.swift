import ActivityKit
import FiscalDesignSystem
import FiscalDomain
import SwiftUI
import WidgetKit

enum RaceStyle {
    static let accent = Color.scoreboardAccent
    static let primary = Color.primary
    static let secondary = Color.secondary
    static let track = Color.secondary.opacity(.opacityTint)
}

struct RaceBoard {
    let title: String
    let rows: [RaceActivityRow]
    let state: RaceActivityState
    let isStale: Bool

    init(context: ActivityViewContext<RaceActivityAttributes>) {
        title = RaceText.title(office: context.attributes.office, uf: context.attributes.uf)
        rows = context.state.rows(with: context.attributes.candidates)
        state = context.state
        isStale = context.isStale
    }

    var first: RaceActivityRow? { rows.first }
    var second: RaceActivityRow? { rows.dropFirst().first }
    var hasStarted: Bool { state.sectionsPercent > 0 }
    var firstPalette: PartyPalette { first.map(palette) ?? PartyPalette.of(party: "", fallback: 0) }
    var secondPalette: PartyPalette {
        second.map(palette) ?? PartyPalette.of(party: "", fallback: 1)
    }

    func palette(_ row: RaceActivityRow) -> PartyPalette {
        let index = rows.firstIndex { $0.number == row.number } ?? 0
        return PartyPalette.of(party: row.party, fallback: index)
    }

    var officeText: String { title }

    var centerValue: String {
        state.final ? String(appLocalized: "Final") : RaceText.shortPercent(state.sectionsPercent)
    }

    var centerCaption: String {
        state.final ? String(appLocalized: "TSE") : String(appLocalized: "counted")
    }

    var marginText: String {
        if let elected = rows.first(where: \.elected) { return RaceText.elected(elected.name) }
        guard hasStarted, let first, let second else {
            return String(appLocalized: "Starts at 5 PM Brasília time")
        }
        return String(
            appLocalized: "Votes apart: \(RaceText.votes(abs(first.votes - second.votes)))")
    }

    var countText: String {
        state.final
            ? String(appLocalized: "Final result")
            : String(appLocalized: "\(RaceText.shortPercent(state.sectionsPercent)) counted")
    }

    var sourceText: String {
        let time = RaceText.time(state.updatedDate)
        return isStale
            ? String(appLocalized: "No update since \(time) · TSE")
            : String(appLocalized: "TSE file from \(time)")
    }

    func score(_ row: RaceActivityRow) -> CandidateScoreText {
        CandidateScoreText(
            number: row.number,
            palette: palette(row),
            name: row.name,
            detail: "\(row.party) · \(row.number)",
            percent: hasStarted ? RaceText.percent(row.percent) : "—",
            shortPercent: hasStarted ? RaceText.shortPercent(row.percent) : "—",
            value: row.percent,
            elected: row.elected,
            dimmed: state.final && !row.elected,
            accessibility: RaceWidgetText.row(row))
    }
}

struct CandidateScoreText {
    let number: String
    let palette: PartyPalette
    let name: String
    let detail: String
    let percent: String
    let shortPercent: String
    let value: Double
    let elected: Bool
    let dimmed: Bool
    let accessibility: String
}

enum RaceWidgetText {
    static func row(_ row: RaceActivityRow) -> String {
        let votes = String(appLocalized: "\(RaceText.votes(row.votes)) votes")
        let base = "\(row.name), \(row.party), \(RaceText.percent(row.percent)), \(votes)"
        return row.elected ? "\(base), \(String(appLocalized: "Elected"))" : base
    }
}
