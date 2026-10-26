import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public struct InvestigationScreen: View {
    @Environment(InvestigationModel.self) private var board
    @Environment(\.open) private var open
    @Environment(\.navigationSection) private var section

    public init() {}

    public var body: some View {
        @Bindable var board = board
        AdaptiveList(columnWidth: .readableColumn) {
            CaseHeaderSection()
            PiecesSection()
            CaseStateSection()
            ForEach(board.board.links) { link in
                LinkSection(link: link)
            }
            if board.conclusion != nil {
                ConclusionSection()
            }
        }
        .emphasisTitle("Investigation")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                AddPieceMenu()
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    board.togglePin()
                } label: {
                    Label(
                        board.isPinned ? LocalizedStringKey("Unpin") : "Pin to top",
                        systemImage: board.isPinned ? "pin.slash" : "pin")
                }
                .tint(Color.primary)
                .disabled(!board.isSaved)
            }
            if let share = board.share {
                ToolbarItem(placement: .primaryAction) {
                    Button("Share", systemImage: "square.and.arrow.up") {
                        open(share, in: section)
                    }
                    .tint(Color.primary)
                }
            }
        }
        .sheet(item: $board.picking) { kind in
            PiecePicker(kind: kind)
                .environment(board)
        }
        .refreshable { await board.refresh() }
    }
}

struct AddPieceMenu: View {
    @Environment(InvestigationModel.self) private var board

    var body: some View {
        Menu {
            ForEach(InvestigationPiece.Kind.allCases) { kind in
                Button(kind.title, systemImage: kind.symbol) { board.picking = kind }
            }
        } label: {
            Label("Add piece", systemImage: "plus")
        }
        .tint(Color.primary)
        .disabled(!(board.current?.canAdd ?? false))
    }
}

private struct CaseHeaderSection: View {
    @Environment(InvestigationModel.self) private var board
    @Environment(\.appTint) private var tint
    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        Section {
        } header: {
            VStack(alignment: .leading, spacing: .spaceS) {
                HStack(spacing: .spaceS) {
                    Chip("INVESTIGATION", color: tint, shape: .capsule)
                    if let updated = board.updatedText {
                        Text(verbatim: updated)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                TextField("Name this investigation", text: $text, axis: .vertical)
                    .font(.titleLarge)
                    .foregroundStyle(Color.primary)
                    .lineLimit(1...4)
                    .focused($isFocused)
                    .submitLabel(.done)
                    .onSubmit { board.rename(text) }
                    .onChange(of: text) { _, value in
                        guard value.contains("\n") else { return }
                        text = value.replacing("\n", with: " ")
                            .trimmingCharacters(in: .whitespaces)
                        isFocused = false
                    }
                    .onChange(of: isFocused) { _, focused in
                        if !focused { board.rename(text) }
                    }
                OriginBadge()
            }
            .textCase(nil)
            .padding(.bottom, .spaceS)
            .onAppear { text = board.current?.question ?? "" }
            .onChange(of: board.current?.id) { _, _ in text = board.current?.question ?? "" }
        }
    }
}

private struct OriginBadge: View {
    @Environment(InvestigationModel.self) private var board

    var body: some View {
        switch board.origin {
        case .model:
            HStack(spacing: .space2XS) {
                Image(systemName: "apple.intelligence")
                    .symbolRenderingMode(.multicolor)
                    .accessibilityHidden(true)
                Text(
                    "Apple Intelligence picked the pieces from your question, on this device. Check them below."
                )
                .fixedSize(horizontal: false, vertical: true)
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, .spaceS)
            .padding(.vertical, .space2XS)
            .background(Color.secondary.opacity(.opacityFill), in: .rect(cornerRadius: .radiusS))
        case .reader:
            Label(
                "Fiscal read names, places and numbers in your question, without AI.",
                systemImage: "text.magnifyingglass"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        case nil:
            EmptyView()
        }
    }
}

private struct PiecesSection: View {
    @Environment(InvestigationModel.self) private var board

