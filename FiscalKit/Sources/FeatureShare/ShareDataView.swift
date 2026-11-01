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

    @ViewBuilder private var standard: some View {
        let format = card.format
        let board = card.board
        VStack(alignment: .leading, spacing: .spaceXS) {
            Text(verbatim: board.eyebrow)
                .font(.posterEyebrow)
                .tracking(.posterTracking)
                .foregroundStyle(Color.posterSecondary)
                .lineLimit(1)
                .minimumScaleFactor(.shareTextShrink)
                .fixedSize(horizontal: false, vertical: true)
            if let person = board.person {
                ShareFaceLine(face: person, showsPortrait: format != .stories)
            }
            if board.lead == nil, let title = board.title {
                ShareBoardTitle(title: title, format: format)
            }
            if !board.layout.fillsTheCard {
                Spacer(minLength: .zero)
            }
            if let lead = board.lead {
                ShareFigure(
                    value: lead,
                    size: format.figureSize(
                        format == .feed ? format.scoreSize : .shareDataLead, for: lead,
                        in: format.safeWidth)
                )
                .fixedSize(horizontal: false, vertical: true)
                if let title = board.title {
                    ShareBoardTitle(title: title, format: format)
                }
            }
            ShareBoardLayout(layout: board.layout, format: format)
            if let note = board.note, !note.isEmpty, format == .feed || board.lead == nil {
                Text(verbatim: note)
                    .font(.posterLabel)
                    .foregroundStyle(Color.posterSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(.shareTextShrink)
            }
            if !board.layout.fillsTheCard {
                Spacer(minLength: .zero)
            }
            ShareFooter(card: card, code: code)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(format.textInsets)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            ShareStageField(parties: card.content.stageParties)
        }
        .overlay(alignment: .bottom) {
            if format == .stories {
                ShareDataZone(content: card.content)
                    .frame(height: .shareFolhaBand)
                    .environment(\.colorScheme, .light)
                    .accessibilityHidden(true)
            }
        }
    }
}

private struct ShareBoardTitle: View {
    let title: String
    let format: ShareFormat

    var body: some View {
        Text(verbatim: title)
            .font(format == .feed ? .posterHeadline : .posterHeadlineCompact)
            .lineLimit(3)
            .minimumScaleFactor(.shareTextShrink)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct ShareBoardLayout: View {
    let layout: ShareBoard.Layout
    let format: ShareFormat

    var body: some View {
        let compact = format.textFormat
        switch layout {
        case .tally(let tally):
            ShareTallyHero(
                tally: tally, format: compact, size: compact.scoreSize, animates: true)
        case .bars(let bars):
            VStack(alignment: .leading, spacing: .spaceXS) {
                ForEach(bars.prefix(format == .feed ? 4 : 3)) { bar in
                    ShareBarRow(bar: bar, format: format)
                }
            }
        case .stats(let lead, let rest):
            VStack(spacing: .spaceXS) {
                ShareStatTile(fact: lead, size: .shareStatLead, width: format.safeWidth)
                if !rest.isEmpty {
                    HStack(spacing: .spaceXS) {
                        ForEach(rest.prefix(3)) { fact in
                            ShareStatTile(
                                fact: fact, size: .shareStatSmall,
                                width: format.safeWidth / CGFloat(min(rest.count, 3)))
                        }
                    }
                }
            }
        case .cells(let cells):
            ShareBoardCells(cells: cells, format: format)
        case .versus(let faces, let rows):
            ShareVersusHero(faces: faces, rows: rows, format: compact)
        case .people(let faces):
            SharePeopleList(faces: faces, format: compact)
        }
    }
}

private struct ShareBarRow: View {
    @Environment(\.shareProgress) private var progress
    let bar: ShareBoard.Bar
    let format: ShareFormat

    var body: some View {
        VStack(alignment: .leading, spacing: .space2XS) {
            HStack(alignment: .firstTextBaseline, spacing: .spaceS) {
                Text(verbatim: bar.label)
                    .font(.posterLabel)
                    .lineLimit(1)
                    .minimumScaleFactor(.shareTextShrink)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: .zero)
                ShareFigure(value: bar.value, size: .shareDataBarFigure)
                    .fixedSize()
            }
            GeometryReader { proxy in
                Capsule()
                    .fill(.white)
                    .frame(
                        width: proxy.size.width * ShareMotion.fill(bar.share, progress: progress)
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white.opacity(.opacityPosterTrack), in: .capsule)
            }
            .frame(height: .shareDataBar)
            .accessibilityHidden(true)
        }
    }
}

private struct ShareDataZone: View {
    @Environment(\.shareShowsArt) private var showsArt
    let content: ShareCardContent

    var body: some View {
        if showsArt, content.zoneContent == .none {
            content.accent
        } else {
            ShareZoneArt(content: content)
        }
    }
}

private struct ShareStatTile: View {
    let fact: SharePoster.Fact
    let size: CGFloat
    let width: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: .space2XS) {
            Spacer(minLength: .zero)
            ShareFigure(
                value: fact.value, size: min(size, width / CGFloat(max(fact.value.count, 1)))
            )
            .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: fact.label)
                .font(.posterLabel)
                .foregroundStyle(Color.posterSecondary)
                .lineLimit(2)
                .minimumScaleFactor(.shareTextShrink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.spaceS)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(.white.opacity(.opacityShareTile), in: .rect(cornerRadius: .radiusM))
    }
}

private struct ShareBoardCells: View {
    let cells: [SharePoster.Fact]
    let format: ShareFormat

    var body: some View {
        VStack(spacing: .spaceXS) {
            ForEach(Array(stride(from: 0, to: cells.count, by: 2)), id: \.self) { start in
                HStack(spacing: .spaceXS) {
                    ForEach(cells[start..<min(start + 2, cells.count)]) { cell in
                        ShareStatTile(
                            fact: cell, size: format.dataCell, width: format.safeWidth / 2)
                    }
                }
            }
        }
    }
}
