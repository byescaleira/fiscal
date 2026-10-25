import SwiftUI

extension ToolbarItemPlacement {
    public static var leading: ToolbarItemPlacement {
        #if os(iOS)
            .topBarLeading
        #else
            .navigation
        #endif
    }
}
