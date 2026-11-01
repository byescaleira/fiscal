#if os(macOS)
    import FeatureCore
    import FiscalDesignSystem
    import FiscalDomain
    import SwiftUI

    struct MineRosterTable: View {
        @Environment(\.open) private var open
        @Environment(\.navigationSection) private var section
        @Environment(FollowController.self) private var follow: FollowController?
        @State private var order = MineRoster.order
        @State private var selection: PersonCard.ID?
        let roster: MineRoster
        let query: String
        let party: String?

        var body: some View {
            Table(
                roster.sorted(query: query, party: party, by: order), selection: $selection,
                sortOrder: $order
            ) {
                TableColumn("Name", value: \.name) { card in
                    Text(verbatim: card.name).tableCell()
                }
                TableColumn("Role", value: \.officeTitle) { card in
                    Text(verbatim: card.officeTitle).tableCell()
                }
                TableColumn("Party", value: \.party) { card in
                    Text(verbatim: card.party).tableCell()
                }
                TableColumn("State Code", value: \.uf) { card in
                    Text(verbatim: roster.stateText(card)).tableCell()
                }
            }
            .contextMenu(forSelectionType: PersonCard.ID.self) { ids in
                if let route = roster.profileRoute(for: ids) {
                    Button("Open Profile", systemImage: "person.crop.circle") {
                        open(route, in: section)
                    }
                }
                if let follow, let card = roster.card(for: ids) {
                    let isFollowing = follow.isFollowing(card.slug)
                    Button(
                        isFollowing ? LocalizedStringKey("Unfollow") : "Follow",
                        systemImage: isFollowing ? "person.badge.minus" : "person.badge.plus"
                    ) {
                        Task { await toggle(card, with: follow) }
                    }
                }
            } primaryAction: { ids in
                if let route = roster.profileRoute(for: ids) { open(route, in: section) }
            }
        }

        private func toggle(_ card: PersonCard, with follow: FollowController) async {
            let isFollowing = await follow.toggle(card)
            FollowController.announce(name: card.name, isFollowing: isFollowing)
        }
    }
#endif
