import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct TodaySection<Content: View>: View {
    private let title: LocalizedStringKey
    private let source: String?
    private let action: (title: LocalizedStringKey, perform: () -> Void)?
    private let content: Content

    init(
        _ title: LocalizedStringKey, source: String?,
        action: (title: LocalizedStringKey, perform: () -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.source = source
        self.action = action
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceM) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.titleMedium)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: .spaceS)
                if let action {
                    Button(action.title, action: action.perform)
                        .font(.subheadline.weight(.semibold))
                        .buttonStyle(.borderless)
                }
            }
            content
            if let source {
                SourceFooter(text: source)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

struct SourceFooter: View {
    let text: String

    var body: some View {
        Label {
            Text(verbatim: text)
        } icon: {
            Image(systemName: "building.columns")
        }
        .labelStyle(.titleAndIcon)
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, .spaceXS)
    }
}

extension View {
    func todayCard() -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .background(.groupedRow, in: .rect(cornerRadius: .radiusGroup))
    }
}

struct LensPickMark: View {
    @Environment(\.appTint) private var tint

    var body: some View {
        Label("For who you support", systemImage: "heart")
            .font(.caption2.weight(.bold))
            .foregroundStyle(tint)
            .labelStyle(.titleAndIcon)
    }
}

struct ThemeTag: View {
    @Environment(\.appTint) private var tint
    let theme: Theme

    var body: some View {
        Label {
            Text(verbatim: theme.title.uppercased())
        } icon: {
            Image(systemName: theme.symbol)
        }
        .font(.caption2.weight(.heavy))
        .foregroundStyle(tint)
        .lineLimit(1)
    }
}

struct ThemeTile: View {
    @Environment(\.appTint) private var tint
    let symbol: String

    var body: some View {
        Image(systemName: symbol)
            .font(.icon(.s, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: .badgeM, height: .badgeM)
            .background(tint.opacity(.opacityTint), in: .rect(cornerRadius: .radiusS))
            .accessibilityHidden(true)
    }
}

extension TodayBallot {
    var color: Color {
        switch self {
        case .yes: .positive
        case .no: .negative
        case .abstention: .warning
        case .absent, .other: .secondary
        }
    }
}

struct BallotChip: View {
    let ballot: TodayBallot

    var body: some View {
        StatusCircle(ballot.title, symbol: ballot.symbol, color: ballot.color)
    }
}

struct ResultChip: View {
    let approved: Bool

    var body: some View {
        StatusCircle(
            approved ? String(appLocalized: "Approved") : String(appLocalized: "Rejected"),
            symbol: approved ? "checkmark" : "xmark",
            color: approved ? Color.positive : Color.negative)
    }
}

struct VoteTallyChart: View {
    let tally: VoteSummary.Tally

    var body: some View {
        TallyChart(
            segments: [
                .init(
                    id: "yes", title: String(appLocalized: "Yes"), value: Double(tally.yes ?? 0),
                    color: .positive),
                .init(
                    id: "no", title: String(appLocalized: "No"), value: Double(tally.no ?? 0),
                    color: .negative),
                .init(
                    id: "others", title: String(appLocalized: "Others"),
                    value: Double(tally.others ?? 0), color: .secondary),
            ], height: .spaceS
        )
        .accessibilityHidden(true)
    }
}

struct TallyLine: View {
    let tally: VoteSummary.Tally
    let font: Font

    var body: some View {
        AdaptiveStack(alignment: .firstTextBaseline, spacing: .spaceL) {
            count("Yes", value: tally.yes, symbol: "checkmark", color: .positive)
            count("No", value: tally.no, symbol: "xmark", color: .negative)
            count("Others", value: tally.others, symbol: "minus", color: .secondary)
        }
    }

    private func count(
        _ label: LocalizedStringKey, value: Int?, symbol: String, color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: .spaceHairline) {
            Label(label, systemImage: symbol)
                .font(.caption2.weight(.heavy))
                .textCase(.uppercase)
                .foregroundStyle(color)
            Text(verbatim: PublicFormat.number(value))
                .font(font)
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .accessibilityElement(children: .combine)
    }
}

struct TodayNotice: View {
    let text: String
    let symbol: String

    var body: some View {
        Label {
            Text(verbatim: text)
        } icon: {
            Image(systemName: symbol)
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.secondary)
        .padding(.spaceM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.subtleFill, in: .rect(cornerRadius: .radiusM))
        .accessibilityElement(children: .combine)
    }
}

struct RouteButton<Label: View>: View {
    @Environment(\.open) private var open
    @Environment(\.navigationSection) private var section
    let route: Route?
    let label: Label

    init(route: Route?, @ViewBuilder label: () -> Label) {
        self.route = route
        self.label = label()
    }

    var body: some View {
        if let route {
            Button {
                open(route, in: section)
            } label: {
                label.contentShape(.rect)
            }
            .buttonStyle(.plain)
        } else {
            label
        }
    }
}
