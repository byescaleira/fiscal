import SwiftUI

public struct FixedToolbarSpacer: ToolbarContent {
    private let placement: ToolbarItemPlacement

    public init(placement: ToolbarItemPlacement = .automatic) {
        self.placement = placement
    }

    public var body: some ToolbarContent {
        #if os(visionOS) || os(tvOS)
            ToolbarItem(placement: placement) { EmptyView() }
        #else
            ToolbarSpacer(.fixed, placement: placement)
        #endif
    }
}
