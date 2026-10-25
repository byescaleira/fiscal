import FeatureCore
import SwiftUI

struct TutorialScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    let pages: [TutorialPage]
    var onFinish: () -> Void = {}

    var body: some View {
        let isLast = index == pages.count - 1
        GuideSheet(
            index: index, count: pages.count, back: index > 0 ? { index -= 1 } : nil,
            primary: GuideAction(isLast ? "Done" : "Continue") {
                if isLast {
                    onFinish()
                    dismiss()
                } else {
                    index += 1
                }
            },
            secondary: isLast ? nil : GuideAction("Skip") { dismiss() }
        ) {
            TutorialPageView(page: pages[index])
        }
    }
}

private struct TutorialPageView: View {
    let page: TutorialPage

    var body: some View {
        GuidePage(title: page.title, message: page.message) {
            FiscalAnimationView(page.animation)
        } content: {
            if !page.steps.isEmpty { GuideSteps(page.steps) }
        }
    }
}
