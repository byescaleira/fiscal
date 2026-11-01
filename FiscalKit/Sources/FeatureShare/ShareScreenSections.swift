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
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .accessibilityHeading(.h2)
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
                Image(systemName: network.symbol)
                    .font(.icon(.s))
                    .frame(height: .shareNetworkSymbol)
                Text(network.title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .fixedSize()
            }
            .foregroundStyle(selected ? AnyShapeStyle(.white) : AnyShapeStyle(tint))
            .frame(minWidth: .shareNetworkTile)
            .padding(.vertical, .spaceS)
            .padding(.horizontal, .space2XS)
            .background(
                selected ? AnyShapeStyle(tint) : AnyShapeStyle(tint.opacity(.opacityTint)),
                in: .rect(cornerRadius: .radiusM))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(network.title))
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

private struct ShareDestinationChip: View {
    @Environment(ShareModel.self) private var model
    @Environment(\.appTint) private var tint
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let destination: ShareDestination

    var body: some View {
        let selected = model.destination == destination
        Button {
            withAnimation(reduceMotion ? nil : .smooth) { model.choose(destination) }
        } label: {
            ShareCapsule(
                title: destination.title, symbol: selected ? "checkmark" : nil, isOn: selected,
                tint: tint)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(destination.postTitle))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct ShareCapsule: View {
    let title: LocalizedStringKey
    let symbol: String?
    let isOn: Bool
    let tint: Color

    var body: some View {
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
        .foregroundStyle(isOn ? AnyShapeStyle(tint) : AnyShapeStyle(.secondary))
        .padding(.horizontal, .spaceM)
        .padding(.vertical, .spaceS)
        .background(
            isOn ? AnyShapeStyle(tint.opacity(.opacityTint)) : AnyShapeStyle(.subtleFill),
            in: .capsule)
    }
}

private struct ShareFactsRail: View {
    @Environment(ShareModel.self) private var model
    @Environment(\.appTint) private var tint

    var body: some View {
        if !model.facts.isEmpty {
            VStack(alignment: .leading, spacing: .spaceS) {
                ShareControlTitle(title: "What goes in")
                EdgeToEdgeRail(.padded(.spaceL), spacing: .spaceS, snaps: false) {
                    ForEach(model.facts) { fact in
                        let isOn = model.isOn(fact)
                        Button {
                            model.toggle(fact)
                        } label: {
                            ShareCapsule(
                                title: "\(fact.title)", symbol: isOn ? "checkmark" : "plus",
                                isOn: isOn, tint: tint)
                        }
                        .buttonStyle(.plain)
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
    @Environment(\.appTint) private var tint
    @State private var showsArt = false
    @State private var showsCaption = false

    var body: some View {
        if model.offersMediaChoice {
            Button {
                model.sendsVideo.toggle()
            } label: {
                ShareCapsule(
                    title: "Animated video", symbol: model.sendsVideo ? "checkmark" : "plus",
                    isOn: model.sendsVideo, tint: tint)
            }
            .buttonStyle(.plain)
            .accessibilityValue(Text(model.sendsVideo ? "On" : "Off"))
        }
        if model.usesArt {
            Button {
                showsArt = true
            } label: {
                ShareCapsule(title: "Art", symbol: "photo", isOn: false, tint: tint)
            }
            .buttonStyle(.plain)
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
            Button {
                showsCaption = true
            } label: {
                ShareCapsule(title: "Caption", symbol: "text.alignleft", isOn: false, tint: tint)
            }
            .buttonStyle(.plain)
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
