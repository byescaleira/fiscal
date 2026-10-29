import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

extension InvestigationModel {
    static let pickerLimit = 60

    func choices(for kind: InvestigationPiece.Kind) -> [InvestigationPiece] {
        let terms = SearchText.words(pickerQuery)
        let matches: ([String]) -> Bool = { words in
            terms.isEmpty || SearchText.matches(terms, in: words)
        }
        let list: [InvestigationPiece]
        switch kind {
        case .person, .spending, .checks, .context:
            let people = index.people.filter { matches($0.words) }.map(\.value)
            let eligible =
                kind == .person || kind == .checks
                ? people
                : people.filter {
                    [.senator, .federalDeputy, .stateDeputy].contains($0.office) || kind == .context
                }
            list = eligible.map { card in
                switch kind {
                case .spending: .spending(card)
                case .checks: .checks(card)
                case .context: .context(card)
                default: .person(card)
                }
            }
        case .vote:
            list = index.votes.filter { matches($0.words) }.map { .vote($0.value) }
        case .place:
            let places = index.places.filter { matches($0.words) }.map(\.value)
            list = (places.filter(\.isState) + places.filter { !$0.isState }).map { .place($0) }
        case .theme:
            list = Theme.neutralOrder.filter { matches(SearchText.words($0.title)) }.map {
                .theme($0)
            }
        case .party:
            list = index.parties.filter { matches($0.words) }.map { .party($0.value.party) }
        case .highlight:
            list = highlights.filter { matches(SearchText.words($0.title)) }
                .map { .highlight(HighlightRef($0)) }
        }
        return Array(list.prefix(Self.pickerLimit))
    }
}

struct PiecePicker: View {
    @Environment(InvestigationModel.self) private var board
    @Environment(\.dismiss) private var dismiss
    let kind: InvestigationPiece.Kind

    var body: some View {
        @Bindable var board = board
        NavigationStack {
            let choices = board.choices(for: kind)
            List {
                Group {
                    if choices.isEmpty {
                        if board.hasData {
                            ContentUnavailableView.search(text: board.pickerQuery)
                        } else {
                            ProgressView("Loading")
                                .frame(maxWidth: .infinity)
                        }
                    } else {
                        Section {
                            ForEach(choices) { piece in
                                PickerRow(piece: piece)
                            }
                        } footer: {
                            Text(kind.pickerFooter)
                        }
                    }
                }
                .surfaceRows()
            }
            .listSurface()
            .searchable(text: $board.pickerQuery, prompt: Text(kind.pickerPrompt))
            .navigationTitle(kind.doorTitle)
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .tint(Color.primary)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onDisappear { board.pickerQuery = "" }
    }
}

private struct PickerRow: View {
    @Environment(InvestigationModel.self) private var board
    @Environment(\.dismiss) private var dismiss
    let piece: InvestigationPiece

    var body: some View {
        let isPinned = board.current?.contains(piece) ?? false
        Button {
            Task {
                if isPinned {
                    await board.remove(piece)
                } else {
                    dismiss()
                    await board.add(piece)
                }
            }
        } label: {
            HStack(spacing: .spaceM) {
                if let card = piece.person {
                    PersonPortrait(
                        slug: card.slug, name: card.name, party: card.party, size: .badgeM)
                } else {
                    SymbolBadge(piece.symbol, color: piece.kind.color, size: .badgeM)
                }
                VStack(alignment: .leading, spacing: .spaceHairline) {
                    Text(verbatim: piece.person?.name ?? piece.title)
                        .font(.rowTitle)
                        .foregroundStyle(Color.primary)
                        .lineLimit(2)
                    if let card = piece.person {
                        AdaptiveStack(spacing: .spaceS) {
                            PartyMark(card.party)
                            Text(verbatim: InvestigationPiece.person(card).detail)
                                .font(.rowDetail)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text(verbatim: piece.detail)
                            .font(.rowDetail)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: .spaceS)
                SelectionMark(isSelected: isPinned)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isPinned ? .isSelected : [])
    }
}

extension InvestigationPiece.Kind {
    var pickerPrompt: LocalizedStringKey {
        switch self {
        case .person, .spending, .checks, .context: "Name, party or state"
        case .vote: "Bill number or subject"
        case .place: "State or city"
        case .theme: "Topic"
        case .party: "Party"
        case .highlight: "Highlight"
        }
    }

    var pickerFooter: LocalizedStringKey {
        switch self {
        case .person: "In alphabetical order."
        case .spending: "Office allowance is published for deputies and senators."
        case .checks: "Fact checks by Projeto Comprova that name the person."
        case .context: "Prices and indexes since the person took office."
        case .vote: "The latest votes in the Chamber and the Senate, newest first."
        case .place: "States first, then cities."
        case .theme: "A topic is estimated from keywords in the official summary."
        case .party: "In alphabetical order."
        case .highlight: "Highlights of the moment, by relevance."
        }
    }
}
