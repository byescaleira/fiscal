import FeatureCore
import FiscalDesignSystem
import SwiftUI

public struct VoteBallotsScreen: View {
    @Environment(VoteDetailModel.self) private var vote

    public init() {}

    public var body: some View {
        @Bindable var vote = vote
        PublicDataContent(
            phase: vote.phase, isEmpty: vote.isEmpty, retry: { await vote.load() }
        ) {
            AdaptiveList {
                VoteBallotsSection()
            }
            .searchable(text: $vote.searchText, prompt: Text("Name, party or state"))
        } empty: {
            VoteDetailEmptyState()
        }
        .navigationTitle(vote.title)
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .refreshable { await vote.load() }
        .task { await vote.load() }
    }
}
