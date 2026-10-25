import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public struct ProfileScreen: View {
    @Environment(ProfileModel.self) private var profile

    public init() {}

    public var body: some View {
        @Bindable var profile = profile
        PublicDataContent(
            phase: profile.phase, isEmpty: profile.isEmpty, retry: { await profile.load() }
        ) {
            AdaptiveList {
                ProfileSummarySection()
                ProfileFactsSection()
            }
        } empty: {
            ProfileEmptyState()
        }
        .fontDesign(.rounded)
        .navigationTitle(profile.title)
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar { ProfileToolbar() }
        .task { await profile.load() }
        .errorAlert($profile.error)
    }
}

private struct ProfileSummarySection: View {
    @Environment(ProfileModel.self) private var profile

    var body: some View {
        Section {
            if let subtitle = profile.subtitle {
                Text(verbatim: subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct ProfileFactsSection: View {
    @Environment(ProfileModel.self) private var profile

    var body: some View {
        Section {
            ForEach(profile.facts) { fact in
                LabeledContent {
                    Text(verbatim: fact.value).monospacedDigit()
                } label: {
                    Text(verbatim: fact.title)
                }
            }
        } header: {
            Text("In Numbers").sectionTitle()
        } footer: {
            Text("A dash means the source doesn't publish this number.")
        }
    }
}

private struct ProfileToolbar: ToolbarContent {
    @Environment(ProfileModel.self) private var profile
    @Environment(SessionModel.self) private var session

    var body: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            if profile.canFollow {
                Button {
                    Task {
                        await profile.toggleFollow()
                        session.reload()
                    }
                } label: {
                    if profile.isFollowing {
                        Label("Following", systemImage: "checkmark")
                    } else {
                        Label("Follow", systemImage: "plus")
                    }
                }
                .tint(Color.primary)
            }
        }
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
        .background(.groupedBackground)
    }
}
