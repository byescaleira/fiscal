import FiscalDesignSystem
import SwiftUI
import Testing

@MainActor
struct QuietBounceTests {
    @Test func rendersASymbolWithTheQuietBounce() {
        let renderer = ImageRenderer(
            content: Image(systemName: "line.3.horizontal.decrease").quietBounce(value: 1))
        #expect(renderer.cgImage != nil)
    }
}
