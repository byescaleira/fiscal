import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public struct LensBadge: View {
    @Environment(\.appTint) private var tint
    private let stance: PoliticalStance

    public init(_ stance: PoliticalStance) {
        self.stance = stance
    }

    public var body: some View {
        Label(stance.badge, systemImage: "eyeglasses")
            .font(.chipLabel)
            .foregroundStyle(tint)
            .padding(.horizontal, .spaceM)
            .padding(.vertical, .spaceS)
            .background(tint.opacity(.opacityTint), in: .capsule)
    }
}
