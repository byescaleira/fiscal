#if os(macOS)
    import FeatureCore
    import FiscalDesignSystem
    import FiscalDomain
    import SwiftUI

    struct VoteBallotsTable: View {
        @Environment(VoteDetailModel.self) private var vote
        @Environment(\.open) private var open
        @Environment(\.navigationSection) private var section
        @State private var order: [KeyPathComparator<VoteDetailModel.BallotRecord>] =
            VoteDetailModel.ballotOrder
        @State private var selection: VoteDetailModel.BallotRecord.ID?

        var body: some View {
            let records = vote.ballotRecords(sortedBy: order)
            VStack(alignment: .leading, spacing: .zero) {
                VStack(alignment: .leading, spacing: .spaceS) {
                    Text(verbatim: vote.ballotsTitle).sectionTitle()
                    BallotFilterPills()
                    BallotPartyFilter()
                }
                .padding([.horizontal, .top], .spaceL)
                .padding(.bottom, .spaceS)
                Table(records, selection: $selection, sortOrder: $order) {
                    TableColumn("Name", value: \.name) { record in
                        Text(verbatim: record.name).tableCell()
                    }
                    TableColumn("Party", value: \.party) { record in
                        Text(verbatim: record.party).tableCell()
                    }
                    TableColumn("State Code", value: \.uf) { record in
                        Text(verbatim: record.uf).tableCell()
                    }
                    TableColumn("Ballot", value: \.voteRank) { record in
                        BallotMark(text: record.vote, choice: record.choice).tableCell()
                    }
                }
                .overlay {
                    if records.isEmpty {
                        Text(verbatim: vote.ballotsEmptyText).foregroundStyle(.secondary)
                    }
                }
                .contextMenu(forSelectionType: VoteDetailModel.BallotRecord.ID.self) { ids in
                    if let route = vote.profileRoute(for: ids) {
                        Button("Open Profile", systemImage: "person.crop.circle") {
                            open(route, in: section)
                        }
                    }
                } primaryAction: { ids in
                    if let route = vote.profileRoute(for: ids) { open(route, in: section) }
                }
                Text(verbatim: vote.sourceText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, .spaceL)
                    .padding(.vertical, .spaceS)
            }
        }
    }
#endif
