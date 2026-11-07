import FiscalDomain
import Foundation
import Observation

@MainActor @Observable
public final class AboutModel {
    public let lottieURL = URL(string: "https://github.com/airbnb/lottie-ios")

    public init() {}

    public var shareMessage: String { String(appLocalized: "I'm using Fiscal. Take a look.") }
}
