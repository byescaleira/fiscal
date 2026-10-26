import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct ThemesSection: View {
    @Environment(SearchModel.self) private var search

    var body: some View {
        Section {
            if let activity = search.themeActivity, activity.hasVotes {
                ThemeOverviewRow(activity: activity)
                if activity.periods.count > 1 {
                    ThemeCadenceRow(activity: activity)
                }
            } else if search.isLoadingThemes {
                ThemeOverviewRow(activity: .placeholder(themes: search.themes))
                    .loading(true)
                    .accessibilityHidden(true)
            } else {
                if search.themeActivity != nil {
                    IconRow(
                        "No votes on these topics in the latest update.", symbol: "tray",
                        color: .secondary)
                }
                ThemeLinkRows()
            }
        } header: {
            VStack(alignment: .leading, spacing: .spaceXS) {
                Text(search.isLensAdapted ? "Your topics" : "Topics").sectionTitle()
                if search.showsLensBadge {
                    LensBadge()
                }
            }
            .textCase(nil)
        } footer: {
            VStack(alignment: .leading, spacing: .space2XS) {
                if search.themeActivity?.hasVotes == true {
                    Text("Tap a topic to see its votes. Slide across the bars to see each day.")
                } else {
                    Text("A topic shows the latest votes in Congress about it.")
                }
                SearchSourceFooter()
            }
        }
    }
}

private struct ThemeOverviewRow: View {
    @Environment(SearchModel.self) private var search
    let activity: ThemeActivity

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceM) {
            VStack(alignment: .leading, spacing: .spaceXS) {
                Chip("RECENT VOTES · \(activity.total)", color: .secondary)
                Text(verbatim: search.headline(for: activity))
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            ThemeBarsChart(activity: activity)
            ExplainerCard(search.barsExplanation(for: activity), style: .caption)
        }
        .padding(.vertical, .spaceS)
    }
}

private struct ThemeCadenceRow: View {
    @Environment(SearchModel.self) private var search
    let activity: ThemeActivity

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            VStack(alignment: .leading, spacing: .spaceHairline) {
                Text(verbatim: search.cadenceTitle(for: activity))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                if let average = search.averageText(for: activity) {
                    Text(verbatim: average)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            ThemeCadenceChart(activity: activity)
            ExplainerCard(search.cadenceExplanation(for: activity), style: .caption)
        }
        .padding(.vertical, .spaceS)
    }
}

private struct ThemeLinkRows: View {
    @Environment(SearchModel.self) private var search

    var body: some View {
        ForEach(Array(search.themes.enumerated()), id: \.element) { slot, theme in
            Button {
                search.apply(.theme(theme))
            } label: {
                Label {
                    Text(verbatim: theme.title).foregroundStyle(Color.primary)
                } icon: {
                    Image(systemName: theme.symbol)
                        .foregroundStyle(ChartPalette.color(at: slot))
                }
            }
            .accessibilityHint(Text("Shows the recent votes on this topic"))
        }
    }
}
