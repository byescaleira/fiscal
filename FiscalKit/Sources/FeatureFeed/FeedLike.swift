import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct FeedLikeButton: View {
    @Environment(LikeController.self) private var like: LikeController?
    @Environment(\.appTint) private var tint
    @State private var likes = 0
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
                            if await like.toggle(item), !wasLiked { likes += 1 }
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
            .sensoryFeedback(.impact(weight: .light), trigger: likes)
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
