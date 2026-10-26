import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct InvestigatorSection: View {
    @Environment(InvestigationModel.self) private var board

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: .spaceL) {
                InvestigatorField()
                if board.suggestions.isEmpty, !board.hasData {
                    InvestigatorPlaceholder()
                }
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
        if !board.suggestions.isEmpty {
            Section {
                InvestigatorSuggestions()
            }
            .railSection()
        }
    }
}

private struct InvestigatorField: View {
    @Environment(InvestigationModel.self) private var board
    @Environment(\.appTint) private var tint
    @FocusState private var isFocused: Bool

    var body: some View {
        @Bindable var board = board
        VStack(alignment: .leading, spacing: .spaceS) {
            Chip("INVESTIGATE", color: tint, shape: .capsule)
            HStack(alignment: .top, spacing: .spaceM) {
                TextField(
                    "What do you want to investigate?", text: $board.question, axis: .vertical
                )
                .font(.caseQuestion)
                .lineLimit(1...4)
                .focused($isFocused)
                .submitLabel(.search)
                .onSubmit { submit() }
                .onChange(of: board.question) { _, text in
                    guard text.contains("\n") else { return }
                    board.question = text.replacing("\n", with: " ")
                        .trimmingCharacters(in: .whitespaces)
                    submit()
                }
                .frame(minHeight: .caseQuestionField, alignment: .topLeading)
                Button {
                    submit()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.icon(.l))
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.borderless)
                .tint(tint)
                .disabled(
                    board.question.trimmingCharacters(in: .whitespaces).isEmpty || board.isReading
                )
                .accessibilityLabel(Text("Investigate"))
            }
            .padding(.spaceL)
            .background(.groupedRow, in: .rect(cornerRadius: .radiusL))
            InvestigatorMode()
        }
    }

    private func submit() {
        isFocused = false
        Task { await board.investigate() }
    }
}

private struct InvestigatorMode: View {
    @Environment(InvestigationModel.self) private var board

    var body: some View {
        Group {
            if board.isReading {
                Label {
                    Text("Reading your question on this device…")
                } icon: {
                    ProgressView().controlSize(.small)
                }
            } else if board.usesIntelligence {
                Label {
                    Text(
                        "Apple Intelligence reads the question on this device. The numbers always come from the official data."
                    )
                } icon: {
                    Image(systemName: "apple.intelligence").symbolRenderingMode(.multicolor)
                }
            } else {
                Label(
                    "Without Apple Intelligence, Fiscal reads names, parties, states, topics and bill numbers. You can also pin pieces by hand.",
                    systemImage: "text.magnifyingglass")
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(.horizontal, .spaceS)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct InvestigatorSuggestions: View {
    @Environment(InvestigationModel.self) private var board
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            Text("Suggested investigations")
                .sectionTitle()
                .padding(.horizontal, .railTitleMargin)
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: .spaceM) {
                    ForEach(board.suggestions) { SuggestionCard(suggestion: $0) }
                }
                .padding(.horizontal, .spaceInset)
            } else {
                EdgeToEdgeRail {
                    ForEach(board.suggestions) { suggestion in
                        SuggestionCard(suggestion: suggestion)
                            .frame(width: .caseSuggestion)
                    }
                }
            }
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
}

private struct SuggestionCard: View {
    @Environment(InvestigationModel.self) private var board
    let suggestion: InvestigationSuggestion

    var body: some View {
        Button {
            Task { await board.open(suggestion) }
        } label: {
            VStack(alignment: .leading, spacing: .spaceM) {
                HStack(spacing: .spaceXS) {
                    Image(systemName: suggestion.symbol)
                    Text(verbatim: suggestion.kicker.uppercased(with: .app))
                }
                .font(.caseKicker)
                .foregroundStyle(.secondary)
                Text(verbatim: suggestion.question)
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: .zero)
                PieceStrip(pieces: suggestion.pieces)
            }
            .frame(maxWidth: .infinity, minHeight: .casePiece, alignment: .topLeading)
            .padding(.spaceL)
            .background(.groupedRow, in: .rect(cornerRadius: .radiusL))
            .contentShape(.rect(cornerRadius: .radiusL))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Opens the investigation board"))
    }
}

struct PieceStrip: View {
    let pieces: [InvestigationPiece]

    var body: some View {
        HStack(spacing: .space2XS) {
            ForEach(pieces.prefix(4)) { piece in
                if case .person(let card) = piece {
                    PersonPortrait(
                        slug: card.slug, name: card.name, party: card.party, size: .badgeS
                    )
                    .overlay { Circle().strokeBorder(Color.groupedRow, lineWidth: .spaceHairline) }
                } else {
                    StatusCircle(piece.kind.title, symbol: piece.symbol, color: piece.kind.color)
                }
                if piece.id != pieces.prefix(4).last?.id {
                    Capsule()
                        .fill(.tertiary)
                        .frame(width: .spaceS, height: .caseThread)
                        .accessibilityHidden(true)
                }
            }
        }
    }
}

private struct InvestigatorPlaceholder: View {
    var body: some View {
        HStack(spacing: .spaceM) {
            ForEach(0..<2, id: \.self) { _ in
                RoundedRectangle(cornerRadius: .radiusL)
                    .fill(Color.groupedRow)
                    .frame(height: .casePiece)
            }
        }
        .loading(true)
        .accessibilityHidden(true)
    }
}
