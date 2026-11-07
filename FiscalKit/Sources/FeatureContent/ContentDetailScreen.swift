import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public struct ContentDetailScreen: View {
    @Environment(ContentDetailModel.self) private var model
    @Environment(\.open) private var open
    @Environment(\.navigationSection) private var section

    public init() {}

    public var body: some View {
        PublicDataContent(
            phase: model.phase, isEmpty: model.isEmpty, retry: model.load
        ) {
            if let content = model.content {
                ContentDetailPage(content: content)
            }
        } empty: {
            EmptyStateView(
                title: "This Highlight Left the List",
                description:
                    "Highlights change as new facts come in. See the current ones in the Feed."
            ) {
                IconRow("Official sources", symbol: "building.columns", color: .retroDenim)
            }
        }
        .navigationTitle(model.content?.kind.title ?? "")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(removing: .title)
        #endif
        .toolbar {
            if let route = model.shareRoute {
                ToolbarItem(placement: .primaryAction) {
                    Button("Share", systemImage: "square.and.arrow.up") {
                        open(route, in: section)
                    }
                    .tint(Color.primary)
                }
            }
        }
        .task { await model.load() }
    }
}

private struct ContentDetailPage: View {
    @Environment(ContentDetailModel.self) private var model
    @Environment(\.appTint) private var tint
    let content: ContentDetail

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .spaceXL) {
                header
                VStack(alignment: .leading, spacing: .spaceS) {
                    ContentFactsGrid(rows: model.factRows)
                    if content.weight != nil { relevance }
                }
                ContentSummary(content: content)
                if !content.themes.isEmpty { themes }
                if let person = content.person { ContentAuthorLink(person: person) }
                ContentSourceBlock(content: content)
            }
            .padding(.spaceInset)
            .frame(maxWidth: .readableColumn, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            Text(verbatim: model.kicker)
                .font(.chipLabel)
                .foregroundStyle(tint)
            Text(verbatim: content.title)
                .font(.emphasis(.title3, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
    }

    private var themes: some View {
        FlowLayout(spacing: .spaceS) {
            ForEach(content.themes) { theme in
                Label {
                    Text(verbatim: theme.title)
                } icon: {
                    Image(systemName: theme.symbol)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .fixedSize()
            }
        }
    }

    private var relevance: some View {
        VStack(alignment: .leading, spacing: .spaceXS) {
            if let short = content.coverage?.uncertaintyShort {
                Text(verbatim: short)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            WeightMethodButton(method: content.method)
        }
    }
}

private struct ContentFactsGrid: View {
    let rows: [[ContentDetailModel.Fact]]

    var body: some View {
        if !rows.isEmpty {
            VStack(spacing: .spaceS) {
                ForEach(rows, id: \.first?.id) { row in
                    AdaptiveStack(spacing: .spaceS) {
                        ForEach(row) { ContentFactTile(fact: $0) }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct ContentFactTile: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let fact: ContentDetailModel.Fact

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceXS) {
            Label {
                Text(verbatim: fact.title)
            } icon: {
                Image(systemName: fact.symbol)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
            Text(verbatim: fact.value)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.spaceM)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.plainRow, in: .rect(cornerRadius: .radiusM))
        .accessibilityElement(children: .combine)
    }
}

private struct ContentSummary: View {
    let content: ContentDetail

    var body: some View {
        if content.plainSummary != nil || content.stageNote != nil
            || content.officialSummary != nil
        {
            VStack(alignment: .leading, spacing: .spaceM) {
                if let plain = content.plainSummary {
                    paragraph(plain)
                }
                if let note = content.stageNote {
                    paragraph(note)
                }
                if let official = content.officialSummary {
                    DisclosureGroup("Official summary") {
                        Text(verbatim: official)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, .spaceS)
                    }
                    .font(.subheadline.weight(.semibold))
                }
            }
        }
    }

    private func paragraph(_ text: String) -> some View {
        Text(verbatim: text)
            .font(.body)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct ContentAuthorLink: View {
    let person: PersonCard

    var body: some View {
        RouteLink(.person(slug: person.slug), showsChevron: false) {
            HStack(spacing: .spaceM) {
                PersonPortrait(slug: person.slug, name: person.name, party: person.party)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: .spaceHairline) {
                    Text(verbatim: person.name)
                        .font(.headline)
                    Text(verbatim: "\(person.officeTitle) · \(person.party)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.spaceM)
            .background(.plainRow, in: .rect(cornerRadius: .radiusM))
            .contentShape(.rect)
        }
        .followActions(person)
    }
}

private struct ContentSourceBlock: View {
    let content: ContentDetail

    var body: some View {
        if content.url != nil || content.sourceLine != nil {
            VStack(alignment: .leading, spacing: .spaceS) {
                if let url = content.url {
                    ExternalLink("See the Official Source", destination: url)
                        .font(.subheadline.weight(.semibold))
                }
                if let line = content.sourceLine {
                    Text(verbatim: line)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
