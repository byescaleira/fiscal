import FiscalDesignSystem
import FiscalDomain
import SwiftUI
import WidgetKit

@main
struct FiscalWidgetsBundle: WidgetBundle {
    init() {
        FiscalLanguage.install()
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
