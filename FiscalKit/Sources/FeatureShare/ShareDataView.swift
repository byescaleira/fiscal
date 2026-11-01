import CoreGraphics
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public struct ShareBoard: Hashable, Sendable {
    public struct Bar: Hashable, Sendable, Identifiable {
        public let label: String
        public let value: String
        public let share: Double

        public var id: String { label }
    }

    public enum Layout: Hashable, Sendable {
        case tally(ShareTally)
        case bars([Bar])
        case stats(lead: SharePoster.Fact, rest: [SharePoster.Fact])
        case cells([SharePoster.Fact])
        case versus([ShareFace], [ShareCompareRow])
        case people([ShareFace])
    }

    public let eyebrow: String
    public let title: String?
    public let lead: String?
    public let person: ShareFace?
    public let layout: Layout
    public let note: String?

    public init(_ content: ShareCardContent) {
        eyebrow = content.eyebrow
        switch content.body {
        case .person(let metrics):
            title = nil
            lead = nil
            person = content.faces.first
            let facts = metrics.map { SharePoster.Fact(value: $0.value, label: $0.label) }
            if let lead = facts.first(where: { $0.value != PublicFormat.missing }) ?? facts.first {
                layout = .stats(lead: lead, rest: facts.filter { $0 != lead })
            } else {
                layout = .cells([])
            }
            note = nil
        case .vote(let tally):
            title = content.headline ?? tally.proposition
            lead = nil
            person = nil
            layout = .tally(tally)
            note = nil
        case .expenses(let spending):
            title = spending.caption
            lead = spending.total
            person = content.faces.first
            layout = .bars(
                spending.categories.map {
                    Bar(label: $0.name, value: $0.value, share: $0.share)
                })
            note = spending.receipts
        case .race(let race):
            title = content.headline
            lead = nil
            person = nil
            layout = .bars(
                race.candidates.map {
                    Bar(label: "\($0.name) · \($0.party)", value: $0.percent, share: $0.share)
                })
            note = race.counted
        case .victory(let victory):
            title = victory.statement
            lead = victory.percent
            person = victory.winner
            layout = .bars(
                victory.ballots.map {
                    Bar(label: $0.title, value: $0.percent, share: $0.share)
                })
            note = nil
        case .compare(let rows):
            title = nil
            lead = nil
            person = nil
            layout = .versus(Array(content.faces.prefix(2)), rows)
            note = nil
        case .representatives(let groups):
            title = content.headline
            lead = nil
            person = nil
            layout = .cells(groups.map { SharePoster.Fact(value: $0.count, label: $0.title) })
            note = nil
        case .highlight(let highlight):
            title = highlight.title
            lead = nil
            person = highlight.person
            layout = highlight.tally.map(Layout.tally) ?? .cells([])
            note = highlight.weight.isEmpty ? highlight.place : highlight.weight
        case .investigation(let investigation):
            title = investigation.conclusion
            lead = nil
            person = nil
            layout = .cells(investigation.numbers)
            note = investigation.uncertainty
        case .following(let faces):
            title = content.headline
            lead = nil
            person = nil
            layout = .people(faces)
            note = nil
        }
    }

    public var texts: [String] {
        [eyebrow, title, lead, person?.name, person?.party].compactMap(\.self) + layout.texts
            + [note].compactMap(\.self)
    }
}

extension ShareBoard.Layout {
    var fillsTheCard: Bool {
        switch self {
        case .stats: true
        case .cells(let cells): !cells.isEmpty
        default: false
        }
    }

    var texts: [String] {
        switch self {
        case .tally(let tally):
            [tally.yes, tally.no, tally.others, tally.result].compactMap(\.self)
        case .bars(let bars): bars.flatMap { [$0.label, $0.value] }
        case .stats(let lead, let rest): ([lead] + rest).flatMap { [$0.value, $0.label] }
        case .cells(let cells): cells.flatMap { [$0.value, $0.label] }
        case .versus(let faces, let rows):
            faces.flatMap { [$0.name, $0.party] } + rows.flatMap { [$0.label] + $0.values }
        case .people(let faces): faces.flatMap { [$0.name, $0.party] }
        }
    }
}

struct ShareDataView: View {
    let card: ShareCard
    let code: CGImage?

    var body: some View {
        if let duel = card.duel {
            ShareDuelView(card: card, duel: duel, code: code)
        } else {
            standard
        }
    }

