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
            title = content.headline ?? tally.name
            lead = nil
            person = nil
            layout = tally.hasCount ? .tally(tally) : .cells([])
            note = tally.hasCount ? nil : tally.result
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
            note = victory.runnerUp.map { "\($0.face.name) · \($0.face.party): \($0.percent)" }
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
            layout =
                highlight.countedTally.map(Layout.tally)
                ?? .cells(
                    highlight.relevance.map {
                        [SharePoster.Fact(value: $0, label: highlight.relevanceDetail)]
                    } ?? [])
            note = [highlight.place, highlight.shortUncertainty ?? ""].filter { !$0.isEmpty }
                .joined(separator: " · ")
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
    var isEmpty: Bool {
        switch self {
        case .cells(let cells): cells.isEmpty
        case .bars(let bars): bars.isEmpty
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
        let side = format.textInsets.leading
        let titleLeads = board.lead == nil && board.layout.isEmpty
        return VStack(spacing: .zero) {
            ShareHeaderBlock(
                card: card, color: .shareDataField,
                title: board.lead == nil && !titleLeads ? board.title : nil, person: board.person)
            if let lead = board.lead {
                ShareTile(
                    fact: SharePoster.Fact(value: lead, label: board.title ?? ""), tone: .lead,
                    color: color, leading: side, trailing: side,
                    size: format.figureSize(
                        .shareFolhaHook * 2, for: lead, in: format.safeWidth))
            }
            if titleLeads, let title = board.title {
                ShareTitleTile(title: title, color: color, format: format)
            }
            ShareBoardMosaic(layout: board.layout, format: format, color: color, card: card)
            ShareFooterBlock(card: card, code: code, note: board.note)
            if format == .stories {
                ShareZoneArt(content: card.content)
                    .frame(height: .shareSafeBottom)
                    .accessibilityHidden(true)
            }
        }
        .background(Color.shareDataField)
    }
}

private struct ShareTitleTile: View {
    let title: String
    let color: Color
    let format: ShareFormat

    var body: some View {
        Text(verbatim: title)
            .font(.posterTitle(format.phraseSize(for: title, lines: 5)))
            .lineLimit(5)
            .minimumScaleFactor(.posterShrink)
            .foregroundStyle(Color.primary)
            .padding(.horizontal, format.textInsets.leading)
            .padding(.vertical, .spaceS)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .shareReveal(3)
            .background { ShareBlockField(color: color, order: 2) }
            .environment(\.colorScheme, .dark)
    }
}

private struct ShareBoardMosaic: View {
    let layout: ShareBoard.Layout
    let format: ShareFormat
    let color: Color
    let card: ShareCard

    var body: some View {
        let side = format.textInsets.leading
        switch layout {
        case .tally(let tally):
            ShareTallyMosaic(tally: tally, format: format)
        case .bars(let bars):
            if !bars.isEmpty {
                VStack(spacing: .spaceHairline) {
                    ForEach(Array(bars.prefix(format == .feed ? 4 : 3).enumerated()), id: \.offset)
                    {
                        index, bar in
                        ShareBarRow(bar: bar, color: color, side: side, order: 3 + index)
                    }
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
            if !cells.isEmpty {
                ShareTileRows(
                    facts: cells, color: color, side: side, fills: true,
                    tones: [.lead, .paper, .ink])
            }
        case .versus(let faces, let rows):
            ShareVersusHero(faces: faces, rows: rows, format: format.textFormat)
                .padding(.horizontal, side)
                .frame(maxHeight: .infinity)
        case .people(let faces):
            SharePeopleTiles(faces: faces, content: card.content, side: side)
        }
    }
}

private struct SharePeopleTiles: View {
    let faces: [ShareFace]
    let content: ShareCardContent
    let side: CGFloat
    private let perRow = 2

    var body: some View {
        VStack(spacing: .zero) {
            ForEach(Array(stride(from: 0, to: faces.count, by: perRow)), id: \.self) { start in
                let row = Array(faces[start..<Swift.min(start + perRow, faces.count)])
                HStack(spacing: .zero) {
                    ForEach(Array(row.enumerated()), id: \.element.id) { index, face in
                        VStack(alignment: .leading, spacing: .space2XS) {
                            Spacer(minLength: .zero)
                            Text(verbatim: face.name)
                                .font(.posterName)
                                .lineLimit(2)
                                .minimumScaleFactor(.shareTextShrink)
                                .fixedSize(horizontal: false, vertical: true)
                            PartyMark(face.party)
                                .fixedSize()
                        }
                        .shareReveal(3 + start + index)
                        .foregroundStyle(Color.primary)
                        .padding(.leading, index == 0 ? side : .spaceS)
                        .padding(.trailing, index == row.count - 1 ? side : .spaceS)
                        .padding(.vertical, .spaceS)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .background {
                            ShareBlockField(
                                color: content.blockColor(party: face.party),
                                order: 2 + start + index)
                        }
                    }
                }
            }
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
                    size: .shareStatLead, order: 2)
                ShareTile(
                    fact: SharePoster.Fact(value: tally.no, label: String(appLocalized: "No")),
                    tone: .lead, color: .voteNoBoard, leading: .spaceS, trailing: side,
                    size: .shareStatLead, order: 3)
            }
            HStack(alignment: .firstTextBaseline, spacing: .spaceM) {
                if let result = tally.result {
                    Text(verbatim: result)
                        .font(.posterHeadline)
                }
                Spacer(minLength: .zero)
                if let others = tally.relevantOthers {
                    Text(verbatim: "\(others) \(String(appLocalized: "Others"))")
                        .font(.posterLabel)
                        .foregroundStyle(Color.posterSecondary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(.shareTextShrink)
            .shareReveal(5)
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
    let order: Int

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
        .shareReveal(order)
        .padding(.horizontal, side)
        .frame(maxWidth: .infinity, minHeight: .shareBarRowHeight, maxHeight: .infinity)
        .background(alignment: .leading) {
            GeometryReader { proxy in
                ShareBlockField(color: color)
                    .frame(
                        width: proxy.size.width * ShareMotion.fill(bar.share, progress: progress))
            }
        }
    }
}
