import FeatureCore
import FiscalDesignSystem
import SwiftUI

struct InspectorScreen: View {
    @Environment(FiscalNavigation.self) private var navigation
    let inspector: FiscalNavigation.Inspector

    var body: some View {
        @Bindable var navigation = navigation
        NavigationStack(path: $navigation.inspectorPath) {
            RouteScreen(route: inspector.route)
                .navigationDestination(for: Route.self) { RouteScreen(route: $0) }
                .toolbar { RoutePaneCloseItem { navigation.closeInspector() } }
        }
        .environment(\.navigationSection, inspector.section)
        .environment(
            \.close,
            CloseAction { navigation.close(in: inspector.section, inspecting: true) }
        )
        #if !os(visionOS) && !os(tvOS)
            .inspectorColumnWidth(min: .inspectorMin, ideal: .inspectorIdeal, max: .inspectorMax)
        #endif
    }
}
