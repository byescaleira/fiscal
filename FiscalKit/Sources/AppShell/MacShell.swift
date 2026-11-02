import FeatureCore
import FiscalDesignSystem
import SwiftUI

#if os(macOS)
    struct MacShell: View {
        @Environment(FiscalNavigation.self) private var navigation
        @Environment(FollowingBadge.self) private var badge

        var body: some View {
            NavigationSplitView {
                List(selection: selection) {
                    ForEach(AppSection.SourceGroup.allCases, id: \.self) { group in
                        Section(group.title) {
                            ForEach(group.sections) { section in
                                Label(section.title, systemImage: section.systemImage)
                                    .badge(section == .feed ? badge.count : 0)
                                    .tag(section)
                            }
                        }
                    }
                }
                .navigationSplitViewColumnWidth(
                    min: .inspectorMin, ideal: .inspectorMin, max: .inspectorIdeal)
            } detail: {
                SectionStack(section: navigation.selectedSection)
                    .id(navigation.selectedSection)
            }
        }

        private var selection: Binding<AppSection?> {
            Binding(
                get: { navigation.selectedSection },
                set: { if let section = $0 { navigation.selectedSection = section } })
        }
    }

    public struct FiscalCommands: Commands {
        @FocusedValue(\.fiscalNavigation) private var navigation

        public init() {}

        public var body: some Commands {
            CommandMenu("Go") {
                ForEach(AppSection.allCases) { section in
                    Button(section.title) { navigation?.selectedSection = section }
                        .keyboardShortcut(section.shortcut)
                        .disabled(navigation == nil)
                }
            }
        }
    }
#endif

extension FocusedValues {
    @Entry var fiscalNavigation: FiscalNavigation?
}
