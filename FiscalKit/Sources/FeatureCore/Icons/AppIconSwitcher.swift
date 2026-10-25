import Foundation

#if canImport(UIKit)
    import UIKit
#endif

@MainActor
public protocol AppIconSwitching {
    var supportsAlternateIcons: Bool { get }
    var current: AppIcon { get }
    func set(_ icon: AppIcon) async throws
}

@MainActor
public struct SystemAppIconSwitcher: AppIconSwitching {
    public init() {}

    public var supportsAlternateIcons: Bool {
        #if os(iOS)
            UIApplication.shared.supportsAlternateIcons
        #else
            false
        #endif
    }

    public var current: AppIcon {
        #if os(iOS)
            AppIcon(assetName: UIApplication.shared.alternateIconName)
        #else
            .standard
        #endif
    }

    public func set(_ icon: AppIcon) async throws {
        #if os(iOS)
            try await UIApplication.shared.setAlternateIconName(icon.assetName)
        #endif
    }
}
