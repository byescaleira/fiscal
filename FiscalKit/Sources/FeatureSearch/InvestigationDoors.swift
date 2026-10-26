import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct InvestigationDoorsSection: View {
    static let kinds: [InvestigationPiece.Kind] = [
        .person, .vote, .place, .theme, .spending, .checks,
    ]

    @Environment(InvestigationModel.self) private var board
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.open) private var open
    @Environment(\.navigationSection) private var section

    var body: some View {
        Section {
            LazyVGrid(
                columns: dynamicTypeSize.isAccessibilitySize
                    ? [GridItem(.flexible())]
                    : [GridItem(.adaptive(minimum: .casePiece), spacing: .spaceM)],
                spacing: .spaceM
            ) {
                ForEach(Self.kinds) { kind in
                    Button {
                        Task { await board.start(with: kind) }
                    } label: {
                        DoorTile(
                            title: kind.doorTitle, detail: kind.doorDetail, symbol: kind.symbol,
                            color: kind.color)
                    }
                    .accessibilityHint(Text("Starts an investigation with this piece"))
                }
                Button {
                    open(.compare(slugs: []), in: section)
                } label: {
                    DoorTile(
                        title: String(appLocalized: "Compare"),
                        detail: String(appLocalized: "Two people, same numbers"),
                        symbol: "rectangle.split.2x1", color: .retroDenim)
                }
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        } header: {
            Text("Everything you can open").sectionTitle()
        } footer: {
            Text("Each door starts a board with one piece. Pin more pieces to connect them.")
        }
    }
}

private struct DoorTile: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let title: String
    let detail: String
    let symbol: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            SymbolBadge(symbol, color: color, size: .badgeM)
            Spacer(minLength: .zero)
            Text(verbatim: title)
                .font(.headline)
                .foregroundStyle(Color.primary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
            Text(verbatim: detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: .caseDoor, alignment: .topLeading)
        .padding(.spaceM)
        .background(.groupedRow, in: .rect(cornerRadius: .radiusM))
        .contentShape(.rect(cornerRadius: .radiusM))
        .accessibilityElement(children: .combine)
    }
}

extension InvestigationPiece.Kind {
    var doorTitle: String {
        switch self {
        case .person: String(appLocalized: "People")
        case .vote: String(appLocalized: "Votes")
        case .place: String(appLocalized: "Places")
        case .theme: String(appLocalized: "Topics")
        case .spending: String(appLocalized: "Money")
        case .checks: String(appLocalized: "Fact checks")
        case .party: String(appLocalized: "Parties")
        case .context: String(appLocalized: "Before and during the term")
        case .highlight: String(appLocalized: "Highlights")
        }
    }

    var doorDetail: String {
        switch self {
        case .person: String(appLocalized: "Attendance, votes and party guidance")
        case .vote: String(appLocalized: "Who voted how, by state and party")
        case .place: String(appLocalized: "How a state's delegation voted")
        case .theme: String(appLocalized: "Votes and proposals on a topic")
        case .spending: String(appLocalized: "Office allowance against peers")
        case .checks: String(appLocalized: "What Projeto Comprova checked")
        case .party: String(appLocalized: "How a party's members voted")
        case .context: String(appLocalized: "Prices since taking office")
        case .highlight: String(appLocalized: "Highlights of the moment")
        }
    }
}

struct SavedInvestigationsSection: View {
    @Environment(InvestigationModel.self) private var board

    var body: some View {
        if !board.saved.isEmpty {
            Section {
                ForEach(board.saved) { investigation in
                    Button {
                        Task { await board.open(investigation) }
                    } label: {
                        SavedRow(investigation: investigation)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { board.delete(at: $0) }
            } header: {
                Text("Your investigations").sectionTitle()
            } footer: {
                Text("Saved only on this device. Swipe to delete.")
            }
        }
    }
}

private struct SavedRow: View {
    let investigation: Investigation

    var body: some View {
        HStack(spacing: .spaceM) {
            VStack(alignment: .leading, spacing: .space2XS) {
                Text(verbatim: investigation.title)
                    .font(.rowTitle)
                    .foregroundStyle(Color.primary)
                    .lineLimit(2)
                if let key = investigation.keyNumber {
                    Text(verbatim: key)
                        .font(.rowDetail.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                PieceStrip(pieces: investigation.pieces)
            }
            Spacer(minLength: .spaceS)
            Text(
                verbatim: investigation.updatedAt.formatted(
                    .dateTime.day().month(.abbreviated).locale(.app))
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, .space2XS)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
