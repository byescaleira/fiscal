import FeatureCore
import FiscalDesignSystem
import SwiftUI

extension ProfileModel {
    public var numbersExplanation: Explanation? {
        guard let numbers = profile?.numbers else { return nil }
        let explanation = Explanation.term(numbers)
        return explanation.isEmpty ? nil : explanation
    }
}

struct ProfileNumbersExplainer: View {
    @Environment(ProfileModel.self) private var profile

    var body: some View {
        if let explanation = profile.numbersExplanation {
            ExplainerCard(explanation)
                .padding(.spaceM)
                .background(.groupedRow, in: .rect(cornerRadius: .radiusM))
                .padding(.top, .spaceS)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
    }
}
