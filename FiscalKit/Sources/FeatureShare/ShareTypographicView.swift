import CoreGraphics
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public struct ShareStatement: Hashable, Sendable {
    public let eyebrow: String
    public let phrase: String?
    public let figure: String?
    public let caption: String?
    public let person: ShareFace?

    public init(_ content: ShareCardContent) {
        eyebrow = content.eyebrow
        switch content.body {
        case .person(let metrics):
            let lead = metrics.first { $0.value != PublicFormat.missing } ?? metrics.first
            phrase = nil
            figure = lead?.value ?? PublicFormat.missing
            caption = lead?.label
            person = content.faces.first
        case .vote(let tally):
            phrase = content.headline ?? tally.proposition
            figure = "\(tally.yes) × \(tally.no)"
            caption = [String(appLocalized: "Yes × No"), tally.result].compactMap(\.self)
                .joined(separator: " · ")
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
            phrase = content.faces.map(\.name).joined(separator: " x ")
            figure = row?.values.joined(separator: " × ") ?? PublicFormat.missing
            caption = row?.label
            person = nil
        case .representatives(let groups):
            phrase = content.headline
            figure = nil
            caption = groups.map { "\($0.count) \($0.title)" }.joined(separator: " · ")
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
        case .following(let faces):
            phrase = content.headline
            figure = nil
            caption = faces.map(\.name).joined(separator: ", ")
            person = nil
        }
    }

    public var texts: [String] {
        [eyebrow, phrase, figure, caption, person?.name, person?.party].compactMap(\.self)
    }
}

struct ShareTypographicView: View {
    let card: ShareCard
    let code: CGImage?

    var body: some View {
        let format = card.format
        let statement = card.statement
        let width = format.safeWidth
        VStack(alignment: .leading, spacing: format == .feed ? .spaceM : .spaceS) {
            Text(verbatim: statement.eyebrow)
                .font(.posterEyebrow)
                .tracking(.posterTracking)
                .foregroundStyle(Color.posterSecondary)
                .lineLimit(1)
                .minimumScaleFactor(.shareTextShrink)
            Capsule()
                .fill(Color.scoreboardAccent)
                .frame(width: .shareTypeRuleWidth, height: .shareTypeRule)
                .accessibilityHidden(true)
            Spacer(minLength: .zero)
            if let phrase = statement.phrase {
                let lines = statement.figure == nil ? 5 : 2
                Text(verbatim: phrase)
                    .font(.posterTitle(format.phraseSize(for: phrase, lines: lines)))
                    .lineLimit(lines)
                    .minimumScaleFactor(.posterShrink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let figure = statement.figure {
                ShareFigure(
                    value: figure,
                    size: format.figureSize(format.typeFigure, for: figure, in: width),
                    animates: true)
            }
            if let caption = statement.caption, !caption.isEmpty {
                Text(verbatim: caption)
                    .font(.posterHeadlineCompact)
                    .foregroundStyle(Color.posterSecondary)
                    .lineLimit(3)
                    .minimumScaleFactor(.shareTextShrink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let person = statement.person {
                ShareIdentity(name: person.name, party: person.party)
            }
            Spacer(minLength: .zero)
            ShareFooter(card: card, code: code)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(format.textInsets)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.shareTypeField)
    }
}
