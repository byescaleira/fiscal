import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public struct ProfileScreen: View {
    @Environment(ProfileModel.self) private var profile
    @Environment(SessionModel.self) private var session

    public init() {}

    public var body: some View {
        @Bindable var profile = profile
        PublicDataContent(
            phase: profile.phase, isEmpty: profile.isEmpty, retry: { await profile.load() }
        ) {
            ProfilePage()
        } empty: {
            ProfileEmptyState()
        }
        .navigationTitle(profile.title)
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(removing: .title)
        #endif
        .task(id: session.generation) { await profile.load() }
        .errorAlert($profile.error)
    }
}

private struct ProfilePage: View {
    @Environment(ProfileModel.self) private var profile

    var body: some View {
        RevealPage(
            chapters: profile.chapters,
            onChapter: { profile.moveCurrentChapter(to: $0) },
            refresh: { await profile.load() },
            content: { jump in
                ProfileHero().revealHero()
                ProfileFailureNotice()
                ProfileSummary(select: jump)
                ForEach(profile.chapters) { chapter in
                    ProfileChapterView(chapter: chapter).revealChapter(chapter)
                }
            },
            bar: { jump, isShown in
                ProfileStickyHeader(select: jump)
                    .portraitsStill(!isShown)
            })
    }
}

private struct ProfileFailureNotice: View {
    @Environment(ProfileModel.self) private var profile

    var body: some View {
        if profile.hasFailedSource {
            VStack(alignment: .leading, spacing: .spaceS) {
                Label("Some sources didn't load", systemImage: "wifi.slash")
                    .font(.subheadline.weight(.semibold))
                Button("Try Again") { Task { await profile.load() } }
                    .font(.subheadline)
            }
            .padding(.spaceL)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.plainRow, in: .rect(cornerRadius: .radiusGroup))
        }
    }
}

private struct ProfileSummary: View {
    @Environment(ProfileModel.self) private var profile
    let select: (ProfileChapter) -> Void

    var body: some View {
        if !profile.summary.isEmpty {
            ContentBlock {
                ForEach(profile.summary) { fact in
                    Button {
                        select(fact.chapter)
                    } label: {
                        ProfileSummaryRow(fact: fact)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(Text("Goes to \(fact.chapter.title)"))
                }
                if let explanation = profile.numbersExplanation {
                    ExplainerCard(explanation)
                }
            }
        }
    }
}

private struct ProfileSummaryRow: View {
    let fact: ProfileSummaryFact

    var body: some View {
        HStack(spacing: .spaceM) {
            VStack(alignment: .leading, spacing: .spaceHairline) {
                Text(verbatim: fact.text)
                    .font(.rowTitle)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                if let source = fact.source {
                    Text(verbatim: source).font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "arrow.down")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .contentShape(.rect)
    }
}

private struct ProfileEmptyState: View {
    var body: some View {
        EmptyStateView(
            title: "Profile not loaded",
            description:
                "Attendance, votes, proposals, expenses and assets show up here, each with its official source."
        ) {
            IconRow("Votes", symbol: "checkmark.square", color: .retroDenim)
            IconRow("Expenses", symbol: "brazilianrealsign", color: .retroOlive)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.plainBackground)
    }
}
