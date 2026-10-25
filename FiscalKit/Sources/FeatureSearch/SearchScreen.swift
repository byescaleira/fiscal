import FeatureCore
import FiscalDesignSystem
import SwiftUI

public struct SearchScreen: View {
    @Environment(SearchModel.self) private var search

    public init() {}

    public var body: some View {
        @Bindable var search = search
        AdaptiveList {
            if search.isSearching {
                SearchResultsSection()
            } else {
                SearchExploreSection()
            }
        }
        .fontDesign(.rounded)
        .navigationTitle("Search")
        .searchable(text: $search.query, prompt: "Name, party or state")
        .task { await search.load() }
    }
}

private struct SearchResultsSection: View {
    @Environment(SearchModel.self) private var search

    var body: some View {
        Section {
            ContentUnavailableView.search(text: search.query)
        }
    }
}

private struct SearchExploreSection: View {
    var body: some View {
        Section {
            RouteLink(.compare(slugs: [])) {
                IconRow(
                    "Compare", detail: "Put two politicians side by side, with the same facts.",
                    symbol: "rectangle.split.2x1", color: .retroDenim)
            }
            RouteLink(.races) {
                IconRow(
                    "Elections", detail: "The official count, straight from the TSE.",
                    symbol: "checkmark.seal", color: .retroTeal)
            }
        } header: {
            Text("Explore").sectionTitle()
        }
    }
}
