import FeatureCore
import SwiftUI

struct SectionStack: View {
    @Environment(FiscalNavigation.self) private var navigation
    let section: AppSection

    var body: some View {
        NavigationStack(path: navigation.path(for: section)) {
            SectionScreen(section: section)
                .navigationDestination(for: Route.self) { route in
                    RouteScreen(route: route)
                        .environment(
                            \.close,
                            CloseAction { navigation.close(in: section, inspecting: false) })
                }
        }
        .environment(\.navigationSection, section)
    }
}
