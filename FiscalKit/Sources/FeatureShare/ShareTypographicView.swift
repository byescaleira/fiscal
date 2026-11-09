import CoreGraphics
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public struct ShareStatement: Hashable, Sendable {
    public struct Row: Hashable, Sendable, Identifiable {
        public let label: String
        public let value: String

        public var id: String { label }
    }

    public let eyebrow: String
    public let phrase: String?
    public let figure: String?
    public let caption: String?
    public let person: ShareFace?
    public let rows: [Row]
    public let people: [ShareFace]
    public let note: String?

    public init(_ content: ShareCardContent) {
        eyebrow = content.eyebrow
        rows = Self.rows(of: content)
        note = Self.note(of: content)
        if case .following(let faces) = content.body { people = faces } else { people = [] }
        switch content.body {
        case .person(let metrics):
            let lead = metrics.first
            phrase = nil
            figure = lead?.value
            caption = lead?.label
            person = content.faces.first
        case .vote(let tally):
            if tally.hasCount {
                phrase = tally.name ?? content.headline
                figure = "\(tally.yes) × \(tally.no)"
                caption = String(appLocalized: "Yes × No")
            } else {
                phrase = [tally.name, tally.result].compactMap(\.self).joined(separator: ": ")
                figure = nil
                caption = content.headline
            }
            person = nil
        case .expenses(let spending):
            phrase = nil
            figure = spending.total
            caption = spending.caption
            person = content.faces.first
        case .race(let race):
            let leader = race.candidates.first
            phrase = content.headline
            figure = leader?.percent
            caption = leader.map { "\($0.name) · \($0.party)" }
            person = nil
        case .victory(let victory):
            phrase = nil
            figure = victory.percent
            caption = victory.statement
            person = victory.winner
        case .compare(let rows):
            let row = rows.first
            phrase = content.faces.map(\.name).joined(separator: " x ")
            figure = row?.values.joined(separator: " × ")
            caption = row?.label
            person = nil
        case .representatives:
            phrase = content.headline
            figure = nil
            caption = nil
            person = nil
        case .highlight(let highlight):
            let tally = highlight.countedTally
            phrase = highlight.title
            figure = tally.map { "\($0.yes) × \($0.no)" }
            caption = highlight.place.isEmpty ? nil : highlight.place
            person = highlight.person
        case .investigation(let investigation):
            let number = investigation.numbers.first
            phrase = investigation.conclusion
            figure = number?.value
            caption = number?.label
            person = nil
        case .following:
            phrase = content.headline
            figure = nil
            caption = nil
            person = nil
        case .receipt(let receipt):
            phrase = receipt.supplier
            figure = receipt.amount
            caption = receipt.context
            person = content.faces.first
        case .ballot(let ballot):
            phrase = ballot.summary
            figure = ballot.vote
            caption = ballot.proposition
            person = content.faces.first
        case .proposal(let proposal):
            phrase = proposal.summary
            figure = nil
            caption = proposal.reference
            person = content.faces.first
        }
    }

    private static func note(of content: ShareCardContent) -> String? {
        switch content.body {
        case .expenses(let spending): spending.receipts
        case .race(let race): race.counted
        case .highlight(let highlight): highlight.shortUncertainty
        case .investigation(let investigation): investigation.uncertainty
        default: nil
        }
    }

    private static func rows(of content: ShareCardContent) -> [Row] {
        switch content.body {
        case .person(let metrics):
            return metrics.dropFirst().map { Row(label: $0.label, value: $0.value) }
        case .vote(let tally):
            guard tally.hasCount else { return [] }
            return [
                tally.result.map { Row(label: String(appLocalized: "Result"), value: $0) },
                tally.relevantOthers.map { Row(label: String(appLocalized: "Others"), value: $0) },
            ].compactMap(\.self)
        case .expenses(let spending):
            return spending.categories.map { Row(label: $0.name, value: $0.value) }
        case .race(let race):
            return race.candidates.dropFirst().map {
                Row(label: "\($0.name) · \($0.party)", value: $0.percent)
            }
        case .compare(let rows):
            return rows.dropFirst().map {
                Row(label: $0.label, value: $0.values.joined(separator: " × "))
            }
        case .representatives(let groups):
            return groups.map { Row(label: $0.title, value: $0.count) }
        case .highlight(let highlight):
            return highlight.relevance.map {
                [Row(label: highlight.relevanceDetail, value: $0)]
            } ?? []
        case .victory(let victory):
            let runner =
                victory.runnerUp.map {
                    [Row(label: $0.face.name, value: $0.percent)]
                } ?? []
            return runner
                + victory.ballots.filter { $0.kind != .valid }.map {
                    Row(label: $0.title, value: $0.percent)
                }
        case .investigation(let investigation):
            return investigation.numbers.dropFirst().map { Row(label: $0.label, value: $0.value) }
        case .following, .proposal:
            return []
        case .receipt(let receipt):
            return [
                Row(label: String(appLocalized: "Kind of expense"), value: receipt.category),
                Row(label: String(appLocalized: "Month"), value: receipt.period),
            ]
        case .ballot(let ballot):
            return [
                Row(label: String(appLocalized: "Date"), value: ballot.date),
                ballot.result.map { Row(label: String(appLocalized: "Result"), value: $0) },
            ].compactMap(\.self)
        }
    }

    public var texts: [String] {
        [eyebrow, phrase, figure, caption, note, person?.name, person?.party].compactMap(\.self)
            + rows.flatMap { [$0.label, $0.value] }
            + people.flatMap { [$0.name, $0.party, $0.detail] }
    }
}

