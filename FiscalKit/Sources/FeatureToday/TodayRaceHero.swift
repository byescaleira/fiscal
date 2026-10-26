import FeatureCore
import SwiftUI

struct TodayRaceHero<Content: View>: View {
    @Environment(PortraitStore.self) private var portraits: PortraitStore?
    let board: TodayRaceBoard
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .task(id: board.race.id) {
                for side in board.sides {
                    portraits?.shelve(slug: side.slug, party: side.candidate.party)
                }
            }
    }
}
