import Foundation
import Testing

@testable import FeatureSettings

@MainActor
struct AboutModelTests {
    @Test func creditsLottieWithItsRepository() {
        let about = AboutModel()
        #expect(about.lottieURL?.host() == "github.com")
        #expect(about.lottieURL?.lastPathComponent == "lottie-ios")
    }

    @Test func sharesAMessageThatNamesFiscal() {
        #expect(AboutModel().shareMessage.contains("Fiscal"))
    }
}
