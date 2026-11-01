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

    private static let ghostLimit = 7

    public var ghost: String? {
        figure.flatMap { $0.count <= Self.ghostLimit ? $0 : nil }
    }

    public init(_ content: ShareCardContent) {
        eyebrow = content.eyebrow
        rows = Self.rows(of: content)
        if case .following(let faces) = content.body { people = faces } else { people = [] }
        switch content.body {
        case .person(let metrics):
            let lead = metrics.first { $0.value != PublicFormat.missing } ?? metrics.first
            phrase = nil
            figure = lead?.value ?? PublicFormat.missing
            caption = lead?.label
            person = content.faces.first
        case .vote(let tally):
            phrase = Self.hook(of: tally) ?? content.headline
            figure = "\(tally.yes) × \(tally.no)"
            caption = String(appLocalized: "Yes × No")
            person = nil
        case .expenses(let spending):
            phrase = nil
            figure = spending.total
            caption = spending.caption
            person = content.faces.first
        case .race(let race):
            let leader = race.candidates.first
            phrase = content.headline
            figure = leader?.percent ?? PublicFormat.missing
            caption = leader.map { "\($0.name) · \($0.party)" }
            person = nil
        case .victory(let victory):
            phrase = nil
            figure = victory.percent
            caption = victory.statement
            person = victory.winner
        case .compare(let rows):
            let row = rows.first
            phrase =
                content.faces.count == 2
                ? String(appLocalized: "\(content.faces[0].name) and \(content.faces[1].name)")
                : content.faces.map(\.name).joined(separator: ", ")
            figure = row?.values.joined(separator: " × ") ?? PublicFormat.missing
            caption = row?.label
            person = nil
        case .representatives:
            phrase = content.headline
            figure = nil
            caption = nil
            person = nil
        case .highlight(let highlight):
            phrase = highlight.title
            figure = nil
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
        }
    }

    private static func hook(of tally: ShareTally) -> String? {
        let name = tally.proposition.components(separatedBy: " · ").first ?? tally.proposition
        guard !name.isEmpty else { return nil }
        return tally.result.map { "\(name): \($0)" } ?? name
    }

    private static func rows(of content: ShareCardContent) -> [Row] {
        switch content.body {
        case .person(let metrics):
            let lead = metrics.first { $0.value != PublicFormat.missing } ?? metrics.first
            return metrics.filter { $0 != lead }.map { Row(label: $0.label, value: $0.value) }
        case .vote(let tally):
            return [Row(label: String(appLocalized: "Others"), value: tally.others)]
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
        case .investigation(let investigation):
            return investigation.numbers.dropFirst().map { Row(label: $0.label, value: $0.value) }
        case .highlight, .victory, .following:
            return []
        }
    }

    public var texts: [String] {
        [eyebrow, phrase, figure, caption, person?.name, person?.party].compactMap(\.self)
            + rows.flatMap { [$0.label, $0.value] }
            + people.flatMap { [$0.name, $0.party, $0.detail] }
    }
}

extension ShareCardContent {
    var accent: Color {
        switch body {
        case .vote, .highlight: .retroTeal
        case .person, .representatives: .retroDenim
        case .expenses: .retroMustard
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
        ZStack(alignment: .bottom) {
            Color.sharePaper
            ShareFolhaBand(
                figure: format == .stories ? statement.ghost : nil, color: card.content.accent,
                height: format.folhaBand)
            ShareFolhaText(card: card, statement: statement, code: code)
                .padding(format.folhaInsets)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .foregroundStyle(Color.primary)
        .environment(\.colorScheme, .light)
    }
}

private struct ShareFolhaBand: View {
    @Environment(\.shareProgress) private var progress
    @Environment(\.shareShowsArt) private var showsArt
    let figure: String?
    let color: Color
    let height: CGFloat

    var body: some View {
        color
            .overlay {
                if let figure, showsArt {
                    Text(verbatim: figure)
                        .font(.posterFigure(.shareFolhaGhost))
                        .foregroundStyle(.white.opacity(.opacityFolhaGhost))
                        .lineLimit(1)
                        .fixedSize()
                        .offset(
                            x: (1 - ShareMotion.eased(progress)) * .shareFolhaDrift,
                            y: .shareFolhaGhostDrop)
                }
            }
            .frame(height: height)
            .clipped()
            .accessibilityHidden(true)
    }
}

private struct ShareFolhaText: View {
    let card: ShareCard
    let statement: ShareStatement
    let code: CGImage?

    var body: some View {
        let format = card.format
        VStack(alignment: .leading, spacing: .spaceS) {
            Text(verbatim: statement.eyebrow)
                .font(.posterEyebrow)
                .tracking(.posterTracking)
                .foregroundStyle(card.content.accent)
                .lineLimit(1)
                .minimumScaleFactor(.shareTextShrink)
            if let person = statement.person {
                ShareIdentity(name: person.name, party: person.party)
            }
            if let phrase = statement.phrase {
                let lines = statement.figure == nil ? 5 : 3
                Text(verbatim: phrase)
                    .font(
                        .posterTitle(
                            statement.figure == nil
                                ? format.phraseSize(for: phrase, lines: lines) : .shareFolhaHook)
                    )
                    .lineLimit(lines)
                    .minimumScaleFactor(.posterShrink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: .zero)
            if let figure = statement.figure {
                ShareFigure(
                    value: figure,
                    size: format.figureSize(format.typeFigure, for: figure, in: format.safeWidth))
            }
            if let caption = statement.caption, !caption.isEmpty {
                Text(verbatim: caption)
                    .font(.posterHeadlineCompact)
                    .foregroundStyle(Color.posterSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(.shareTextShrink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ShareFolhaRule()
            let limit = statement.figure == nil ? format.folhaRowsWithoutFigure : format.folhaRows
            ForEach(statement.rows.prefix(limit)) { row in
                ShareFolhaRow(row: row)
            }
            ForEach(statement.people) { face in
                ShareFolhaPerson(face: face)
            }
            ShareFooter(card: card, code: code)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ShareFolhaRule: View {
    @Environment(\.shareProgress) private var progress

    var body: some View {
        GeometryReader { proxy in
            Rectangle()
                .fill(Color.primary)
                .frame(width: proxy.size.width * ShareMotion.eased(progress))
        }
        .frame(height: .shareFolhaRule)
        .accessibilityHidden(true)
    }
}

private struct ShareFolhaRow: View {
    let row: ShareStatement.Row

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: .spaceS) {
            Text(verbatim: row.label)
                .font(.posterLabel)
                .lineLimit(1)
                .minimumScaleFactor(.shareTextShrink)
            Spacer(minLength: .zero)
            Text(verbatim: row.value)
                .font(.posterHeadlineCompact)
                .lineLimit(1)
                .fixedSize()
        }
    }
}

private struct ShareFolhaPerson: View {
    let face: ShareFace

    var body: some View {
        HStack(spacing: .spaceS) {
            SharePartyStripes(party: face.party)
            Text(verbatim: face.name)
                .font(.posterHeadlineCompact)
                .lineLimit(1)
                .minimumScaleFactor(.shareTextShrink)
            Spacer(minLength: .zero)
            Text(verbatim: [face.party, face.detail].joined(separator: " · "))
                .font(.posterLabel)
                .foregroundStyle(Color.posterSecondary)
                .lineLimit(1)
                .minimumScaleFactor(.shareTextShrink)
        }
    }
}
