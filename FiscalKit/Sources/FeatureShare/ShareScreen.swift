import FeatureCore
import FiscalDesignSystem
import SwiftUI

public struct ShareScreen: View {
    private let subject: ShareSubject

    public init(subject: ShareSubject) {
        self.subject = subject
    }

    public var body: some View {
        ContentUnavailableView(
            "Share card", systemImage: "square.and.arrow.up",
            description: Text("The card for this page is on its way.")
        )
        .fontDesign(.rounded)
        .navigationTitle("Share")
    }
}
