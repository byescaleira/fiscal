#if os(visionOS)
    import FeatureCore
    import FiscalDesignSystem
    import SwiftUI

    @MainActor
    final class RouteWindows {
        static let shared = RouteWindows()

        struct Entry {
            let route: Route
            let section: AppSection
            let window: FiscalWindow
        }

        private var entries: [UUID: Entry] = [:]

        func store(_ route: Route, in section: AppSection, window: FiscalWindow) -> UUID {
            let id = UUID()
            entries[id] = Entry(route: route, section: section, window: window)
            return id
        }

        func entry(_ id: UUID) -> Entry? {
            entries[id]
        }

        func remove(_ id: UUID) {
            entries[id] = nil
        }
    }

    public struct RouteWindowScreen: View {
        @Environment(\.dismissWindow) private var dismissWindow
        private let id: UUID?

        public init(id: UUID?) {
            self.id = id
        }

        public var body: some View {
            if let id, let entry = RouteWindows.shared.entry(id) {
                RouteWindowStack(entry: entry)
                    .fiscalWindow(entry.window)
                    .environment(OfflineDataCenter.shared.model)
                    .environment(\.explainer, FiscalServices.shared.explainer)
                    .onDisappear { RouteWindows.shared.remove(id) }
            } else {
                Color.clear.onAppear { dismissWindow() }
            }
        }
    }

    private struct RouteWindowStack: View {
        @State private var path: [Route] = []
        let entry: RouteWindows.Entry

        var body: some View {
            NavigationStack(path: $path) {
                RouteScreen(route: entry.route)
                    .navigationDestination(for: Route.self) { RouteScreen(route: $0) }
            }
            .environment(\.navigationSection, entry.section)
            .environment(\.open, FiscalDestination { route, _ in path.append(route) })
            .environment(\.close, CloseAction { if !path.isEmpty { path.removeLast() } })
        }
    }

    struct RouteWindowOpener: ViewModifier {
        @Environment(FiscalNavigation.self) private var navigation
        @Environment(\.openWindow) private var openWindow
        @Environment(\.currentWindow) private var window

        func body(content: Content) -> some View {
            content.onChange(of: navigation.inspector) { _, inspector in
                guard let inspector, let window else { return }
                let id = RouteWindows.shared.store(
                    inspector.route, in: inspector.section, window: window)
                navigation.closeInspector()
                openWindow(value: id)
            }
        }
    }
#endif
