import FeatureCore
import FiscalDesignSystem
import SwiftUI

public struct GuidesHubScreen: View {
    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: .spaceXL) {
                ForEach(GuideCategory.allCases) { GuidesCategory(category: $0) }
            }
            .padding(.horizontal, .spaceInset)
            .padding(.vertical, .spaceL)
        }
        .readableWidth()
        .background(.groupedBackground)
        .fontDesign(.rounded)
        .navigationTitle("Guides")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

private struct GuidesCategory: View {
    let category: GuideCategory

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceM) {
            HStack(alignment: .firstTextBaseline, spacing: .spaceS) {
                Text(verbatim: category.title)
                    .font(.title3.weight(.bold))
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: .zero)
                Text("\(category.guides.count) guides")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .padding(.horizontal, .space2XS)
            ForEach(category.guides) { GuideCard(guide: $0) }
        }
    }
}

private struct GuideCard: View {
    @Environment(\.showGuide) private var showGuide
    @Environment(\.appTint) private var appTint
    let guide: Guide

    var body: some View {
        Button {
            showGuide?(guide)
        } label: {
            HStack(spacing: .spaceM) {
                FiscalAnimationView(guide.animation, isStill: true)
                    .frame(width: 96)
                    .padding(.spaceXS)
                    .background(appTint.opacity(.opacityFill), in: .rect(cornerRadius: .radiusM))
                    .allowsHitTesting(false)
                VStack(alignment: .leading, spacing: .space2XS) {
                    Text(verbatim: guide.title).font(.rowTitle)
                    Text(verbatim: guide.subtitle).font(.rowDetail).foregroundStyle(.secondary)
                    Chip("\(guide.minutes) min", color: appTint, shape: .capsule)
                        .padding(.top, .space2XS)
                }
                Spacer(minLength: .spaceS)
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .multilineTextAlignment(.leading)
            .padding(.spaceM)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .background(.groupedRow, in: .rect(cornerRadius: .radiusL, style: .continuous))
    }
}
