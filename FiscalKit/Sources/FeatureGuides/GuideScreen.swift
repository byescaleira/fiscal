import FeatureCore
import SwiftUI

public struct GuideScreen: View {
    private let guide: Guide

    public init(_ guide: Guide) {
        self.guide = guide
    }

    public var body: some View {
        TutorialScreen(pages: guide.pages)
    }
}
