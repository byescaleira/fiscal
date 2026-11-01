import FiscalDesignSystem
import SwiftUI

struct ShareControls: View {
    @Environment(\.layoutContext) private var context

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            ShareDestinationPicker()
            ShareFactsRail()
            if context.size.height >= .shareNoteMinimumHeight {
                ShareNote()
            }
        }
        .padding(.horizontal, .spaceL)
    }
}

private struct ShareControlTitle: View {
    let title: LocalizedStringKey

    var body: some View {
        Text(title)
            .font(.emphasis(.subheadline, weight: .bold))
            .foregroundStyle(.primary)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct ShareDestinationPicker: View {
    @Environment(ShareModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            ShareControlTitle(title: "Where to post")
            EdgeToEdgeRail(.padded(.spaceL), spacing: .spaceS, snaps: false) {
                ForEach(ShareNetwork.allCases) { network in
                    ShareNetworkTile(network: network)
                }
            }
            EdgeToEdgeRail(.padded(.spaceL), spacing: .spaceS, snaps: false) {
                ForEach(model.destination.network.destinations) { destination in
                    ShareDestinationChip(destination: destination)
                }
                ShareTools()
            }
        }
        .sensoryFeedback(.selection, trigger: model.destination)
    }
}

private struct ShareNetworkTile: View {
    @Environment(ShareModel.self) private var model
    @Environment(\.appTint) private var tint
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let network: ShareNetwork

    var body: some View {
        let selected = model.destination.network == network
        Button {
            guard !selected, let first = network.destinations.first else { return }
            withAnimation(reduceMotion ? nil : .smooth) { model.choose(first) }
        } label: {
            VStack(spacing: .space2XS) {
                SymbolBadge(
                    network.symbol, color: selected ? tint : .secondary,
                    style: selected ? .filled : .tinted)
                Text(network.title)
                    .font(.caption2.weight(selected ? .bold : .medium))
                    .foregroundStyle(selected ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                    .lineLimit(1)
                    .fixedSize()
            }
            .frame(minWidth: .shareNetworkTile)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(network.title))
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

private struct ShareDestinationChip: View {
    @Environment(ShareModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let destination: ShareDestination

    var body: some View {
        let selected = model.destination == destination
        ShareCapsule(
            title: destination.title, symbol: selected ? "checkmark" : nil, isOn: selected
        ) {
            withAnimation(reduceMotion ? nil : .smooth) { model.choose(destination) }
        }
        .accessibilityLabel(Text(destination.postTitle))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct ShareCapsule: View {
    @Environment(\.appTint) private var tint
    let title: LocalizedStringKey
    let symbol: String?
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: .spaceXS) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.caption.weight(.bold))
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .tint(isOn ? tint : nil)
    }
}

private struct ShareFactsRail: View {
    @Environment(ShareModel.self) private var model

    var body: some View {
        if !model.facts.isEmpty {
            VStack(alignment: .leading, spacing: .spaceS) {
                ShareControlTitle(title: "What goes in")
                EdgeToEdgeRail(.padded(.spaceL), spacing: .spaceS, snaps: false) {
                    ForEach(model.facts) { fact in
                        let isOn = model.isOn(fact)
                        ShareCapsule(
                            title: "\(fact.title)", symbol: isOn ? "checkmark" : "plus", isOn: isOn
                        ) {
                            model.toggle(fact)
                        }
                        .disabled(!model.canToggle(fact))
                        .accessibilityValue(Text(isOn ? "On" : "Off"))
                    }
                }
            }
            .sensoryFeedback(.selection, trigger: model.facts.map(model.isOn))
        }
    }
}

private struct ShareTools: View {
    @Environment(ShareModel.self) private var model
    @State private var showsArt = false
    @State private var showsCaption = false

    var body: some View {
        if model.offersMediaChoice || model.usesArt || model.destination.acceptsCaption {
            Divider()
                .frame(height: .shareToolDivider)
        }
        if model.offersMediaChoice {
            ShareCapsule(
                title: "Animated video", symbol: model.sendsVideo ? "checkmark" : "plus",
                isOn: model.sendsVideo
            ) {
                model.sendsVideo.toggle()
            }
            .accessibilityValue(Text(model.sendsVideo ? "On" : "Off"))
        }
        if model.usesArt {
            ShareCapsule(title: "Art", symbol: "photo", isOn: false) {
                showsArt = true
            }
            .sheet(isPresented: $showsArt) {
                ShareToolSheet(title: "Art") {
                    ScrollView {
                        ShareArtPicker()
                            .padding(.spaceL)
                    }
                }
            }
        }
        if model.destination.acceptsCaption {
            ShareCapsule(title: "Caption", symbol: "text.alignleft", isOn: false) {
                showsCaption = true
            }
            .sheet(isPresented: $showsCaption) {
                ShareToolSheet(title: "Caption") {
                    Form {
                        ShareCaptionField()
                    }
                }
            }
        }
    }
}

private struct ShareToolSheet<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    let title: LocalizedStringKey
    @ViewBuilder let content: () -> Content

    var body: some View {
        NavigationStack {
            content()
                .navigationTitle(title)
                #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct ShareCaptionField: View {
    @Environment(ShareModel.self) private var model

    var body: some View {
        TextField(
            "Caption",
            text: Binding(get: { model.caption }, set: { model.editCaption($0) }),
            axis: .vertical
        )
        .font(.subheadline)
        .lineLimit(3...8)
        Text(verbatim: "\(model.caption.count)/\(ShareCaption.limit)")
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .accessibilityHidden(true)
    }
}

private struct ShareNote: View {
    @Environment(ShareModel.self) private var model

    var body: some View {
        Group {
            if model.isInvestigation {
                Text(
                    "The card carries only the numbers found, their sources and the date. Your question stays on this device unless you share it."
                )
            } else if model.isVictory {
                Text(
                    "The card carries the official TSE numbers and the time of the file. Your Lens never goes into the image."
                )
            } else if model.usesArt {
                Text(
                    "The card carries the official source, the date and the art credit. Your Lens never goes into the image."
                )
            } else {
                Text(
                    "The card carries the official source and the date. Your Lens never goes into the image."
                )
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
}
