import FeatureCore
import FeatureGuides
import FeatureLens
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public struct MainScreen: View {
    @Environment(SessionModel.self) private var session
    @Environment(FiscalNavigation.self) private var navigation
    @Environment(LaunchProgress.self) private var launch
    @Environment(\.featureFlags) private var flags
    @Environment(\.locale) private var locale
    public init() {}

    @ViewBuilder
    public var body: some View {
        @Bindable var navigation = navigation
        TabView(selection: $navigation.selectedSection) {
            ForEach(AppSection.allCases) { section in
                Tab(
                    section.title, systemImage: section.systemImage, value: section,
                    role: section.role
                ) {
                    SectionStack(section: section)
                }
            }
        }
        .id(locale.identifier)
        .tabViewStyle(.sidebarAdaptable)
        .overlay {
            if !launch.isDismissed {
                SplashScreen(progress: launch.fraction, status: launch.status)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.4), value: launch.isDismissed)
        .sheet(item: $navigation.guide) { GuideScreen($0) }
        .environment(\.showGuide, ShowGuideAction { navigation.guide = $0 })
        .routeInspector(isPresented: navigation.isInspecting) {
            if let inspector = navigation.inspector {
                InspectorScreen(inspector: inspector)
            }
        }
        .onGeometryChange(for: CGFloat.self) {
            $0.size.width
        } action: {
            navigation.fit(width: $0)
        }
        .environment(
            \.open,
            FiscalDestination { route, section in
                navigation.open(route, in: section)
            }
        )
        .onChange(of: session.generation, initial: true) { launch.finish(.content) }
        .task(id: launch.isComplete) {
            try? await Task.sleep(for: launch.isComplete ? .milliseconds(600) : .seconds(8))
            launch.dismiss()
        }
        .onChange(of: navigation.selectedSection) { navigation.closeInspectorOutsideSelection() }
        .modifier(DeepLinks())
        .modifier(UpdateRecommendation())
        .lensExperience(isReady: launch.isDismissed)
    }
}
