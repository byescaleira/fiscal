import FiscalDesignSystem
import SwiftUI

struct ShareCardCarousel: View {
    @Environment(ShareModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: .spaceS) {
            GeometryReader { proxy in
                carousel(in: proxy.size)
            }
            ShareStyleNames()
        }
        .sensoryFeedback(.selection, trigger: model.style)
    }

    private func carousel(in space: CGSize) -> some View {
        let size = model.format.size
        let scale = min(space.height / size.height, space.width * .shareCarouselShare / size.width)
        let isStill = reduceMotion
        let selection = Binding<ShareStyle?>(
            get: { model.style },
            set: { style in
                if let style { model.style = style }
            })
        return ScrollView(.horizontal) {
            HStack(spacing: .spaceM) {
                ForEach(model.styles) { style in
                    ShareCarouselCard(style: style, scale: scale)
                        .scrollTransition(.interactive, axis: .horizontal) { card, phase in
                            card
                                .scaleEffect(
                                    phase.isIdentity || isStill ? 1 : .shareNeighborScale
                                )
                                .opacity(phase.isIdentity ? 1 : .opacityShareNeighbor)
                        }
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .contentMargins(.horizontal, (space.width - size.width * scale) / 2, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: selection, anchor: .top)
        .animation(reduceMotion ? nil : .smooth, value: model.format)
    }
}

private struct ShareCarouselCard: View {
    @Environment(ShareModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let style: ShareStyle
    let scale: CGFloat

    var body: some View {
        let size = model.format.size
        let selected = model.style == style
        let card = model.card(style: style)
        Button {
            withAnimation(reduceMotion ? nil : .smooth) { model.style = style }
        } label: {
            Group {
                if let card {
                    ShareCardView(card: card, code: model.code)
                        .portraitsStill()
                        .partyMarksStill()
                        .scaleEffect(scale, anchor: .topLeading)
                }
            }
            .frame(
                width: size.width * scale, height: size.height * scale, alignment: .topLeading
            )
            .clipShape(.rect(cornerRadius: .radiusL))
            .contentShape(.rect(cornerRadius: .radiusL))
            .overlay {
                RoundedRectangle(cornerRadius: .radiusL)
                    .strokeBorder(.separator)
            }
            .shadow(color: .black.opacity(.opacityShareCardShadow), radius: .spaceM, y: .spaceS)
        }
        .buttonStyle(.plain)
        .id(style)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(style.title))
        .accessibilityValue(Text(verbatim: selected ? card?.accessibilityLabel ?? "" : ""))
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

private struct ShareStyleNames: View {
    @Environment(ShareModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: .spaceL) {
            ForEach(model.styles) { style in
                let selected = model.style == style
                Button {
                    withAnimation(reduceMotion ? nil : .smooth) { model.style = style }
                } label: {
                    Text(style.title)
                        .font(.emphasis(.subheadline, weight: selected ? .bold : .regular))
                        .foregroundStyle(
                            selected ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary)
                        )
                        .lineLimit(1)
                        .fixedSize()
                }
                .buttonStyle(.plain)
                .accessibilityHidden(true)
            }
        }
    }
}
