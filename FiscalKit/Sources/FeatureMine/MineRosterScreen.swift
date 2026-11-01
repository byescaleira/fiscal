import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public struct MineRosterScreen: View {
    @State private var query = ""
    @State private var party: String?
    let roster: MineRoster

    public init(roster: MineRoster) {
        self.roster = roster
    }

    public var body: some View {
        let people = roster.filtered(query: query, party: party)
        Group {
            #if os(macOS)
                MineRosterTable(roster: roster, query: query, party: party)
                    .overlay {
                        if people.isEmpty { MineRosterNoMatch(query: $query, party: $party) }
                    }
                    .safeAreaInset(edge: .bottom) {
                        VStack(alignment: .leading, spacing: .spaceXS) {
                            Text(verbatim: roster.header(shown: people.count))
                            Text("In alphabetical order. Nobody is ranked.")
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, .spaceL)
                        .padding(.vertical, .spaceS)
                    }
            #else
                List {
                    Group {
                        Section {
                            if people.isEmpty {
                                MineRosterNoMatch(query: $query, party: $party)
                            } else {
                                ForEach(people) { MineRosterRow(card: $0) }
                            }
                        } header: {
                            Text(verbatim: roster.header(shown: people.count))
                        } footer: {
                            Text("In alphabetical order. Nobody is ranked.")
                        }
                    }
                    .surfaceRows()
                }
                .listSurface()
            #endif
        }
        .searchable(text: $query, prompt: Text("Name"))
        .navigationTitle(Text(verbatim: roster.title))
        #if !os(visionOS)
            .navigationSubtitle(roster.scopeTitle(party: party))
        #endif
        .sensoryFeedback(.selection, trigger: party)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                MineRosterFilter(roster: roster, party: $party)
            }
        }
    }
}

private struct MineRosterNoMatch: View {
    @Binding var query: String
    @Binding var party: String?

    var body: some View {
        ContentUnavailableView {
            Label("No one matches these filters", systemImage: "line.3.horizontal.decrease")
        } actions: {
            Button("Clear Filters") {
                query = ""
                party = nil
            }
            .font(.buttonLabel)
        }
    }
}

private struct MineRosterFilter: View {
    let roster: MineRoster
    @Binding var party: String?

    var body: some View {
        Menu {
            Picker("Party", selection: $party) {
                Label("All Parties", systemImage: "square.grid.2x2").tag(String?.none)
                ForEach(roster.parties) { share in
                    Text(verbatim: roster.partyOption(share))
                        .tag(String?.some(share.party))
                }
            }
            .pickerStyle(.inline)
            if party != nil {
                Divider()
                Button("Clear Filters", systemImage: "eraser.line.dashed") { party = nil }
            }
        } label: {
            Label("Filters", systemImage: "line.3.horizontal.decrease")
                .labelStyle(.iconOnly)
                .foregroundStyle(Color.primary)
                .quietBounce(value: party)
        }
        .accessibilityValue(Text(verbatim: roster.scopeTitle(party: party)))
        .menuStyle(.button)
        .buttonStyle(.plain)
        .tint(Color.primary)
        .badge(party == nil ? 0 : 1)
        .disabled(roster.parties.count < 2)
    }
}
