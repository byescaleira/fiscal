import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct TodayFollowingLink: View {
    @Environment(TodayModel.self) private var today
    @Environment(FiscalNavigation.self) private var navigation: FiscalNavigation?
    @Environment(FollowingBadge.self) private var badge: FollowingBadge?

    var body: some View {
        Button {
            navigation?.selectedSection = .following
        } label: {
            HStack(spacing: .spaceM) {
                SymbolBadge("person.2", color: .info, size: .badgeL)
                VStack(alignment: .leading, spacing: .space2XS) {
                    Text(verbatim: today.followingTitle(newCount: badge?.count ?? 0))
                        .font(.headline)
                    Text(verbatim: today.followingDetail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.forward")
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.spaceL)
            .todayCard()
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}
