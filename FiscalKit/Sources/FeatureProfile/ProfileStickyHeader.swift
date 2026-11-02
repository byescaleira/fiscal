import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct ProfileStickyHeader: View {
    @Environment(ProfileModel.self) private var profile
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let select: (ProfileChapter) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            if let person = profile.profile {
                HStack(spacing: .spaceM) {
                    PersonPortrait(
                        slug: person.slug, name: person.name, party: person.party,
                        size: .profileStickyPortrait,
                        expression: profile.hasJustFollowed ? .wave : nil,
                        gesture: profile.currentChapter.map(ProfilePortraitChoreography.gesture),
                        animatesAtAnySize: true
                    )
                    VStack(alignment: .leading, spacing: .spaceHairline) {
                        Text(verbatim: person.name)
                            .font(.headline)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                        if !dynamicTypeSize.isAccessibilitySize {
                            Text(verbatim: profile.identityLine)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, .spaceL)
            }
            ProfileChapterShortcuts(select: select)
        }
        .padding(.vertical, .spaceS)
        .frame(maxWidth: .readableColumn, alignment: .leading)
        .frame(maxWidth: .infinity)
        .background(.bar, ignoresSafeAreaEdges: .top)
        .overlay(alignment: .bottom) { Divider() }
    }
}

private struct ProfileChapterShortcuts: View {
    @Environment(ProfileModel.self) private var profile
    @Environment(\.appTint) private var tint
    let select: (ProfileChapter) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: .spaceS) {
                    ForEach(profile.chapters) { chapter in
                        shortcut(chapter).id(chapter)
                    }
                }
                .padding(.horizontal, .spaceL)
            }
            .scrollIndicators(.hidden)
            .onChange(of: profile.currentChapter) { _, chapter in
                guard let chapter else { return }
                withAnimation(.snappy) { proxy.scrollTo(chapter, anchor: .center) }
            }
        }
    }

    private func shortcut(_ chapter: ProfileChapter) -> some View {
        let isCurrent = profile.currentChapter == chapter
        return Button {
            select(chapter)
        } label: {
            Text(verbatim: chapter.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(isCurrent ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                .padding(.horizontal, .spaceM)
                .frame(minHeight: .badgeL)
                .background(
                    isCurrent ? AnyShapeStyle(tint) : AnyShapeStyle(.plainRow), in: .capsule
                )
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }
}
