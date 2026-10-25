import FiscalDesignSystem
import FiscalResource
import SwiftUI

struct ArtPoster: View {
    let work: ArtWork
    var width: CGFloat? = .posterWidth
    var height: CGFloat = .posterHeight
    var showsCredit = true

    var body: some View {
        Color.clear
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil)
            .overlay { work.image.resizable().scaledToFill() }
            .overlay(alignment: .bottom) {
                if showsCredit { ArtCredit(work: work) }
            }
            .clipShape(.rect(cornerRadius: .radiusL))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(work.accessibilityCredit)
    }
}

struct ArtCredit: View {
    let work: ArtWork

    var body: some View {
        VStack(alignment: .leading, spacing: .space2XS) {
            Text(verbatim: work.artist).font(.caption.weight(.bold))
            Text(verbatim: work.caption).font(.caption2).lineLimit(2)
            Label(work.licenseTitle, systemImage: "checkmark.seal")
                .font(.caption2.weight(.semibold))
                .labelStyle(.titleAndIcon)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.spaceM)
        .padding(.top, .spaceXL)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(.opacityScrim)], startPoint: .top,
                endPoint: .bottom))
    }
}

struct LensBackdrop: View {
    let work: ArtWork?

    var body: some View {
        ZStack {
            Color.black
            if let work {
                work.image
                    .resizable()
                    .scaledToFill()
                    .blur(radius: .artBlur)
                    .opacity(.opacitySoft)
                    .id(work.id)
                    .transition(.opacity)
            }
            LinearGradient(
                colors: [.black.opacity(.opacityTint), .black.opacity(.opacityStrong)],
                startPoint: .top, endPoint: .bottom)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

struct PosterCarousel: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let works: [ArtWork]
    private let lap: Double = 20

    init(works: [ArtWork]) {
        self.works = works
    }

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            ScrollView(.horizontal) {
                HStack(spacing: .spaceL) {
                    ForEach(Array((works + works).enumerated()), id: \.offset) { index, work in
                        ArtPoster(work: work)
                            .rotationEffect(
                                index.isMultiple(of: 2)
                                    ? .posterTilt : .degrees(-Angle.posterTilt.degrees)
                            )
                            .offset(y: index.isMultiple(of: 2) ? .spaceM : -.spaceM)
                    }
                }
                .padding(.vertical, .spaceXL)
                .offset(x: -shift(at: timeline.date))
            }
            .scrollDisabled(true)
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
        }
        .clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Artworks from the Fiscal collection, all in the public domain"))
    }

    private var loopWidth: CGFloat {
        CGFloat(works.count) * (.posterWidth + .spaceL)
    }

    private func shift(at date: Date) -> CGFloat {
        guard !reduceMotion, !works.isEmpty else { return .posterWidth / 2 }
        let phase = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: lap) / lap
        return loopWidth * phase
    }
}

struct LensSwatch: View {
    let swatch: LensPaletteSwatch

    var body: some View {
        Circle()
            .fill(swatch.gradient)
            .frame(width: .badgeM, height: .badgeM)
            .accessibilityHidden(true)
    }
}