    var body: some View {
        Section {
            if board.pieces.isEmpty {
                EmptyPieces()
            } else {
                FlowLayout(spacing: .spaceS) {
                    ForEach(board.pieces) { PieceCard(piece: $0) }
                }
                .padding(.vertical, .spaceXS)
            }
        } header: {
            Text("Pinned pieces").sectionTitle()
        } footer: {
            VStack(alignment: .leading, spacing: .space2XS) {
                ForEach(board.board.hints, id: \.self) { Text(verbatim: $0) }
                Text(
                    "Up to \(Investigation.pieceLimit) pieces. Fiscal connects them only with published data."
                )
            }
        }
    }
}

private struct EmptyPieces: View {
    @Environment(InvestigationModel.self) private var board

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceM) {
            HStack(spacing: .space2XS) {
                ForEach([InvestigationPiece.Kind.person, .vote, .place]) { kind in
                    StatusCircle(kind.title, symbol: kind.symbol, color: kind.color, isDashed: true)
                    if kind != .place {
                        Capsule().fill(.tertiary).frame(width: .spaceL, height: .caseThread)
                            .accessibilityHidden(true)
                    }
                }
            }
            Text("Pin a person, a vote and a place, and Fiscal shows how they connect.")
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            Menu {
                ForEach(InvestigationPiece.Kind.allCases) { kind in
                    Button(kind.title, systemImage: kind.symbol) { board.picking = kind }
                }
            } label: {
                Label("Pin the first piece", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .primaryButton()
        }
        .padding(.vertical, .spaceS)
    }
}

private struct PieceCard: View {
    @Environment(InvestigationModel.self) private var board
    let piece: InvestigationPiece

    var body: some View {
        HStack(spacing: .spaceS) {
            if case .person(let card) = piece {
                PersonPortrait(
                    slug: card.slug, name: card.name, party: card.party, size: .badgeM,
                    expression: board.phase == .loading ? .think : nil)
            } else {
                SymbolBadge(piece.symbol, color: piece.kind.color, size: .badgeM)
            }
            VStack(alignment: .leading, spacing: .zero) {
                Text(verbatim: piece.kind.title.uppercased(with: .app))
                    .font(.caseKicker)
                    .foregroundStyle(piece.kind.color)
                Text(verbatim: piece.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                if case .person(let card) = piece {
                    PartyMark(card.party)
                }
            }
            Button {
                Task { await board.remove(piece) }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: .badgeS, height: .badgeS)
                    .contentShape(.rect)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(Text("Remove \(piece.title)"))
        }
        .padding(.leading, .spaceXS)
        .padding(.vertical, .spaceXS)
        .padding(.trailing, .space2XS)
        .frame(maxWidth: .casePiece * 2, alignment: .leading)
        .background(piece.kind.color.opacity(.opacityFill), in: .rect(cornerRadius: .radiusM))
        .accessibilityElement(children: .combine)
    }
}

private struct CaseStateSection: View {
    @Environment(InvestigationModel.self) private var board

    var body: some View {
        if board.isStale, let error = board.phase.error {
            Section {
                IconRow(verbatim: error.message, symbol: error.symbol, color: .retroRust)
                if let updated = board.updatedText {
                    Text("Showing the last data loaded. \(updated).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Button("Try Again") { Task { await board.refresh() } }
                    .font(.buttonLabel)
            }
        } else if board.board.isEmpty, !board.pieces.isEmpty {
            Section {
                switch board.phase {
                case .idle, .loading:
                    ProgressView("Connecting the pieces")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, .spaceL)
                case .failed(let error):
                    IconRow(verbatim: error.message, symbol: error.symbol, color: .retroRust)
                    Button("Try Again") { Task { await board.refresh() } }
                        .font(.buttonLabel)
                case .loaded:
                    ContentUnavailableView(
                        "No connection found", systemImage: "point.3.connected.trianglepath.dotted",
                        description: Text(
                            "The published data doesn't link these pieces yet. Try adding a vote or a person."
                        ))
                }
            }
        }
    }
}