    private var standard: some View {
        let format = card.format
        let board = card.board
        let color = card.content.leadColor
        return VStack(spacing: .zero) {
            ShareHeaderBlock(
                card: card, color: .shareDataField,
                title: board.lead == nil ? board.title : nil, person: board.person
            ) {
                if let person = board.person {
                    PersonPortrait(
                        slug: person.slug, name: person.name, party: person.party,
                        size: .shareHeaderPortrait)
                }
            }
            if let lead = board.lead {
                ShareTile(
                    fact: SharePoster.Fact(value: lead, label: board.title ?? ""), tone: .lead,
                    color: color, leading: format.textInsets.leading,
                    trailing: format.textInsets.leading,
                    size: format.figureSize(
                        .shareFolhaHook * 2, for: lead, in: format.safeWidth))
            }
            ShareBoardMosaic(layout: board.layout, format: format, color: color)
            ShareFooterBlock(card: card, code: code)
            if format == .stories {
                ShareZoneArt(content: card.content)
                    .frame(height: .shareSafeBottom)
                    .accessibilityHidden(true)
            }
        }
        .background(Color.shareDataField)
    }
}

private struct ShareBoardMosaic: View {
    let layout: ShareBoard.Layout
    let format: ShareFormat
    let color: Color

    var body: some View {
        let side = format.textInsets.leading
        switch layout {
        case .tally(let tally):
            ShareTallyMosaic(tally: tally, format: format)
        case .bars(let bars):
            VStack(spacing: .spaceHairline) {
                ForEach(bars.prefix(format == .feed ? 4 : 3)) { bar in
                    ShareBarRow(bar: bar, color: color, side: side)
                }
            }
        case .stats(let lead, let rest):
            VStack(spacing: .zero) {
                ShareTile(
                    fact: lead, tone: .lead, color: color, leading: side, trailing: side,
                    size: format.figureSize(.shareStatLead, for: lead.value, in: format.safeWidth))
                ShareTileRows(facts: Array(rest.prefix(3)), color: color, side: side)
            }
        case .cells(let cells):
            ShareTileRows(facts: cells, color: color, side: side, fills: true)
        case .versus(let faces, let rows):
            ShareVersusHero(faces: faces, rows: rows, format: format.textFormat)
                .padding(.horizontal, side)
                .frame(maxHeight: .infinity)
        case .people(let faces):
            SharePeopleList(faces: faces, format: format.textFormat)
                .padding(.horizontal, side)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

private struct ShareTallyMosaic: View {
    let tally: ShareTally
    let format: ShareFormat

    var body: some View {
        let side = format.textInsets.leading
        VStack(spacing: .zero) {
            HStack(spacing: .zero) {
                ShareTile(
                    fact: SharePoster.Fact(value: tally.yes, label: String(appLocalized: "Yes")),
                    tone: .lead, color: .voteYesBoard, leading: side, trailing: .spaceS,
                    size: .shareStatLead)
                ShareTile(
                    fact: SharePoster.Fact(value: tally.no, label: String(appLocalized: "No")),
                    tone: .lead, color: .voteNoBoard, leading: .spaceS, trailing: side,
                    size: .shareStatLead)
            }
            HStack(alignment: .firstTextBaseline, spacing: .spaceM) {
                if let result = tally.result {
                    Text(verbatim: result)
                        .font(.posterHeadline)
                }
                Spacer(minLength: .zero)
                Text(verbatim: "\(tally.others) \(String(appLocalized: "Others"))")
                    .font(.posterLabel)
                    .foregroundStyle(Color.posterSecondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(.shareTextShrink)
            .padding(.horizontal, side)
            .padding(.vertical, .spaceS)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct ShareBarRow: View {
    @Environment(\.shareProgress) private var progress
    let bar: ShareBoard.Bar
    let color: Color
    let side: CGFloat

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: .spaceS) {
            Text(verbatim: bar.label)
                .font(.posterLabel)
                .lineLimit(1)
                .minimumScaleFactor(.shareTextShrink)
            Spacer(minLength: .zero)
            ShareFigure(value: bar.value, size: .shareDataBarFigure)
                .fixedSize()
        }
        .padding(.horizontal, side)
        .frame(maxWidth: .infinity, minHeight: .shareBarRowHeight)
        .background(alignment: .leading) {
            GeometryReader { proxy in
                ShareBlockField(color: color)
                    .frame(
                        width: proxy.size.width * ShareMotion.fill(bar.share, progress: progress))
            }
        }
    }
}
