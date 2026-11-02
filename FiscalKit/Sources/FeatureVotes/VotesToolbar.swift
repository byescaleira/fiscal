import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct VotesToolbar: ToolbarContent {
    @Environment(\.open) private var open
    @Environment(\.navigationSection) private var section

    var body: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            VotesFilterMenu()
        }
        FixedToolbarSpacer(placement: .primaryAction)
        ToolbarItem(placement: .primaryAction) {
            Button("My Support", systemImage: "heart") { open(.support, in: section) }
                .tint(Color.primary)
        }
    }
}

private struct VotesFilterMenu: View {
    @Environment(VotesModel.self) private var votes

    var body: some View {
        @Bindable var votes = votes
        Menu {
            Picker("House", selection: $votes.house) {
                ForEach(VotesModel.HouseFilter.allCases) { house in
                    Text(verbatim: house.title).tag(house)
                }
            }
            .pickerStyle(.inline)
            VotesTopicPicker()
            if votes.hasFilter {
                Divider()
                Button("Clear Filters", systemImage: "eraser.line.dashed") {
                    votes.clearFilters()
                }
            }
        } label: {
            Label("Filters", systemImage: "line.3.horizontal.decrease")
                .labelStyle(.iconOnly)
                .foregroundStyle(Color.primary)
                .quietBounce(value: votes.hasFilter)
                .accessibilityValue(Text(verbatim: votes.filterSummary))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .tint(Color.primary)
        .badge(votes.activeFilterCount)
        .disabled(votes.votes.isEmpty)
    }
}

private struct VotesTopicPicker: View {
    @Environment(VotesModel.self) private var votes

    var body: some View {
        @Bindable var votes = votes
        Picker(selection: $votes.theme) {
            Label("All Topics", systemImage: "square.grid.2x2").tag(Theme?.none)
            ForEach(votes.themeChoices) { TopicOption(theme: $0).tag(Theme?.some($0)) }
        } label: {
            Label("Topic", systemImage: "tag")
        }
        .pickerStyle(.menu)
    }
}

private struct TopicOption: View {
    let theme: Theme

    var body: some View {
        Label(theme.title, systemImage: theme.symbol)
    }
}
