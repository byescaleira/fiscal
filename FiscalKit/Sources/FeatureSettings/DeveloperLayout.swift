import FiscalDesignSystem
import FiscalDomain
import Foundation
import SwiftUI

public struct DeveloperLayout: Equatable, Sendable {
    public let sizeText: String
    public let postureText: String
    public let divisionsText: String
    public let verticalBarText: String

    public init(_ context: LayoutContext) {
        sizeText = Self.text(of: context.size)
        postureText = Self.text(of: context.posture)
        divisionsText =
            context.divisions.isEmpty
            ? String(appLocalized: "None")
            : context.divisions.map(Self.text(of:)).joined(separator: "; ")
        verticalBarText = Self.text(of: context.verticalBarEdge)
    }

    static func text(of size: CGSize) -> String {
        "\(Int(size.width.rounded())) × \(Int(size.height.rounded())) pt"
    }

    static func text(of rect: CGRect) -> String {
        "(\(Int(rect.minX.rounded())), \(Int(rect.minY.rounded()))) "
            + text(of: rect.size)
    }

    static func text(of posture: LayoutContext.Posture) -> String {
        switch posture {
        case .flat: String(appLocalized: "Flat")
        case .folded(.horizontal, _): String(appLocalized: "Folded, side by side")
        case .folded(.vertical, _): String(appLocalized: "Folded, stacked")
        }
    }

    static func text(of edge: HorizontalEdge?) -> String {
        switch edge {
        case nil: String(appLocalized: "None")
        case .leading: String(appLocalized: "Leading")
        case .trailing: String(appLocalized: "Trailing")
        }
    }
}
