import CoreGraphics
import FiscalDesignSystem
import FiscalResource
import SwiftUI

public struct ShareCardView: View {
    private let card: ShareCard
    private let code: CGImage?

    public init(card: ShareCard, code: CGImage?) {
        self.card = card
        self.code = code
    }

    public var body: some View {
        let size = card.format.size
        Group {
            if let victory = card.victory {
                ShareVictoryPoster(card: card, victory: victory, code: code)
            } else {
                standard
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
        .dynamicTypeSize(.large)
    }

    private var standard: some View {
        let size = card.format.size
        let field = Color.posterField(card.artwork?.shade)
        return ZStack(alignment: .top) {
            LinearGradient(
                colors: [field.mix(with: .white, by: .opacityPosterGlow), field],
                startPoint: .top, endPoint: .bottom)
            if let artwork = card.artwork, artwork.isBackdrop {
                ShareBackdrop(artwork: artwork, size: size)
            }
            VStack(alignment: .leading, spacing: .zero) {
                ShareArtHeader(artwork: card.artwork, format: card.format, field: field)
                    .layoutPriority(1)
                if card.artwork?.isBackdrop == true {
                    Spacer(minLength: .spaceM)
                    ShareContent(card: card, code: code, field: field)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(2)
                } else {
                    ShareLead(poster: card.poster, format: card.format)
                        .padding([.top, .horizontal], card.format.margin)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(2)
                    Spacer(minLength: .spaceM)
                    ShareFooter(card: card, code: code)
                        .padding([.bottom, .horizontal], card.format.margin)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(2)
                }
            }
        }
    }
}

extension Color {
    static func posterField(_ shade: String?) -> Color {
        guard let shade else { return .scoreboard }
        return Color.scoreboard.mix(with: Color(hex: shade), by: .opacityPosterTint)
    }

    static let posterSecondary = Color.white.opacity(.opacityPosterSecondary)
}

private struct ShareBackdrop: View {
    let artwork: ShareArtwork
    let size: CGSize

    var body: some View {
        artwork.work.image
            .resizable()
            .scaledToFill()
            .frame(width: size.width, height: size.height)
            .clipped()
            .accessibilityHidden(true)
    }
}

private struct ShareArtHeader: View {
    let artwork: ShareArtwork?
    let format: ShareFormat
    let field: Color

    var body: some View {
        if let artwork {
            if artwork.isBackdrop {
                ShareCredit(text: artwork.credit, lines: 3)
                    .padding(.horizontal, .spaceS)
                    .padding(.vertical, .space2XS)
                    .background(
                        field.opacity(.opacityPosterLabel), in: .rect(cornerRadius: .radiusS)
                    )
                    .padding(format.margin)
            } else if format.plateSpansWidth {
                VStack(alignment: .leading, spacing: .spaceS) {
                    SharePlate(artwork: artwork)
                    ShareCredit(text: artwork.credit, lines: 3)
                }
                .padding([.top, .horizontal], format.margin)
            } else {
                HStack(alignment: .top, spacing: .spaceM) {
                    ShareCredit(text: artwork.credit, lines: 7)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    SharePlate(artwork: artwork)
                        .frame(width: format.plateWidth)
                }
                .padding([.top, .horizontal], format.margin)
            }
        }
    }
}

private struct SharePlate: View {
    let artwork: ShareArtwork

    var body: some View {
        artwork.work.image
            .resizable()
            .aspectRatio(contentMode: .fit)
            .accessibilityHidden(true)
    }
}

private struct ShareCredit: View {
    let text: String
    let lines: Int

    var body: some View {
        Text(verbatim: text)
            .font(.posterCredit)
            .foregroundStyle(Color.posterSecondary)
            .lineLimit(lines)
            .minimumScaleFactor(.shareTextShrink)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct ShareContent: View {
    let card: ShareCard
    let code: CGImage?
    let field: Color

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceL) {
            ShareLead(poster: card.poster, format: card.format)
            ShareFooter(card: card, code: code)
        }
        .padding(card.format.margin)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .bottom) {
            if card.artwork?.isBackdrop == true {
                ShareScrim(field: field)
            }
        }
    }
}

private struct ShareScrim: View {
    let field: Color

    var body: some View {
        VStack(spacing: .zero) {
            LinearGradient(
                colors: [field.opacity(.zero), field.opacity(.opacityPosterScrim)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: .posterFade)
            field.opacity(.opacityPosterScrim)
        }
        .padding(.top, -.posterFade)
    }
}

private struct ShareLead: View {
    let poster: SharePoster
    let format: ShareFormat

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            Text(verbatim: poster.eyebrow)
                .font(.posterEyebrow)
                .tracking(.posterTracking)
                .foregroundStyle(Color.posterSecondary)
                .lineLimit(1)
                .minimumScaleFactor(.shareTextShrink)
            if let headline = poster.headline {
                Text(verbatim: headline)
                    .font(format == .message ? .posterHeadlineCompact : .posterHeadline)
                    .lineLimit(format.headlineLines)
                    .minimumScaleFactor(.shareTextShrink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ShareHero(hero: poster.hero, format: format)
            if !poster.facts.isEmpty, format.showsFacts || poster.factsAreEssential {
                ShareFacts(facts: poster.facts, size: format.factSize)
            }
            if let note = poster.note, format.showsNote || poster.noteIsEssential {
                Text(verbatim: note)
                    .font(.posterLabel)
                    .foregroundStyle(Color.posterSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(.shareTextShrink)
            }
            if let person = poster.person {
                ShareIdentity(name: person.name, party: person.party)
            }
        }
    }
}

private struct ShareFooter: View {
    let card: ShareCard
    let code: CGImage?

    var body: some View {
        HStack(alignment: .bottom, spacing: .spaceM) {
            VStack(alignment: .leading, spacing: .space2XS) {
                Text(verbatim: card.content.source)
                    .font(.posterSource)
                    .foregroundStyle(Color.posterSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(.shareTextShrink)
                HStack(alignment: .firstTextBaseline, spacing: .spaceXS) {
                    Text(verbatim: card.brand)
                        .font(.posterBrand)
                    Text(verbatim: ShareCardBuilder.host)
                        .font(.posterHost)
                        .foregroundStyle(Color.posterSecondary)
                }
                .lineLimit(1)
            }
            Spacer(minLength: .zero)
            if let code, card.format.showsCode {
                Image(decorative: code, scale: 1)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: .posterCode, height: .posterCode)
                    .padding(.posterCodeInset)
                    .background(.white, in: .rect(cornerRadius: .space2XS))
            }
        }
    }
}
