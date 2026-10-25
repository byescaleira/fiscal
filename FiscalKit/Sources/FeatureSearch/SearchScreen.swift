import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public struct SearchScreen: View {
    @Environment(SearchModel.self) private var search

    public init() {}

    public var body: some View {
        @Bindable var search = search
        AdaptiveList {
            if search.isSearching {
                SearchResultsList()
            } else {
                SearchHub()
            }
        }
        .fontDesign(.rounded)
        .navigationTitle("Search")
        .searchable(
            text: $search.query, tokens: $search.tokens,
            prompt: "Name, party, office, state or city"
        ) { token in
            Label(token.title, systemImage: token.symbol)
        }
        .onSubmit(of: .search) { search.record() }
        .task { await search.load() }
    }
}

struct SearchSourceFooter: View {
    @Environment(SearchModel.self) private var search

    var body: some View {
        if let line = search.sourceLine {
            Text(verbatim: line)
        }
    }
}
