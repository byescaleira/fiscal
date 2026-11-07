import FiscalDesignSystem
import Observation
import SwiftUI

@MainActor @Observable
public final class FiscalNavigation {
    public var selectedSection: AppSection = .feed
    public var paths: [AppSection: [Route]] = [:]
    public var inspector: Inspector?
    public private(set) var layout: ReadingLayout = .stack
    public var panes: [AppSection: [Route]] = [:]
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

    public func pane(for section: AppSection) -> Binding<[Route]> {
        Binding(get: { self.panes[section, default: []] }, set: { self.panes[section] = $0 })
    }

    public func fit(_ context: LayoutContext) {
        let next = ReadingLayout(context)
        guard next != layout else { return }
        let wasFolded = layout.isFolded
        layout = next
        if next.isFolded, !wasFolded {
            moveStacksToPanes()
        } else if !next.isFolded, wasFolded {
            movePanesToStacks()
        }
    }

    public func open(_ route: Route, in section: AppSection) {
        switch layout {
        case .folded:
            selectedSection = section
            panes[section, default: []].append(route)
        case .beside:
            open(route, in: section, beside: true)
        case .stack:
            open(route, in: section, beside: false)
        }
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

    public func closePane(in section: AppSection, all: Bool) {
        if all {
            panes[section] = []
        } else if panes[section]?.isEmpty == false {
            panes[section]?.removeLast()
        }
    }

    public func closeInspectorOutsideSelection() {
        if inspector?.section != selectedSection { closeInspector() }
    }

    public func closeInspector() {
        inspector = nil
        inspectorPath = []
    }

    public var isFree: Bool {
        guide == nil
    }

    public var openRoutes: [Route] {
        paths.values.flatMap(\.self) + panes.values.flatMap(\.self)
            + [inspector?.route].compactMap(\.self) + inspectorPath
    }

    public func reset() {
        paths = [:]
        panes = [:]
        closeInspector()
    }

    private func moveStacksToPanes() {
        for (section, path) in paths where !path.isEmpty {
            panes[section, default: []].append(contentsOf: path)
            paths[section] = []
        }
        if let inspector {
            panes[inspector.section, default: []].append(
                contentsOf: [inspector.route] + inspectorPath)
            closeInspector()
        }
    }

    private func movePanesToStacks() {
        for (section, pane) in panes where !pane.isEmpty {
            paths[section, default: []].append(contentsOf: pane)
        }
        panes = [:]
    }
}
