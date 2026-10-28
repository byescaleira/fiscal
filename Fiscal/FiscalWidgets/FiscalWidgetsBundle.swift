import FiscalDesignSystem
import SwiftUI
import WidgetKit

@main
struct FiscalWidgetsBundle: WidgetBundle {
    init() {
        EmphasisFont.register()
    }

    var body: some Widget {
        RaceLiveActivity()
        HighlightLiveActivity()
        VoteWidget()
        HighlightWidget()
        RepresentativesWidget()
    }
}
