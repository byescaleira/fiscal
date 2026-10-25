import FeatureCore
import FeatureHome
import SwiftUI

struct RouteScreen: View {
    @Environment(SessionModel.self) private var session
    let route: Route

    @ViewBuilder var body: some View {
        switch route {
        case .item(let id):
            ModelHost(ItemEditorModel(id: id, repositories: session.repositories)) {
                ItemEditorScreen()
            }
        }
    }
}
