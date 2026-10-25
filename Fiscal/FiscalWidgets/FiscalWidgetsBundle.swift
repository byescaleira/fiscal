import SwiftUI
import WidgetKit

@main
struct FiscalWidgetsBundle: WidgetBundle {
    var body: some Widget {
        RaceLiveActivity()
        VoteWidget()
        RepresentativesWidget()
    }
}
