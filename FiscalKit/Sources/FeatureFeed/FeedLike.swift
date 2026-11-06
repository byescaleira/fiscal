import ByescaleiraEffects
import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

enum FeedLikeSpace {
    static let name = "feedLike"
}

struct FeedLikeState {
    var count = 0
    var origin = CGPoint.zero
}

struct FeedLikeButton: View {
    @Environment(LikeController.self) private var like: LikeController?
    @Environment(\.appTint) private var tint
    @Binding var state: FeedLikeState
    let id: String
    var ink: Color?
    let make: () -> LikedItem

    var body: some View {
        if let like {
            Toggle(
                isOn: Binding(
                    get: { like.isLiked(id) },
                    set: { _ in
                        let item = make()
                        let wasLiked = like.isLiked(id)
                        Task {
                            if await like.toggle(item), !wasLiked { state.count += 1 }
                        }
                    })
            ) {
                Text("Like")
            }
            .toggleStyle(
                FeedLikeToggleStyle(
                    ink: ink ?? tint,
                    rest: ink.map { AnyShapeStyle($0.opacity(.opacityStrong)) }
                        ?? AnyShapeStyle(.secondary))
            )
            .sensoryFeedback(.impact(weight: .light), trigger: state.count)
            .onGeometryChange(for: CGPoint.self) { proxy in
                let frame = proxy.frame(in: .named(FeedLikeSpace.name))
                return CGPoint(x: frame.midX, y: frame.midY)
            } action: {
                state.origin = $0
            }
        }
    }
}

private struct FeedLikeToggleStyle: ToggleStyle {
    let ink: Color
    let rest: AnyShapeStyle

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            Image(systemName: configuration.isOn ? "heart.fill" : "heart")
                .font(.body.weight(.semibold))
                .foregroundStyle(configuration.isOn ? AnyShapeStyle(ink) : rest)
                .privacySensitive(configuration.isOn)
                .contentTransition(.symbolEffect(.replace))
                .frame(minWidth: .badgeL, minHeight: .badgeL)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) { configuration.label }
        }
    }
}

struct FeedLikeWash: View {
    @Environment(\.appTint) private var tint
    @ReducesMotion private var reduceMotion
    let state: FeedLikeState
    var ink: Color?

    var body: some View {
        let isStill = reduceMotion || MotionBudget.isConstrained
        Rectangle()
            .fill((ink ?? tint).opacity(.opacityTint))
            .keyframeAnimator(initialValue: 0.0, trigger: state.count) { view, opacity in
                view.opacity(isStill ? 0 : opacity)
            } keyframes: { _ in
                MoveKeyframe(1.0)
                LinearKeyframe(0.0, duration: RippleTiming.duration)
            }
            .ripple(origin: state.origin, trigger: state.count)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

extension View {
    func feedLikeWash(_ state: FeedLikeState, ink: Color? = nil) -> some View {
        background { FeedLikeWash(state: state, ink: ink) }
            .coordinateSpace(.named(FeedLikeSpace.name))
    }
}
