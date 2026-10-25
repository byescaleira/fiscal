import FiscalDesignSystem
import Observation
import SwiftUI

@MainActor @Observable
public final class FiscalNavigation {
    public var selectedSection: AppSection = .home
    public var paths: [AppSection: [Route]] = [:]
    public var inspector: Inspector?
    public private(set) var opensBeside = false
    public var inspectorPath: [Route] = []
    public var guide: Guide?
    public init() {}

    public struct Inspector: Identifiable, Equatable {
        public let id = UUID()
        public let route: Route
        public let section: AppSection
    }

    public func path(for section: AppSection) -> Binding<[Route]> {
        Binding(get: { self.paths[section, default: []] }, set: { self.paths[section] = $0 })
    }

    public var isInspecting: Binding<Bool> {
        Binding(get: { self.inspector != nil }, set: { if !$0 { self.closeInspector() } })
    }

    public func fit(width: CGFloat) {
        opensBeside = Self.opensRoutesBeside && width >= .readableColumn + .inspectorIdeal
    }

    public func open(_ route: Route, in section: AppSection) {
        open(route, in: section, beside: opensBeside)
    }

    public func open(_ route: Route, in section: AppSection, beside: Bool) {
        if inspector != nil {
            inspectorPath.append(route)
            return
        }
        selectedSection = section
        if beside {
            inspectorPath = []
            inspector = Inspector(route: route, section: section)
        } else {
            paths[section, default: []].append(route)
        }
    }

    public func close(in section: AppSection, inspecting: Bool) {
        if inspecting {
            if inspectorPath.isEmpty { closeInspector() } else { inspectorPath.removeLast() }
        } else if paths[section]?.isEmpty == false {
            paths[section]?.removeLast()
        }
    }

    public func closeInspectorOutsideSelection() {
        if inspector?.section != selectedSection { closeInspector() }
    }

    public func closeInspector() {
        inspector = nil
        inspectorPath = []
    }

    public func reset() {
        paths = [:]
        closeInspector()
    }

    static var opensRoutesBeside: Bool {
        #if os(tvOS)
            false
        #else
            true
        #endif
    }
}
