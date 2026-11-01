import CoreGraphics
import FiscalDesignSystem
import SwiftUI

struct ShareFactsSection: View {
    @Environment(ShareModel.self) private var model

    var body: some View {
        if !model.facts.isEmpty {
            Section("What goes in") {
                ForEach(model.facts) { fact in
                    Toggle(
                        isOn: Binding(
                            get: { model.isOn(fact) },
                            set: { _ in model.toggle(fact) })
                    ) {
                        Text(verbatim: fact.title)
                    }
                    .disabled(!model.canToggle(fact))
                }
            }
        }
    }
}

struct ShareStyleSection: View {
    @Environment(ShareModel.self) private var model

    var body: some View {
        Section("Style") {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: .shareStyleTile), spacing: .spaceM)],
                alignment: .leading, spacing: .spaceM
            ) {
                ForEach(ShareStyle.allCases) { style in
                    ShareStyleTile(style: style)
                }
            }
            .padding(.vertical, .spaceXS)
        }
        .sensoryFeedback(.selection, trigger: model.style)
    }
}

private struct ShareStyleTile: View {
    @Environment(ShareModel.self) private var model
    @Environment(\.appTint) private var tint
    let style: ShareStyle

    var body: some View {
        let selected = model.style == style
        Button {
            model.style = style
        } label: {
            VStack(spacing: .spaceXS) {
                ShareStyleThumbnail(card: model.card(style: style), code: model.code)
                    .overlay {
                        RoundedRectangle(cornerRadius: .radiusM)
                            .strokeBorder(selected ? tint : .clear, lineWidth: .space2XS)
                    }
                Text(style.title)
                    .font(.footnote.weight(selected ? .bold : .regular))
                    .foregroundStyle(selected ? AnyShapeStyle(tint) : AnyShapeStyle(.secondary))
                    .lineLimit(1)
                    .fixedSize()
            }
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(style.title))
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

private struct ShareStyleThumbnail: View {
    let card: ShareCard?
    let code: CGImage?

    var body: some View {
        let size = card?.format.size ?? ShareFormat.stories.size
        let scale = CGFloat.shareStyleTile / size.width
        Group {
            if let card {
                ShareCardView(card: card, code: code)
                    .portraitsStill()
                    .partyMarksStill()
                    .scaleEffect(scale, anchor: .topLeading)
            }
        }
        .frame(width: .shareStyleTile, height: size.height * scale, alignment: .topLeading)
        .clipShape(.rect(cornerRadius: .radiusM))
        .accessibilityHidden(true)
    }
}

struct ShareDestinationSection: View {
    @Environment(ShareModel.self) private var model

    var body: some View {
        Section("Where to post") {
            ForEach(ShareNetwork.allCases) { network in
                VStack(alignment: .leading, spacing: .spaceS) {
                    Label(network.title, systemImage: network.symbol)
                        .font(.subheadline.weight(.semibold))
                    HStack(spacing: .spaceS) {
                        ForEach(network.destinations) { destination in
                            ShareDestinationChip(destination: destination)
                        }
                    }
                }
                .padding(.vertical, .spaceXS)
            }
        }
        .sensoryFeedback(.selection, trigger: model.destination)
    }
}

private struct ShareDestinationChip: View {
    @Environment(ShareModel.self) private var model
    @Environment(\.appTint) private var tint
    let destination: ShareDestination

    var body: some View {
        let selected = model.destination == destination
        Button {
            model.choose(destination)
        } label: {
            Text(destination.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selected ? AnyShapeStyle(.white) : AnyShapeStyle(tint))
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, .spaceM)
                .padding(.vertical, .spaceS)
                .background(
                    selected ? AnyShapeStyle(tint) : AnyShapeStyle(tint.opacity(.opacityTint)),
                    in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(destination.postTitle))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct ShareCaptionSection: View {
    @Environment(ShareModel.self) private var model

    var body: some View {
        Section("Caption") {
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
}

struct ShareNoteSection: View {
    @Environment(ShareModel.self) private var model

    var body: some View {
        Section {
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
            .font(.footnote)
            .foregroundStyle(.secondary)
            .listRowBackground(Color.clear)
        }
    }
}

struct SharePostBar: View {
    @Environment(ShareModel.self) private var model

    var body: some View {
        VStack(spacing: .spaceS) {
            if model.postFailed {
                Text("Couldn't prepare the file. Try again.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Button {
                Task { await model.post() }
            } label: {
                Label(model.destination.postTitle, systemImage: "square.and.arrow.up")
                    .lineLimit(1)
                    .minimumScaleFactor(.shareTextShrink)
                    .frame(maxWidth: .infinity)
            }
            .primaryButton()
            .disabled(model.rendered == nil || model.isPosting)
        }
        .padding(.spaceM)
        .readableWidth()
        .frame(maxWidth: .infinity)
        .background(.bar)
    }
}
