import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct ProfileChecksChapter: View {
    @Environment(ProfileModel.self) private var profile

    var body: some View {
        if !profile.checkItems.isEmpty {
            ContentBlock(footer: [profile.checksSourceText]) {
                IconRow(
                    "Only what the agency chose to check",
                    detail:
                        "The verdict applies to the content that circulated, not to the person. Not being on this list says nothing about anyone.",
                    symbol: "info.circle", color: .retroDenim)
                ForEach(profile.checkItems) { check in
                    ProfileCheckRow(check: check)
                }
            }
        }
    }
}

private struct ProfileCheckRow: View {
    @Environment(ProfileModel.self) private var profile
    let check: FactCheck

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            AdaptiveRow(spacing: .spaceS) {
                if let verdict = check.verdict {
                    Chip(verdict, color: .secondary)
                }
                Text(verbatim: SourceFootnote.day(check.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(verbatim: check.title)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            ExternalLink("See the Source", destination: check.url)
                .font(.footnote.weight(.semibold))
            ExternalLink(destination: check.licenseUrl) {
                Text(verbatim: profile.checkCredit(check))
            }
            .font(.caption)
        }
    }
}
