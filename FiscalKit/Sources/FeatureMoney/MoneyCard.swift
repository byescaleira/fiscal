import FiscalDesignSystem
import SwiftUI

struct MoneyCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        card
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
    }

    @ViewBuilder private var card: some View {
        let stack = VStack(spacing: .spaceM) { content }
            .multilineTextAlignment(.center)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
        #if os(macOS)
            GroupBox { stack }
        #else
            stack
                .padding(.spaceInset)
                .background(.plainRow, in: .rect(cornerRadius: .radiusGroup))
        #endif
    }
}

struct MoneyHeroValue: View {
    @Environment(\.appTint) private var tint
    @ReducesMotion private var reduceMotion
    let chip: String
    let value: String
    let cents: Int
    let caption: String

    var body: some View {
        VStack(spacing: .spaceS) {
            Chip(chip, color: tint, shape: .capsule)
            Text(verbatim: value)
                .font(.amountHero)
                .monospacedDigit()
                .contentTransition(reduceMotion ? .identity : .numericText(value: Double(cents)))
                .amountLine()
            Text(verbatim: caption)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
