import FiscalDesignSystem
import SwiftUI

struct ShareSegment: Hashable {
    let share: Double
    let color: Color
}

struct ShareStackedBar: View {
    let segments: [ShareSegment]

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: .zero) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    Rectangle()
                        .fill(segment.color)
                        .frame(width: proxy.size.width * min(max(segment.share, 0), 1))
                }
                Spacer(minLength: .zero)
            }
            .background(.subtleFill)
            .clipShape(.capsule)
        }
        .frame(height: .shareBar)
        .accessibilityHidden(true)
    }
}

struct ShareRaceView: View {
    let race: ShareRace
    let dense: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            Text(verbatim: race.counted)
                .font(.shareLabel)
                .foregroundStyle(.secondary)
            ShareStackedBar(segments: [ShareSegment(share: race.countedShare, color: .secondary)])
            ForEach(race.candidates) { candidate in
                ShareCandidateRow(candidate: candidate, dense: dense)
            }
            Text(verbatim: race.footnote)
                .font(.shareLabel)
                .foregroundStyle(.secondary)
        }
    }
}

private struct ShareCandidateRow: View {
    let candidate: ShareRace.Candidate
    let dense: Bool

    var body: some View {
        let palette = PartyPalette.of(party: candidate.party)
        HStack(spacing: .spaceS) {
            Rectangle()
                .fill(palette.primary)
                .frame(width: .shareStripe)
            VStack(alignment: .leading, spacing: .space2XS) {
                Text(verbatim: candidate.name)
                    .font(dense ? .shareBody.weight(.bold) : .shareName)
                    .lineLimit(1)
                    .minimumScaleFactor(.shareTextShrink)
                HStack(spacing: .spaceXS) {
                    PartyMark(candidate.party)
                    Text(verbatim: candidate.votes)
                        .font(.shareLabel)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    if candidate.elected {
                        Label("Elected", systemImage: "checkmark.seal.fill")
                            .font(.shareLabel)
                            .foregroundStyle(.positive)
                    }
                }
            }
            Spacer(minLength: .spaceS)
            Text(verbatim: candidate.percent)
                .font(dense ? .shareName : .shareNumber)
                .monospacedDigit()
                .padding(.trailing, .spaceS)
        }
        .padding(.vertical, dense ? .zero : .space2XS)
        .background(alignment: .leading) {
            GeometryReader { proxy in
                Rectangle()
                    .fill(palette.primary.opacity(.opacityTint))
                    .frame(width: proxy.size.width * candidate.share)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct ShareCompareView: View {
    let faces: [ShareFace]
    let rows: [ShareCompareRow]
    let dense: Bool

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: .spaceS, verticalSpacing: .spaceS) {
            GridRow {
                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                ForEach(faces) { face in
                    VStack(spacing: .space2XS) {
                        PersonPortrait(
                            slug: face.slug, name: face.name, party: face.party,
                            size: dense ? .sharePortraitSmall : .sharePortrait)
                        Text(verbatim: face.name)
                            .font(.shareBody.weight(.bold))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(.shareTextShrink)
                        PartyMark(face.party)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            ForEach(rows) { row in
                Divider()
                GridRow {
                    Text(verbatim: row.label)
                        .font(.shareLabel)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    ForEach(Array(row.values.enumerated()), id: \.offset) { _, value in
                        Text(verbatim: value)
                            .font(dense ? .shareBody.weight(.bold) : .shareName)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(.shareTextShrink)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
}

struct ShareGroupsView: View {
    let groups: [ShareGroup]
    let dense: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: dense ? .space2XS : .spaceS) {
            ForEach(groups) { group in
                HStack(alignment: .firstTextBaseline, spacing: .spaceS) {
                    VStack(alignment: .leading, spacing: .zero) {
                        Text(verbatim: group.title)
                            .font(dense ? .shareBody.weight(.bold) : .shareName)
                            .lineLimit(1)
                            .minimumScaleFactor(.shareTextShrink)
                        if !group.names.isEmpty {
                            Text(verbatim: group.names.joined(separator: ", "))
                                .font(.shareBody)
                                .foregroundStyle(.secondary)
                                .lineLimit(dense ? 1 : 2)
                                .minimumScaleFactor(.shareTextShrink)
                        }
                    }
                    Spacer(minLength: .spaceS)
                    Text(verbatim: group.count)
                        .font(dense ? .shareName : .shareNumber)
                        .monospacedDigit()
                }
            }
        }
    }
}
