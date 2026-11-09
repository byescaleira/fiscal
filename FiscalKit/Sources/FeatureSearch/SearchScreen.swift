import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public struct SearchScreen: View {
    @Environment(SearchModel.self) private var search
    @Environment(SessionModel.self) private var session

    public init() {}

    public var body: some View {
        @Bindable var search = search
        @Bindable var board = search.board
        AdaptiveList {
            if search.isSearching {
                SearchResultsList()
            } else {
                SearchHub()
            }
        }
        .navigationTitle("Search")
        .searchable(
            text: $search.query, tokens: $search.tokens,
            prompt: "Name, party, office, state or city"
        ) { token in
            Label(token.title, systemImage: token.symbol)
        }
        .onSubmit(of: .search) { search.record() }
        .navigationDestination(isPresented: $board.isBoardOpen) {
            InvestigationScreen()
                .environment(search)
                .environment(board)
        }
        .environment(board)
        .task(id: session.generation) { await search.load() }
        .onChange(of: board.isBoardOpen) { _, isOpen in
            guard !isOpen else { return }
            Task { await board.loadSaved() }
        }
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
