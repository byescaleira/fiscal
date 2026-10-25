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
        ZStack(alignment: .top) {
            ShareBackdrop(artwork: card.artwork, size: size)
            VStack(spacing: .zero) {
                ShareArtBand(
                    artwork: card.artwork, width: size.width,
                    height: size.height * card.format.artShare)
                Spacer(minLength: .zero)
                ShareDataBlock(card: card, code: code)
                    .padding(.spaceM)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .environment(\.colorScheme, .light)
        .fontDesign(.rounded)
        .dynamicTypeSize(.large)
    }
}

private struct ShareBackdrop: View {
    let artwork: ShareArtwork?
    let size: CGSize

    var body: some View {
        ZStack {
            Color.scoreboard
            if let artwork {
                artwork.work.image
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .blur(radius: .shareBlur)
                    .clipped()
            }
            LinearGradient(
                colors: [shade.opacity(.opacityTint), shade.opacity(.opacityShareShade)],
                startPoint: .top, endPoint: .bottom)
        }
        .frame(width: size.width, height: size.height)
    }

    private var shade: Color {
        artwork?.shade.map { Color(hex: $0) } ?? .scoreboard
    }
}

private struct ShareArtBand: View {
    let artwork: ShareArtwork?
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        ZStack(alignment: .top) {
            if let artwork {
                artwork.work.image
                    .resizable()
                    .aspectRatio(contentMode: artwork.work.isPublicDomain ? .fill : .fit)
                    .frame(width: width, height: height)
                    .clipped()
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .black, location: .zero),
                                .init(color: .black, location: .shareArtFade),
                                .init(color: .clear, location: 1),
                            ], startPoint: .top, endPoint: .bottom))
                Text(verbatim: artwork.credit)
                    .font(.shareCredit)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(.shareTextShrink)
                    .padding(.horizontal, .spaceM)
                    .padding(.vertical, .spaceXS)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.black.opacity(.opacityShareBand))
            }
        }
        .frame(width: width, height: height, alignment: .top)
    }
}

private struct ShareDataBlock: View {
    let card: ShareCard
    let code: CGImage?

    var body: some View {
        ViewThatFits(in: .vertical) {
            ShareBlockContent(card: card, code: code, dense: card.format.isCompact)
            ShareBlockContent(card: card, code: code, dense: true)
        }
        .padding(.spaceL)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            .white.opacity(.opacityShareBlock), in: .rect(cornerRadius: .shareRadius))
    }
}

private struct ShareBlockContent: View {
    let card: ShareCard
    let code: CGImage?
    let dense: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: dense ? .spaceS : .spaceM) {
            Text(verbatim: card.content.eyebrow)
                .font(.shareLabel)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(.shareTextShrink)
            if let headline = card.content.headline {
                Text(verbatim: headline)
                    .font(.shareTitle)
                    .lineLimit(dense ? 2 : 4)
                    .minimumScaleFactor(.shareTextShrink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if case .compare = card.content.body {
                EmptyView()
            } else if let face = card.content.faces.first {
                ShareFaceRow(face: face)
            }
            ShareBodyView(content: card.content, dense: dense)
            Divider()
            ShareFooter(card: card, code: dense ? nil : code)
        }
    }
}

private struct ShareFaceRow: View {
    let face: ShareFace

    var body: some View {
        HStack(spacing: .spaceM) {
            PersonPortrait(
                slug: face.slug, name: face.name, party: face.party, size: .sharePortrait)
            VStack(alignment: .leading, spacing: .space2XS) {
                Text(verbatim: face.name)
                    .font(.shareName)
                    .lineLimit(2)
                    .minimumScaleFactor(.shareTextShrink)
                HStack(spacing: .spaceXS) {
                    PartyMark(face.party)
                    Text(verbatim: face.detail)
                        .font(.shareBody)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(.shareTextShrink)
                }
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
                    .font(.shareBody)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(.shareTextShrink)
                Text(verbatim: card.content.stamp)
                    .font(.shareStamp)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(.shareTextShrink)
                HStack(alignment: .firstTextBaseline, spacing: .spaceXS) {
                    Text(verbatim: card.brand)
                        .font(.shareBrand)
                    Text(verbatim: ShareCardBuilder.host)
                        .font(.shareLabel)
                        .foregroundStyle(.secondary)
                    if let mark = card.portraitMark {
                        Text(verbatim: "· \(mark)")
                            .font(.shareLabel)
                            .foregroundStyle(.secondary)
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(.shareTextShrink)
            }
            Spacer(minLength: .zero)
            if let code, card.format.showsCode {
                Image(decorative: code, scale: 1)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: .shareCode, height: .shareCode)
            }
        }
    }
}
