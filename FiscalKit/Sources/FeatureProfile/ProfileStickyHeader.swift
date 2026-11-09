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
            ShortcutStrip(
                items: profile.chapters.map { .init(id: $0, title: $0.title) },
                current: profile.currentChapter, select: select)
        }
        .padding(.vertical, .spaceS)
        .frame(maxWidth: .readableColumn, alignment: .leading)
        .frame(maxWidth: .infinity)
    }
}
