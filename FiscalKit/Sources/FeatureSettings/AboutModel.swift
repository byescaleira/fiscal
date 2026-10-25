import FiscalDomain
import Foundation
import Observation

@MainActor @Observable
final class AboutModel {
    let lottieURL = URL(string: "https://github.com/airbnb/lottie-ios")

    var shareMessage: String { String(appLocalized: "I'm using Fiscal. Take a look.") }
}
