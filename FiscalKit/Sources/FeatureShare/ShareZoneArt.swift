import FiscalDesignSystem
import SwiftUI

enum ShareZoneContent: Hashable {
    case faces([ShareFace])
    case shares([ShareSegment])
    case none
}

extension ShareCardContent {
    private static let zoneFaceLimit = 3

    var zoneContent: ShareZoneContent {
        switch body {
        case .vote(let tally):
            return .shares(tally.segments)
        case .race(let race):
            return .shares(
                race.candidates.map {
                    ShareSegment(share: $0.share, color: PartyPalette.of(party: $0.party).primary)
                })
        case .highlight(let highlight):
            if let tally = highlight.tally { return .shares(tally.segments) }
            return highlight.person.map { .faces([$0]) } ?? .none
        case .victory(let victory):
            return .faces([victory.winner] + (victory.runnerUp.map { [$0.face] } ?? []))
        case .representatives:
            return .none
        default:
            let shown = Array(faces.prefix(Self.zoneFaceLimit))
            return shown.isEmpty ? .none : .faces(shown)
        }
    }
}

extension ShareTally {
    var segments: [ShareSegment] {
        [
            ShareSegment(share: yesShare, color: .voteYes),
            ShareSegment(share: noShare, color: .voteNo),
            ShareSegment(share: othersShare, color: .voteAbstain),
        ]
    }
}

struct ShareZoneArt: View {
    let content: ShareCardContent

    var body: some View {
        ShareZoneFill(content: content)
            .environment(\.colorScheme, .light)
    }
}

private struct ShareZoneFill: View {
    @Environment(\.shareProgress) private var progress
    @Environment(\.shareShowsArt) private var showsArt
    let content: ShareCardContent

    var body: some View {
        if showsArt {
            switch content.zoneContent {
            case .faces(let faces):
                HStack(spacing: .zero) {
                    ForEach(Array(faces.enumerated()), id: \.offset) { index, face in
                        PartyStripes(palette: PartyPalette.of(party: face.party))
                            .scaleEffect(
                                y: ShareMotion.stage(index + 2, progress: progress),
                                anchor: .bottom)
                    }
                }
            case .shares(let segments):
                GeometryReader { proxy in
                    HStack(spacing: .zero) {
                        ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                            segment.color.frame(
                                width: proxy.size.width
                                    * ShareMotion.fill(segment.share, progress: progress))
                        }
                        Spacer(minLength: .zero)
                    }
                    .background(Color.shareDataField)
                }
            case .none:
                content.accent
                    .scaleEffect(y: ShareMotion.stage(2, progress: progress), anchor: .bottom)
            }
        } else {
            Color.clear
        }
    }
}

struct ShareBlockField: View {
    @Environment(\.shareProgress) private var progress
    @Environment(\.shareShowsArt) private var showsArt
    let color: Color
    var order: Int?

    var body: some View {
        if showsArt {
            color
                .environment(\.colorScheme, .light)
                .scaleEffect(
                    x: order.map { ShareMotion.stage($0, progress: progress) } ?? 1,
                    anchor: .leading)
        }
    }
}

extension ShareCardContent {
    func blockColor(party: String?) -> Color {
        guard let party else { return accent }
        return PartyPalette.of(party: party).primary.mix(with: .scoreboard, by: .shareBlockShade)
    }

    var leadColor: Color { blockColor(party: stageParties.onlySoleElement) }
}

extension Array where Element == String {
    fileprivate var onlySoleElement: String? {
        dropFirst().isEmpty ? first : nil
    }
}

struct ShareTile: View {
    enum Tone {
        case ink, lead, paper
    }

    let fact: SharePoster.Fact
    let tone: Tone
    let color: Color
    let leading: CGFloat
    let trailing: CGFloat
    var size: CGFloat = .shareStatSmall
    var order = 2

    var body: some View {
        VStack(alignment: .leading, spacing: .space2XS) {
            Spacer(minLength: .zero)
            ShareFigure(value: fact.value, size: size)
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: fact.label)
                .font(.posterLabel)
                .foregroundStyle(Color.posterSecondary)
                .lineLimit(2)
                .minimumScaleFactor(.shareTextShrink)
                .fixedSize(horizontal: false, vertical: true)
                .shareReveal(order + 1)
        }
        .foregroundStyle(Color.primary)
        .padding(.leading, leading)
        .padding(.trailing, trailing)
        .padding(.vertical, .spaceS)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background {
            switch tone {
            case .ink: ShareBlockField(color: .shareDataField, order: order)
            case .lead: ShareBlockField(color: color, order: order)
            case .paper: ShareBlockField(color: .retroCream, order: order)
            }
        }
        .environment(\.colorScheme, tone == .paper ? .light : .dark)
    }
}

struct ShareTileRows: View {
    let facts: [SharePoster.Fact]
    let color: Color
    let side: CGFloat
    var fills = false
    var tones: [ShareTile.Tone] = [.ink, .lead, .paper]
    private let perRow = 3

    var body: some View {
        VStack(spacing: .zero) {
            ForEach(Array(stride(from: 0, to: facts.count, by: perRow)), id: \.self) { start in
                let row = Array(facts[start..<Swift.min(start + perRow, facts.count)])
                HStack(spacing: .zero) {
                    ForEach(Array(row.enumerated()), id: \.element.id) { index, fact in
                        ShareTile(
                            fact: fact, tone: tones[(start + index) % tones.count], color: color,
                            leading: index == 0 ? side : .spaceS,
                            trailing: index == row.count - 1 ? side : .spaceS,
                            order: 3 + start + index)
                    }
                }
                .frame(minHeight: .shareTileHeight, maxHeight: fills ? .infinity : .shareTileHeight)
            }
        }
    }
}

struct ShareFooterBlock: View {
    let card: ShareCard
    let code: CGImage?
    var note: String?

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceXS) {
            if let note, !note.isEmpty {
                Text(verbatim: note)
                    .font(.posterLabel)
                    .foregroundStyle(Color.posterSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(.shareTextShrink)
            }
            ShareFooter(card: card, code: code)
        }
        .shareReveal(7)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, card.format.textInsets.leading)
        .padding(.vertical, .spaceS)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ShareBlockField(color: .shareDataField, order: 6)
        }
        .environment(\.colorScheme, .dark)
        .foregroundStyle(Color.primary)
    }
}

struct ShareHeaderBlock: View {
    let card: ShareCard
    let color: Color
    let title: String?
    let person: ShareFace?

    var body: some View {
        let insets = card.format.textInsets
        VStack(alignment: .leading, spacing: .space2XS) {
            Text(verbatim: card.content.eyebrow)
                .font(.posterEyebrow)
                .tracking(.posterTracking)
                .foregroundStyle(Color.posterSecondary)
                .lineLimit(1)
                .minimumScaleFactor(.shareTextShrink)
                .fixedSize(horizontal: false, vertical: true)
            if let person {
                Text(verbatim: person.name)
                    .font(.posterName)
                    .lineLimit(1)
                    .minimumScaleFactor(.shareTextShrink)
                    .fixedSize(horizontal: false, vertical: true)
                PartyMark(person.party)
                    .fixedSize()
            }
            if let title {
                Text(verbatim: title)
                    .font(.posterTitle(.shareFolhaHook))
                    .lineLimit(3)
                    .minimumScaleFactor(.posterShrink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .shareReveal(1)
        .foregroundStyle(Color.primary)
        .padding(.top, insets.top)
        .padding(.bottom, .spaceS)
        .padding(.horizontal, insets.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ShareBlockField(color: color, order: 0)
        }
        .environment(\.colorScheme, .dark)
    }
}
