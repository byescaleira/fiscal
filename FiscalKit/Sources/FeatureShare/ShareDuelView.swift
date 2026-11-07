import CoreGraphics
import FiscalDesignSystem
import SwiftUI

public struct ShareDuel: Hashable, Sendable {
    public struct Side: Hashable, Sendable {
        public let value: String
        public let name: String
        public let detail: String
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
            left = Side(value: lead.values[0], name: faces[0].name, detail: faces[0].party)
            right = Side(value: lead.values[1], name: faces[1].name, detail: faces[1].party)
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
            left = Side(value: first.percent, name: first.name, detail: first.party)
            right = Side(value: second.percent, name: second.name, detail: second.party)
            criterion = race.counted
            rows = []
            shares = [first.share, second.share]
        default:
            return nil
        }
    }
}

struct ShareDuelView: View {
    let card: ShareCard
    let duel: ShareDuel
    let code: CGImage?

    var body: some View {
        let format = card.format
        let insets = format.textInsets
        VStack(spacing: .zero) {
            HStack(spacing: .zero) {
                ShareDuelSide(
                    side: duel.left, format: format, longest: duel.longestValue,
                    color: card.content.blockColor(party: duel.left.detail),
                    leading: insets.leading, trailing: .spaceS, order: 0)
                ShareDuelSide(
                    side: duel.right, format: format, longest: duel.longestValue,
                    color: card.content.blockColor(party: duel.right.detail),
                    leading: .spaceS, trailing: insets.leading, order: 1)
            }
            VStack(spacing: .space2XS) {
                if let criterion = duel.criterion, !criterion.isEmpty {
                    Text(verbatim: criterion)
                        .font(.posterHeadlineCompact)
                        .lineLimit(1)
                        .minimumScaleFactor(.shareTextShrink)
                }
                ForEach(duel.rows.prefix(format.folhaRows)) { row in
                    ShareDuelRow(row: row)
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
            }
            .fixedSize(horizontal: false, vertical: true)
            .shareReveal(4)
            .padding(.horizontal, insets.leading)
            .padding(.vertical, .spaceS)
            .frame(maxWidth: .infinity)
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

extension ShareDuel {
    var longestValue: Int { max(left.value.count, right.value.count) }
}

private struct ShareDuelSide: View {
    let side: ShareDuel.Side
    let format: ShareFormat
    let longest: Int
    let color: Color
    let leading: CGFloat
    let trailing: CGFloat
    let order: Int

    var body: some View {
        let size = format.figureSize(
            .shareDuelFigure, for: String(repeating: "0", count: longest),
            in: (format.safeWidth - .spaceL * 2) / 2)
        VStack(alignment: .leading, spacing: .space2XS) {
            Spacer(minLength: .zero)
            Text(verbatim: side.name)
                .font(.posterName)
                .lineLimit(2)
                .minimumScaleFactor(.shareTextShrink)
                .fixedSize(horizontal: false, vertical: true)
            PartyMark(side.detail)
            ShareFigure(value: side.value, size: size)
                .fixedSize(horizontal: false, vertical: true)
        }
        .shareReveal(order + 1)
        .padding(.top, format.textInsets.top)
        .padding(.leading, leading)
        .padding(.trailing, trailing)
        .padding(.bottom, .spaceS)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background { ShareBlockField(color: color, order: order) }
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
