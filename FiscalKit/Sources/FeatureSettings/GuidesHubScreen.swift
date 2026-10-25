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
        VStack(alignment: .leading, spacing: .spaceS) {
            Text(verbatim: category.title)
                .font(.headline)
                .padding(.horizontal, .spaceS)
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
                    .background(appTint.opacity(.opacityFill), in: .rect(cornerRadius: .radiusS))
                    .allowsHitTesting(false)
                VStack(alignment: .leading, spacing: .space2XS) {
                    Text(verbatim: guide.title).font(.rowTitle)
                    Text(verbatim: guide.subtitle).font(.rowDetail).foregroundStyle(.secondary)
                    Label("\(guide.minutes) min", systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
        .background(.groupedRow, in: .rect(cornerRadius: .radiusM))
    }
}
