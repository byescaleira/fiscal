import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public struct LensBadge: View {
    @Environment(\.appTint) private var tint

    public init() {}

    public var body: some View {
        Label("For who you support", systemImage: "heart")
            .font(.chipLabel)
            .foregroundStyle(tint)
            .padding(.horizontal, .spaceM)
            .padding(.vertical, .spaceS)
            .background(tint.opacity(.opacityTint), in: .capsule)
    }
}
