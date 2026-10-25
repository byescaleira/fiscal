import CoreGraphics
import Foundation
import Lottie
import QuartzCore

@MainActor
enum PortraitStill {
    static func render(_ animation: LottieAnimation, side: CGFloat) -> CGImage? {
        let size = animation.size
        guard size.width > 0, size.height > 0, side > 0,
            let space = CGColorSpace(name: CGColorSpace.sRGB)
        else { return nil }
        let layer = LottieAnimationLayer(
            animation: animation, configuration: LottieConfiguration(renderingEngine: .mainThread))
        layer.frame = CGRect(origin: .zero, size: size)
        layer.currentProgress = 0
        for sublayer in layer.sublayers ?? [] {
            sublayer.position = CGPoint(x: layer.bounds.midX, y: layer.bounds.midY)
        }
        layer.forceDisplayUpdate()
        let pixels = Int(side.rounded())
        guard
            let context = CGContext(
                data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        let scale = side / max(size.width, size.height)
        context.translateBy(x: 0, y: side)
        context.scaleBy(x: scale, y: -scale)
        layer.render(in: context)
        return context.makeImage()
    }
}
