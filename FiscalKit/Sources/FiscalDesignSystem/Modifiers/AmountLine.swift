import SwiftUI

extension View {
    public func amountLine() -> some View {
        lineLimit(1).minimumScaleFactor(0.5).allowsTightening(true).privacySensitive()
    }
}
