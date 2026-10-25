import FeatureCore
import SwiftUI

struct TutorialPage: Identifiable {
    let id = UUID()
    let animation: FiscalAnimation
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var steps: [GuideStep] = []
}

extension Guide {
    var pages: [TutorialPage] {
        switch self {
        case .tour: Self.tourPages
        case .appearance: Self.appearancePages
        case .privacy: Self.privacyPages
        }
    }
}
