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
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.liteMode) private var liteMode
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
        .animation(splashAnimation, value: launch.isDismissed)
        .sheet(item: $navigation.guide) { GuideScreen($0) }
        .environment(\.showGuide, ShowGuideAction { navigation.guide = $0 })
        .routeInspector(isPresented: navigation.isInspecting) {
            if let inspector = navigation.inspector {
                InspectorScreen(inspector: inspector)
            }
        }
        .onChange(of: navigation.inspector) { AccessibilityNotification.ScreenChanged(nil).post() }
        .modifier(RoutesBeside())
        .readsLayoutContext()
        .environment(
            \.open,
            FiscalDestination { route, section in
                navigation.open(route, in: section)
            }
        )
        .environment(\.explainer, FiscalServices.shared.explainer)
        .onChange(of: session.generation, initial: true) { launch.finish(.content) }
        .task { await session.start() }
        .task(id: launch.isComplete) {
            try? await Task.sleep(for: launch.isComplete ? .milliseconds(600) : .seconds(8))
            launch.dismiss()
        }
        .onChange(of: navigation.selectedSection) { navigation.closeInspectorOutsideSelection() }
        .modifier(DeepLinks())
        .modifier(UpdateRecommendation())
        .lensExperience(isReady: launch.isDismissed)
        .modifier(LensSetupCover())
        .modifier(SystemIntegrations())
        .environment(OfflineDataCenter.shared.model)
        .task(id: launch.isDismissed) {
            guard launch.isDismissed else { return }
            await OfflineDataCenter.shared.refreshIfDue()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: Task { await OfflineDataCenter.shared.refreshIfDue() }
            case .background: OfflineDataCenter.shared.scheduleBackgroundRefresh()
            default: break
            }
        }
    }

    private var splashAnimation: Animation {
        systemReduceMotion || liteMode.reducesMotion
            ? .splashQuiet : .splashDismiss
    }
}

private struct RoutesBeside: ViewModifier {
    @Environment(FiscalNavigation.self) private var navigation
    @Environment(\.layoutContext) private var context

    func body(content: Content) -> some View {
        content.onChange(of: context, initial: true) { navigation.fit(context) }
    }
}

private struct LensSetupCover: ViewModifier {
    @Environment(FiscalNavigation.self) private var navigation
    @Environment(SessionModel.self) private var session

    func body(content: Content) -> some View {
        @Bindable var navigation = navigation
        #if os(macOS)
            content.sheet(isPresented: $navigation.isShowingLensSetup) {
                flow
                    .frame(minWidth: .readableColumn, minHeight: .readableColumn)
                    .interactiveDismissDisabled()
            }
        #else
            content.fullScreenCover(isPresented: $navigation.isShowingLensSetup) { flow }
        #endif
    }

    private var flow: some View {
        LensSetupFlow(
            service: FiscalServices.shared.publicData(), follows: session.repositories.follows)
    }
}
