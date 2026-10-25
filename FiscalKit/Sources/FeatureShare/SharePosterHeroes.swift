import FiscalDesignSystem
import SwiftUI

struct ShareHero: View {
    let hero: SharePoster.Hero
    let format: ShareFormat

    var body: some View {
        switch hero {
        case .figure(let value, let caption):
            VStack(alignment: .leading, spacing: .zero) {
                ShareFigure(value: value, size: format.figureSize(format.heroSize, for: value))
                Text(verbatim: caption)
                    .font(.posterHeadlineCompact)
                    .foregroundStyle(Color.posterSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(.shareTextShrink)
            }
        case .place(let name):
            Text(verbatim: name)
                .font(.posterTitle(format.titleSize))
                .lineLimit(2)
                .minimumScaleFactor(.posterShrink)
        case .tally(let tally):
            ShareTallyHero(tally: tally, format: format)
        case .race(let race):
            ShareRaceHero(race: race, format: format)
        case .versus(let faces, let rows):
            ShareVersusHero(faces: faces, rows: rows, format: format)
        }
    }
}

struct ShareFigure: View {
    let value: String
    let size: CGFloat

    var body: some View {
        Text(verbatim: value)
            .font(.posterFigure(size))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(.posterShrink)
    }
}

private struct ShareTallyHero: View {
    let tally: ShareTally
    let format: ShareFormat

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            HStack(alignment: .lastTextBaseline, spacing: .spaceL) {
                ShareCount(
                    value: tally.yes, label: "YES", symbol: "checkmark", color: .voteYes,
                    size: format.scoreSize
                )
                .frame(width: format.column, alignment: .leading)
                ShareCount(
                    value: tally.no, label: "NO", symbol: "xmark", color: .voteNo,
                    size: format.scoreSize
                )
                .frame(width: format.column, alignment: .leading)
            }
            ShareTallyBar(segments: [
                ShareSegment(share: tally.yesShare, color: .voteYes),
                ShareSegment(share: tally.noShare, color: .voteNo),
                ShareSegment(share: tally.othersShare, color: .voteAbstain),
            ])
            HStack(alignment: .firstTextBaseline, spacing: .spaceM) {
                if let result = tally.result {
                    HStack(spacing: .spaceXS) {
                        Image(systemName: resultSymbol)
                        Text(verbatim: result)
                    }
                    .font(.posterHeadline)
                    .foregroundStyle(resultColor)
                }
                Spacer(minLength: .zero)
                HStack(alignment: .firstTextBaseline, spacing: .spaceXS) {
                    Text(verbatim: tally.others)
                        .font(.posterFigure(format.factSize))
                        .monospacedDigit()
                    Text("OTHERS")
                        .font(.posterParty)
                        .tracking(.posterTracking)
                }
                .foregroundStyle(Color.voteAbstain)
            }
        }
    }

    private var resultSymbol: String {
        switch tally.approved {
        case .some(true): "checkmark.seal.fill"
        case .some(false): "xmark.seal.fill"
        case .none: "info.circle.fill"
        }
    }

    private var resultColor: Color {
        switch tally.approved {
        case .some(true): .voteYes
        case .some(false): .voteNo
        case .none: .posterSecondary
        }
    }
}

private struct ShareCount: View {
    let value: String
    let label: LocalizedStringKey
    let symbol: String
    let color: Color
    let size: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: .zero) {
            HStack(spacing: .space2XS) {
                Image(systemName: symbol)
                Text(label)
            }
            .font(.posterParty)
            .tracking(.posterTracking)
            .foregroundStyle(color)
            ShareFigure(value: value, size: size)
        }
    }
}

struct ShareSegment: Hashable {
    let share: Double
    let color: Color
}

struct ShareTallyBar: View {
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
            .background(.white.opacity(.opacityPosterTrack))
            .clipShape(.capsule)
        }
        .frame(height: .posterBar)
        .accessibilityHidden(true)
    }
}

private struct ShareRaceHero: View {
    let race: ShareRace
    let format: ShareFormat

