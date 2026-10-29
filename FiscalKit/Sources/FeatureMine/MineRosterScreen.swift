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
        List {
            Group {
                Section {
                    if people.isEmpty {
                        VStack(spacing: .spaceM) {
                            Image(systemName: "line.3.horizontal.decrease")
                                .font(.icon(.l))
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                            Text("No one matches these filters")
                                .font(.headline)
                            Button("Clear Filters") {
                                query = ""
                                party = nil
                            }
                            .buttonStyle(.borderless)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, .spaceXL)
                    } else {
                        ForEach(people) { MineRosterRow(card: $0) }
                    }
                } header: {
                    Text(verbatim: header(shown: people.count))
                } footer: {
                    Text("In alphabetical order. Nobody is ranked.")
                }
            }
            .surfaceRows()
        }
        .listSurface()
        .searchable(text: $query, prompt: Text("Name"))
        .navigationTitle(Text(verbatim: roster.title))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                MineRosterFilter(roster: roster, party: $party)
            }
        }
    }

    private func header(shown: Int) -> String {
        let total = roster.people.count
        guard shown != total else { return String(appLocalized: "\(total) people") }
        return String(appLocalized: "\(shown) of \(total) people")
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
                    Text(verbatim: "\(share.party) · \(PublicFormat.number(share.count))")
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
                .symbolEffect(.bounce, value: party)
                .accessibilityValue(Text(verbatim: party ?? String(appLocalized: "All Parties")))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .tint(Color.primary)
        .badge(party == nil ? 0 : 1)
        .disabled(roster.parties.count < 2)
    }
}
