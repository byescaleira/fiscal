import FeatureCore
import FiscalDesignSystem
import SwiftUI

public struct ProfileScreen: View {
    @Environment(ProfileModel.self) private var profile

    public init() {}

    public var body: some View {
        Group {
            if profile.isEmpty {
                ProfileEmptyState()
            }
        }
        .fontDesign(.rounded)
        .navigationTitle("Profile")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await profile.load() }
    }
}

private struct ProfileEmptyState: View {
    var body: some View {
        EmptyStateView(
            title: "Profile not loaded",
            description:
                "Attendance, votes, proposals, expenses and assets show up here, each with its official source."
        ) {
            IconRow("Votes", symbol: "checkmark.square", color: .retroDenim)
            IconRow("Expenses", symbol: "brazilianrealsign", color: .retroOlive)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.groupedBackground)
    }
}