    var body: some View {
        if race.candidates.count == 2 {
            HStack(alignment: .top, spacing: .spaceL) {
                ForEach(race.candidates) { candidate in
                    VStack(alignment: .leading, spacing: .spaceXS) {
                        ShareFigure(
                            value: candidate.percent,
                            size: format.figureSize(
                                format.scoreSize, for: candidate.percent, in: format.column))
                        ShareIdentity(name: candidate.name, party: candidate.party)
                        if candidate.elected {
                            ShareElected()
                        }
                    }
                    .frame(width: format.column, alignment: .leading)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: .spaceS) {
                ForEach(race.candidates) { candidate in
                    HStack(alignment: .center, spacing: .spaceM) {
                        ShareIdentity(name: candidate.name, party: candidate.party)
                        if candidate.elected {
                            ShareElected()
                        }
                        Spacer(minLength: .spaceS)
                        ShareFigure(value: candidate.percent, size: format.rowSize)
                            .fixedSize()
                    }
                }
            }
        }
    }
}

private struct ShareElected: View {
    var body: some View {
        HStack(spacing: .space2XS) {
            Image(systemName: "checkmark.seal.fill")
            Text("Elected")
        }
        .font(.posterParty)
        .foregroundStyle(Color.voteYes)
    }
}

private struct ShareVersusHero: View {
    let faces: [ShareFace]
    let rows: [ShareCompareRow]
    let format: ShareFormat

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceM) {
            HStack(alignment: .top, spacing: .spaceL) {
                ForEach(faces) { face in
                    ShareIdentity(name: face.name, party: face.party)
                        .frame(width: format.column, alignment: .leading)
                }
            }
            ForEach(rows.prefix(format.compareRows)) { row in
                VStack(alignment: .leading, spacing: .zero) {
                    Text(verbatim: row.label.uppercased())
                        .font(.posterEyebrow)
                        .tracking(.posterTracking)
                        .foregroundStyle(Color.posterSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(.shareTextShrink)
                    HStack(alignment: .firstTextBaseline, spacing: .spaceL) {
                        ForEach(Array(row.values.prefix(2).enumerated()), id: \.offset) {
                            _, value in
                            ShareFigure(value: value, size: format.rowSize)
                                .frame(width: format.column, alignment: .leading)
                        }
                    }
                }
            }
        }
    }
}

struct ShareFacts: View {
    let facts: [SharePoster.Fact]
    let size: CGFloat

    var body: some View {
        Grid(alignment: .topLeading, horizontalSpacing: .spaceL, verticalSpacing: .spaceS) {
            ForEach(Array(stride(from: 0, to: facts.count, by: 3)), id: \.self) { start in
                GridRow {
                    ForEach(facts[start..<min(start + 3, facts.count)]) { fact in
                        VStack(alignment: .leading, spacing: .zero) {
                            Text(verbatim: fact.value)
                                .font(.posterFigure(size))
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(.posterShrink)
                            Text(verbatim: fact.label)
                                .font(.posterLabel)
                                .foregroundStyle(Color.posterSecondary)
                                .lineLimit(2)
                                .minimumScaleFactor(.shareTextShrink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }
}

struct ShareIdentity: View {
    let name: String
    let party: String

    var body: some View {
        HStack(spacing: .spaceS) {
            SharePartyStripes(party: party)
            VStack(alignment: .leading, spacing: .zero) {
                Text(verbatim: name)
                    .font(.posterName)
                    .lineLimit(2)
                    .minimumScaleFactor(.shareTextShrink)
                Text(verbatim: party.uppercased())
                    .font(.posterParty)
                    .tracking(.posterTracking)
                    .foregroundStyle(Color.posterSecondary)
                    .lineLimit(1)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct SharePartyStripes: View {
    let party: String

    var body: some View {
        let palette = PartyPalette.of(party: party)
        HStack(spacing: .spaceHairline) {
            Rectangle().fill(palette.primary)
            Rectangle().fill(palette.secondary)
        }
        .frame(width: .posterStripe * 2 + .spaceHairline)
        .accessibilityHidden(true)
    }
}
