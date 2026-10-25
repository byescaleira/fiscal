import FiscalDesignSystem
import SwiftUI

struct MoneyCard<Background: ShapeStyle, Content: View>: View {
    private let background: Background
    private let content: Content

    init(_ background: Background, @ViewBuilder content: () -> Content) {
        self.background = background
        self.content = content()
    }

    var body: some View {
        VStack(spacing: .spaceM) { content }
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)
            .padding(.spaceInset)
            .frame(maxWidth: .infinity)
            .background(background, in: .rect(cornerRadius: .radiusGroup))
            .environment(\.colorScheme, .dark)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
    }
}

struct MoneyHeroValue: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let chip: String
    let value: String
    let cents: Int
    let caption: String
    let accent: Color

    var body: some View {
        VStack(spacing: .spaceS) {
            Chip(chip, color: accent, shape: .capsule)
            Text(verbatim: value)
                .font(.amountHero)
                .foregroundStyle(.white)
                .contentTransition(reduceMotion ? .identity : .numericText(value: Double(cents)))
                .amountLine()
            Text(verbatim: caption)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

struct MoneyScoreSide: View {
    let label: LocalizedStringKey
    let value: String
    let alignment: HorizontalAlignment

    var body: some View {
        VStack(alignment: alignment, spacing: .space2XS) {
            Text(label)
                .font(.chipLabel)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            Text(verbatim: value)
                .font(.scoreboardNumber)
                .monospacedDigit()
                .foregroundStyle(.white)
                .amountLine()
        }
        .accessibilityElement(children: .combine)
    }
}

struct RevealingBar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false
    let value: Double
    let color: Color

    var body: some View {
        ProgressBar(value: revealed ? value : 0, color: color)
            .onAppear {
                withAnimation(reduceMotion ? nil : .smooth(duration: 1)) { revealed = true }
            }
    }
}
