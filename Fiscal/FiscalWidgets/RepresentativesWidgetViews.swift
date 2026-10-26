import FiscalDesignSystem
import FiscalDomain
import SwiftUI
import WidgetKit

struct PlaceMonogram: View {
    let digest: RepresentativesDigest

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: digest.ufText)
                .font(.placeMonogram)
                .foregroundStyle(WidgetStyle.primary)
                .widgetAccentable()
            Text(verbatim: digest.name.uppercased(with: .app))
                .font(.caption2.weight(.heavy))
                .foregroundStyle(WidgetStyle.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .privacySensitive()
        .accessibilityElement(children: .combine)
    }
}

struct RepresentativesSmall: View {
    let digest: RepresentativesDigest

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            HStack(alignment: .top) {
                PlaceMonogram(digest: digest)
                Spacer(minLength: 0)
                Image(systemName: "person.2")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(WidgetStyle.secondary)
                    .accessibilityHidden(true)
            }
            Spacer(minLength: 0)
            HStack(spacing: -.spaceS) {
                ForEach(digest.featured) { person in
                    PersonPortrait(
                        slug: person.slug, name: person.name, party: person.party, size: .badgeM
                    )
                    .overlay { Circle().stroke(WidgetStyle.board, lineWidth: .spaceHairline) }
                    .widgetAccentable()
                }
            }
            .privacySensitive()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: names))
            Text(verbatim: digest.sourceText)
                .font(.caption2)
                .foregroundStyle(WidgetStyle.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.9)
        }
    }

    private var names: String {
        digest.featured.map(digest.accessibility(for:)).joined(separator: "; ")
    }
}

struct RepresentativesMedium: View {
    let digest: RepresentativesDigest

    var body: some View {
        HStack(alignment: .top, spacing: .spaceL) {
            VStack(alignment: .leading, spacing: .space2XS) {
                PlaceMonogram(digest: digest)
                Spacer(minLength: 0)
                if let federal = digest.federalDeputies {
                    Text("\(federal) federal deputies")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(WidgetStyle.primary)
                }
                if let state = digest.stateDeputies {
                    Text("\(state) state deputies")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(WidgetStyle.primary)
                }
                Text(verbatim: digest.sourceText)
                    .font(.caption2)
                    .foregroundStyle(WidgetStyle.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .containerRelativeFrame(
                .horizontal, count: 5, span: 2, spacing: .spaceL, alignment: .leading)
            VStack(alignment: .leading, spacing: .spaceHairline) {
                ForEach(digest.featured) { person in
                    if let url = IntegrationLink.person(person.slug) {
                        Link(destination: url) { RepresentativeRow(digest: digest, person: person) }
                    } else {
                        RepresentativeRow(digest: digest, person: person)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct RepresentativeRow: View {
    let digest: RepresentativesDigest
    let person: PersonCard

    var body: some View {
        HStack(spacing: .spaceS) {
            PersonPortrait(slug: person.slug, name: person.name, party: person.party, size: .badgeS)
                .widgetAccentable()
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: person.name)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(WidgetStyle.primary)
                Text(verbatim: digest.detail(for: person))
                    .font(.caption2)
                    .foregroundStyle(WidgetStyle.secondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
        }
        .privacySensitive()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: digest.accessibility(for: person)))
    }
}
