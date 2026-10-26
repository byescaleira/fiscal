import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public struct LensFaces: View {
    private let cards: [PersonCard]
    private let size: CGFloat
    private let expression: PortraitExpression?

    public init(
        cards: [PersonCard], size: CGFloat = .badgeM, expression: PortraitExpression? = nil
    ) {
        self.cards = cards
        self.size = size
        self.expression = expression
    }

    public var body: some View {
        HStack(spacing: -size / 3) {
            ForEach(cards) { card in
                PersonPortrait(
                    slug: card.slug, name: card.name, party: card.party, size: size,
                    expression: expression
                )
                .overlay { Circle().strokeBorder(.white, lineWidth: .selectionStroke) }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: SupportedPeople.names(cards)))
    }
}
