import CoreGraphics
import FiscalDesignSystem
import FiscalResource
import SwiftUI

public struct ShareCardView: View {
    private let card: ShareCard
    private let code: CGImage?

    public init(card: ShareCard, code: CGImage?) {
        self.card = card
        self.code = card.showsCode ? code : nil
    }

    public var body: some View {
        let size = card.format.size
        Group {
            switch card.style {
            case .poster: standard
            case .typographic: ShareTypographicView(card: card, code: code)
            case .data: ShareDataView(card: card, code: code)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
        .dynamicTypeSize(.large)
    }

    private var standard: some View {
        let field = Color.posterField(card.artwork?.shade)
        let insets = card.format.safeInsets
        return VStack(spacing: .zero) {
            if card.format == .stories {
                ShareContent(card: card, code: code, field: field, top: insets.top)
                ShareArtBlock(artwork: card.artwork, field: field)
            } else {
                ShareArtBlock(artwork: card.artwork, field: field)
                ShareContent(card: card, code: code, field: field, top: .spaceM)
            }
        }
    }
}

extension Color {
    static func posterField(_ shade: String?) -> Color {
        guard let shade else { return .scoreboard }
        return Color.scoreboard.mix(with: Color(hex: shade), by: .opacityPosterTint)
    }

    static let posterSecondary = Color.primary.opacity(.opacityPosterSecondary)
}

private struct ShareArtBlock: View {
    @Environment(\.shareProgress) private var progress
    let artwork: ShareArtwork?
    let field: Color

    var body: some View {
        GeometryReader { proxy in
            if let artwork {
                artwork.work.image
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .scaleEffect(1 + (1 - ShareMotion.art(progress)) * .shareArtApproach)
                    .opacity(ShareMotion.stage(0, progress: progress))
                    .clipped()
            } else {
                field
            }
        }
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
    let top: CGFloat

    var body: some View {
        let format = card.format.textFormat
        VStack(alignment: .leading, spacing: .spaceS) {
            ShareLead(poster: card.poster, format: format)
            ShareFooter(card: card, code: code)
            if let artwork = card.artwork {
                ShareCredit(text: artwork.credit, lines: 2)
            }
        }
        .shareReveal(1)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, top)
        .padding(.bottom, .spaceM)
        .padding(.horizontal, format.margin)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(field)
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
                ShareFaceLine(face: person)
            }
        }
    }
}

struct ShareFooter: View {
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