extension ShareCardContent {
    public var stageParties: [String] {
        switch body {
        case .compare: faces.prefix(2).map(\.party)
        case .following, .representatives: []
        case .highlight(let highlight): highlight.person.map { [$0.party] } ?? []
        case .victory(let victory): [victory.winner.party]
        default: faces.dropFirst().isEmpty ? faces.map(\.party) : []
        }
    }

    var accent: Color {
        switch body {
        case .vote, .highlight, .ballot: .retroTeal
        case .person, .representatives, .proposal: .retroDenim
        case .expenses, .receipt: .retroMustard
        case .compare, .investigation: .retroPlum
        case .race, .victory: .retroOrange
        case .following: .retroOlive
        }
    }
}

struct ShareTypographicView: View {
    let card: ShareCard
    let code: CGImage?

    var body: some View {
        let format = card.format
        let statement = card.statement
        let facts = statement.rows.prefix(
            statement.figure == nil ? format.folhaRowsWithoutFigure : format.folhaRows
        )
        .map { SharePoster.Fact(value: $0.value, label: $0.label) }
        VStack(spacing: .zero) {
            ShareHeaderBlock(
                card: card, color: card.content.leadColor,
                title: statement.figure == nil && statement.people.isEmpty ? nil : statement.phrase,
                person: statement.person)
            ShareFolhaHero(card: card, statement: statement)
            ShareTileRows(
                facts: facts, color: card.content.leadColor, side: format.textInsets.leading)
            ShareFooterBlock(card: card, code: code)
            if format == .stories {
                ShareZoneArt(content: card.content)
                    .frame(height: .shareSafeBottom)
                    .accessibilityHidden(true)
            }
        }
        .background(Color.sharePaper)
    }
}

private struct ShareFolhaHero: View {
    let card: ShareCard
    let statement: ShareStatement

    var body: some View {
        let format = card.format
        let side = format.textInsets.leading
        VStack(alignment: .leading, spacing: .space2XS) {
            Spacer(minLength: .zero)
            if let figure = statement.figure {
                ShareFigure(
                    value: figure,
                    size: format.figureSize(.shareFolhaFigure, for: figure, in: format.safeWidth))
            } else if statement.people.isEmpty, let phrase = statement.phrase {
                Text(verbatim: phrase)
                    .font(.posterTitle(format.phraseSize(for: phrase, lines: 5)))
                    .lineLimit(5)
                    .minimumScaleFactor(.posterShrink)
                    .shareReveal(2)
            }
            if let caption = statement.caption, !caption.isEmpty {
                Text(verbatim: caption)
                    .font(.posterHeadlineCompact)
                    .foregroundStyle(Color.posterSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(.shareTextShrink)
                    .fixedSize(horizontal: false, vertical: true)
                    .shareReveal(3)
            }
            if let note = statement.note, !note.isEmpty {
                Text(verbatim: note)
                    .font(.posterLabel)
                    .foregroundStyle(Color.posterSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(.shareTextShrink)
                    .fixedSize(horizontal: false, vertical: true)
                    .shareReveal(4)
            }
            ForEach(Array(statement.people.enumerated()), id: \.offset) { index, face in
                ShareFolhaPerson(face: face)
                    .shareReveal(2 + index)
            }
            Spacer(minLength: .zero)
        }
        .foregroundStyle(Color.primary)
        .padding(.horizontal, side)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color.sharePaper)
        .environment(\.colorScheme, .light)
    }
}

struct ShareFaceLine: View {
    let face: ShareFace

    var body: some View {
        VStack(alignment: .leading, spacing: .space2XS) {
            Text(verbatim: face.name)
                .font(.posterName)
                .lineLimit(1)
                .minimumScaleFactor(.shareTextShrink)
            PartyMark(face.party)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct ShareFolhaPerson: View {
    let face: ShareFace

    var body: some View {
        HStack(spacing: .spaceS) {
            SharePartyStripes(party: face.party)
            Text(verbatim: face.name)
                .font(.posterName)
                .lineLimit(1)
                .minimumScaleFactor(.shareTextShrink)
            Spacer(minLength: .zero)
            Text(verbatim: [face.party, face.detail].joined(separator: " · "))
                .font(.posterLabel)
                .foregroundStyle(Color.posterSecondary)
                .lineLimit(1)
                .minimumScaleFactor(.shareTextShrink)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
