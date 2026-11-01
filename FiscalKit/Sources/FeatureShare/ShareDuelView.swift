import CoreGraphics
import FiscalDesignSystem
import SwiftUI

public struct ShareDuel: Hashable, Sendable {
    public struct Side: Hashable, Sendable {
        public let value: String
        public let name: String
        public let detail: String
        public let slug: String?
    }

    public struct Row: Hashable, Sendable, Identifiable {
        public let label: String
        public let left: String
        public let right: String

        public var id: String { label }
    }

    public let eyebrow: String
    public let hook: String?
    public let left: Side
    public let right: Side
    public let criterion: String?
    public let rows: [Row]
    public let shares: [Double]

    public init?(_ content: ShareCardContent) {
        eyebrow = content.eyebrow
        switch content.body {
        case .compare(let rows):
            let compared = rows.filter { $0.values.count >= 2 }
            guard content.faces.count >= 2, let lead = compared.first else { return nil }
            let faces = content.faces
            hook = nil
            left = Side(
                value: lead.values[0], name: faces[0].name, detail: faces[0].party,
                slug: faces[0].slug)
            right = Side(
                value: lead.values[1], name: faces[1].name, detail: faces[1].party,
                slug: faces[1].slug)
            criterion = lead.label
            self.rows = compared.dropFirst().map {
                Row(label: $0.label, left: $0.values[0], right: $0.values[1])
            }
            shares = []
        case .race(let race):
            guard race.candidates.count == 2 else { return nil }
            let first = race.candidates[0]
            let second = race.candidates[1]
            hook = content.headline
            left = Side(value: first.percent, name: first.name, detail: first.party, slug: nil)
            right = Side(
                value: second.percent, name: second.name, detail: second.party, slug: nil)
            criterion = race.counted
            rows = []
            shares = [first.share, second.share]
        default:
            return nil
        }
    }
}

struct ShareDuelView: View {
    @Environment(\.shareProgress) private var progress
    @Environment(\.shareShowsArt) private var showsArt
    let card: ShareCard
    let duel: ShareDuel
    let code: CGImage?

    var body: some View {
        let format = card.format
        ZStack(alignment: .bottom) {
            ShareStageField(parties: [duel.left.detail, duel.right.detail])
            if showsArt, format == .stories {
                Text(verbatim: "×")
                    .font(.posterFigure(.shareDuelMark))
                    .foregroundStyle(.white.opacity(.opacityDuelMark))
                    .fixedSize()
                    .scaleEffect(
                        .shareNeighborScale + (1 - .shareNeighborScale)
                            * ShareMotion.eased(progress)
                    )
                    .offset(y: .shareDuelMarkDrop)
                    .accessibilityHidden(true)
            }
            VStack(spacing: .spaceXS) {
                Text(verbatim: duel.eyebrow)
                    .font(.posterEyebrow)
                    .tracking(.posterTracking)
                    .foregroundStyle(Color.posterSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(.shareTextShrink)
                    .fixedSize(horizontal: false, vertical: true)
                if let hook = duel.hook {
                    Text(verbatim: hook)
                        .font(.posterTitle(.shareFolhaHook))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(.posterShrink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: .zero)
                ShareDuelSides(duel: duel, format: format)
                    .fixedSize(horizontal: false, vertical: true)
                if let criterion = duel.criterion, !criterion.isEmpty {
                    Text(verbatim: criterion)
                        .font(.posterHeadlineCompact)
                        .lineLimit(1)
                        .minimumScaleFactor(.shareTextShrink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                VStack(spacing: .space2XS) {
                    ForEach(duel.rows.prefix(format.folhaRows)) { row in
                        ShareDuelRow(row: row)
                    }
                }
                if duel.shares.count == 2 {
                    ShareTallyBar(
                        segments: [
                            ShareSegment(share: duel.shares[0], color: .white),
                            ShareSegment(
                                share: duel.shares[1],
                                color: .white.opacity(.opacityPosterSecondary)),
                        ], animates: true)
                }
                Spacer(minLength: .zero)
                ShareFooter(card: card, code: code)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(format.textInsets)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

private struct ShareDuelSides: View {
    let duel: ShareDuel
    let format: ShareFormat

    var body: some View {
        let longest = max(duel.left.value.count, duel.right.value.count)
        let value = String(repeating: "0", count: longest)
        let size = format.figureSize(
            .shareDuelFigure, for: value, in: (format.safeWidth - .spaceL * 2) / 2)
        HStack(alignment: .top, spacing: .zero) {
            ShareDuelSide(side: duel.left, size: size)
                .padding(.trailing, .spaceS)
            ShareDuelSide(side: duel.right, size: size)
                .padding(.leading, .spaceS)
        }
    }
}

private struct ShareDuelSide: View {
    let side: ShareDuel.Side
    let size: CGFloat

    var body: some View {
        VStack(spacing: .space2XS) {
            if let slug = side.slug {
                PersonPortrait(
                    slug: slug, name: side.name, party: side.detail, size: .shareDuelPortrait)
            }
            Text(verbatim: side.name)
                .font(.posterName)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(.shareTextShrink)
            PartyMark(side.detail)
            ShareFigure(value: side.value, size: size)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ShareDuelRow: View {
    let row: ShareDuel.Row

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: .space2XS) {
            Text(verbatim: row.left)
                .font(.posterHeadlineCompact)
                .frame(maxWidth: .infinity)
            Text(verbatim: row.label)
                .font(.posterSource)
                .foregroundStyle(Color.posterSecondary)
                .lineLimit(1)
                .minimumScaleFactor(.shareTextShrink)
                .frame(width: .shareDuelLabel)
            Text(verbatim: row.right)
                .font(.posterHeadlineCompact)
                .frame(maxWidth: .infinity)
        }
        .lineLimit(1)
        .minimumScaleFactor(.shareTextShrink)
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct ShareStageField: View {
    @Environment(\.shareShowsArt) private var showsArt
    let parties: [String]

    var body: some View {
        if showsArt, !parties.isEmpty {
            HStack(spacing: .zero) {
                ForEach(Array(parties.enumerated()), id: \.offset) { _, party in
                    PartyBackdrop(party: party)
                }
            }
        } else {
            Color.shareDataField
        }
    }
}
