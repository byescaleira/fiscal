import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public struct LensFaces: View {
    private let cards: [PersonCard]
    private let size: CGFloat

    public init(cards: [PersonCard], size: CGFloat = .badgeM) {
        self.cards = cards
        self.size = size
    }

    public var body: some View {
        HStack(spacing: -size / 3) {
            ForEach(cards) { card in
                PersonPortrait(slug: card.slug, name: card.name, party: card.party, size: size)
                    .overlay { Circle().strokeBorder(.white, lineWidth: .selectionStroke) }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: SupportedPeople.names(cards)))
    }
}
