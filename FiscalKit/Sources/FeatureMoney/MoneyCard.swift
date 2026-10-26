import FiscalDesignSystem
import SwiftUI

struct MoneyCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: .spaceM) { content }
            .multilineTextAlignment(.center)
            .foregroundStyle(.primary)
            .padding(.spaceInset)
            .frame(maxWidth: .infinity)
            .background(.groupedRow, in: .rect(cornerRadius: .radiusGroup))
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
    }
}

struct MoneyHeroValue: View {
    @Environment(\.appTint) private var tint
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let chip: String
    let value: String
    let cents: Int
    let caption: String

    var body: some View {
        VStack(spacing: .spaceS) {
            Text(verbatim: chip)
                .font(.caption.weight(.heavy))
                .foregroundStyle(tint)
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
