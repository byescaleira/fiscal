import FeatureCore
import SwiftUI

struct DeepLinks: ViewModifier {
    @Environment(FiscalNavigation.self) private var navigation

    func body(content: Content) -> some View {
        content
            .onOpenURL(perform: handle)
            .onChange(of: FiscalServices.shared.pendingURL, initial: true) { _, url in
                guard let url else { return }
                FiscalServices.shared.pendingURL = nil
                handle(url)
            }
            .task { handleLaunchArgument() }
    }

    private func handleLaunchArgument() {
        #if DEBUG
            guard let value = UserDefaults.standard.string(forKey: "fiscal.developer.openURL"),
                let url = URL(string: value)
            else { return }
            UserDefaults.standard.removeObject(forKey: "fiscal.developer.openURL")
            handle(url)
        #endif
    }

    private func handle(_ url: URL) {
        guard DeepLink.handles(url) else { return }
        switch DeepLink(url: url) {
        case .section(let section):
            navigation.selectedSection = section
        case .route(let route, let section):
            navigation.open(route, in: section)
        }
    }
}
