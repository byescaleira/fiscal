import FeatureCore
import FiscalDesignSystem
import SwiftUI

extension VoteDetailModel {
    public var explanation: Explanation? {
        vote.map { Explanation.vote($0, requiredYes: requiredYes) }
    }
}

struct VoteExplainSection: View {
    @Environment(VoteDetailModel.self) private var vote

    var body: some View {
        if let explanation = vote.explanation, !explanation.isEmpty {
            Section {
                ExplainerCard(explanation)
            }
        }
    }
}
