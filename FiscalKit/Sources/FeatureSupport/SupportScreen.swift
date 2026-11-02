import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public struct SupportScreen: View {
    @Environment(SupportModel.self) private var model
    @Environment(SupportContext.self) private var context
    private let service: (any PublicDataService)?
    private let follows: (any FollowRepository)?

    public init(service: (any PublicDataService)?, follows: (any FollowRepository)?) {
        self.service = service
        self.follows = follows
    }

    public var body: some View {
        @Bindable var model = model
        Group {
            if model.hasChoice {
                SupportTimelineContent()
            } else if context.hasLoaded {
                SupportEmptyState()
            } else {
                ProgressView("Loading")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("My Support")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Choose People and Causes", systemImage: "slider.horizontal.3") {
                    model.isEditing = true
                }
                .tint(Color.primary)
            }
        }
        .sheet(isPresented: $model.isEditing) {
            ModelHost(
                SupportEditorModel(context: context, service: service, follows: follows)
            ) {
                SupportEditor()
            }
        }
        .sheet(isPresented: $model.isConfirmingErase) {
            SupportEraseGuide()
        }
        .task(id: context.saved) { await model.load() }
        .refreshable { await model.load() }
    }
}

private struct SupportEmptyState: View {
    @Environment(SupportModel.self) private var model

    var body: some View {
        EmptyStateView(
            title: "Follow What You Support",
            description:
                "Choose people and causes to see their votes and proposals by date. It stays on this device, and it changes nothing else in the app.",
            actionTitle: "Choose People and Causes",
            action: { model.isEditing = true }
        ) {
            IconRow("Only on this device", symbol: "lock", color: .retroDenim)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SupportTimelineContent: View {
    @Environment(SupportModel.self) private var model

    var body: some View {
        PublicDataContent(
            phase: model.phase, isEmpty: model.isEmpty, retry: { await model.load() }
        ) {
            list
        } empty: {
            list
        }
    }

    private var list: some View {
        AdaptiveList {
            Section {
                SupportFilterRail()
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                if model.hasGaps {
                    Label(
                        "Some sources did not answer. Pull to try again.", systemImage: "wifi.slash"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
                }
                if let note = model.votesNote {
                    Label {
                        Text(verbatim: note)
                    } icon: {
                        Image(systemName: "info.circle")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
                }
            }
            if model.sections.isEmpty, model.phase == .loaded {
                Section {
                    Text(verbatim: model.emptyMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(model.sections) { section in
                Section {
                    ForEach(section.events) { SupportEventRow(event: $0) }
                } header: {
                    Text(verbatim: section.title).sectionTitle()
                }
            }
            Section {
                Button("Delete My Support", systemImage: "trash", role: .destructive) {
                    model.isConfirmingErase = true
                }
            } footer: {
                Text(verbatim: model.footnote)
            }
        }
    }
}

private struct SupportEraseGuide: View {
    @Environment(SupportModel.self) private var model

    var body: some View {
        GuideSheet(
            index: 0, count: 1, isWorking: model.isErasing,
            primary: GuideAction("Delete My Support") { Task { await model.erase() } },
            secondary: GuideAction("Keep It") { model.isConfirmingErase = false }
        ) {
            GuidePage(
                title: "Delete your support?",
                message:
                    "The people and causes you chose leave this device for good. Whoever you follow stays followed."
            ) {
                FiscalAnimationView(.privacy)
            }
        }
    }
}
