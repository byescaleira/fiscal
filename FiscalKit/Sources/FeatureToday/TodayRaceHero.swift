import FeatureCore
import FeatureLiveResults
import SwiftUI

struct TodayRaceHero: View {
    @Environment(PortraitStore.self) private var portraits: PortraitStore?
    let board: TodayRaceBoard

    var body: some View {
        RaceHeroCard(race: board.race, opensDetail: true)
            .task(id: board.race.id) {
                for side in board.sides {
                    portraits?.shelve(slug: side.slug, party: side.candidate.party)
                }
            }
    }
}
