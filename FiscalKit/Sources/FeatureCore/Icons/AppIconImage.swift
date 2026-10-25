import FiscalResource
import SwiftUI

public struct AppIconImage: View {
    private let icon: AppIcon
    private let size: CGFloat

    public init(icon: AppIcon, size: CGFloat) {
        self.icon = icon
        self.size = size
    }

    public var body: some View {
        FiscalResourceImage.appIcon(icon.previewName)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(.rect(cornerRadius: size * 0.2237, style: .continuous))
            .accessibilityHidden(true)
    }
}
