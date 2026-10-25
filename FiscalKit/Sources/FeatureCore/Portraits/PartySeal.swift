import FiscalDesignSystem
import Lottie
import SwiftUI

public struct PartySeal: View {
    private static let aspect: CGFloat = 2
    private static let letterScale: CGFloat = 0.3
    private static let textWidth: CGFloat = 0.72
    private static let textLift: CGFloat = 0.04
    private static let minimumScale: CGFloat = 0.5

    @Environment(PortraitStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.partyMarksAreStill) private var partyMarksAreStill
    @Environment(\.self) private var environment
    private let party: String

    public init(_ party: String) {
        self.party = party
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let seal = store.seal {
                    colored(LottieView(animation: seal))
                        .playbackMode(
                            reduceMotion || partyMarksAreStill
                                ? .paused(at: .progress(0))
                                : .playing(.fromProgress(0, toProgress: 1, loopMode: .loop))
                        )
                        .resizable()
                } else {
                    Capsule().fill(PartyPalette.of(party: party).gradient)
                }
                Text(party.uppercased())
                    .font(
                        .system(
                            size: proxy.size.height * Self.letterScale, weight: .heavy,
                            design: .rounded)
                    )
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(Self.minimumScale)
                    .frame(width: proxy.size.width * Self.textWidth)
                    .offset(y: -proxy.size.height * Self.textLift)
            }
        }
        .aspectRatio(Self.aspect, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Party \(party)"))
    }

    private func colored(_ view: LottieView<EmptyView>) -> LottieView<EmptyView> {
        let palette = PartyPalette.of(party: party)
        return
            view
            .valueProvider(
                ColorValueProvider(lottieColor(palette.primary)),
                for: AnimationKeypath(keypath: "primary.**.Color")
            )
            .valueProvider(
                ColorValueProvider(lottieColor(palette.secondary)),
                for: AnimationKeypath(keypath: "secondary.**.Color"))
    }

    private func lottieColor(_ color: Color) -> LottieColor {
        let resolved = color.resolve(in: environment)
        return LottieColor(
            r: Double(resolved.red), g: Double(resolved.green), b: Double(resolved.blue),
            a: Double(resolved.opacity))
    }
}
