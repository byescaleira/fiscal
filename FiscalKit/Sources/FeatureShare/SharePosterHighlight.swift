import FiscalDesignSystem
import SwiftUI

struct ShareHighlightHero: View {
    let highlight: ShareHighlight
    let format: ShareFormat

    var body: some View {
        let withTally = highlight.tally != nil
        VStack(alignment: .leading, spacing: .spaceM) {
            Text(verbatim: highlight.title)
                .font(
                    .posterTitle(format.statementSize(for: highlight.title, withTally: withTally))
                )
                .lineLimit(format.statementLines(withTally: withTally))
                .minimumScaleFactor(.posterShrink)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: .spaceXS) {
                if let person = highlight.person {
                    ShareIdentity(name: person.name, party: person.party)
                }
                if !highlight.place.isEmpty {
                    Text(verbatim: highlight.place)
                        .font(format == .message ? .posterLabel : .posterHeadlineCompact)
                        .foregroundStyle(Color.posterSecondary)
                        .lineLimit(2)
                        .minimumScaleFactor(.shareTextShrink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let tally = highlight.tally {
                ShareTallyHero(tally: tally, format: format, size: format.verdictSize)
            }
        }
    }
}
