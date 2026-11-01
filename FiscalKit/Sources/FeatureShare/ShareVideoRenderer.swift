import AVFoundation
import CoreGraphics
import CoreVideo
import SwiftUI

public enum ShareVideoError: Error, Equatable {
    case cannotStart
    case cannotRender
    case cannotAppend
    case cannotFinish
}

@MainActor
public enum ShareVideoRenderer {
    public static let bitRate = 8_000_000
    static let framesPerBatch = 4

    public static func render(
        size: CGSize, scale: CGFloat, seconds: Double, fps: Int, fileName: String = "Fiscal.mp4",
        frame: (Double) -> AnyView, progress: (Double) -> Void
    ) async throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appending(path: "FiscalVideo", directoryHint: .isDirectory)
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        return try await render(
            to: folder.appending(path: fileName), size: size, scale: scale, seconds: seconds,
            fps: fps, frame: frame, progress: progress)
    }

    static func render(
        to url: URL, size: CGSize, scale: CGFloat, seconds: Double, fps: Int,
        frame: (Double) -> AnyView, progress: (Double) -> Void
    ) async throws -> URL {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
            try FileManager.default.removeItem(at: url)
        }
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        do {
            try await write(
                to: writer, size: size, scale: scale,
                frames: max(1, Int((seconds * Double(fps)).rounded())), fps: fps, frame: frame,
                progress: progress)
            return url
        } catch {
            if writer.status == .writing { writer.cancelWriting() }
            try? FileManager.default.removeItem(at: url)
            throw error
        }
    }

    static func pixelSize(_ size: CGSize, scale: CGFloat) -> (width: Int, height: Int) {
        func even(_ value: CGFloat) -> Int { max(2, Int(value.rounded()) / 2 * 2) }
        return (even(size.width * scale), even(size.height * scale))
    }

    static func settings(width: Int, height: Int, fps: Int) -> [String: Any] {
        [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
            ],
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: bitRate,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoExpectedSourceFrameRateKey: fps,
                AVVideoMaxKeyFrameIntervalKey: fps,
            ],
        ]
    }

    private static func write(
        to writer: AVAssetWriter, size: CGSize, scale: CGFloat, frames: Int, fps: Int,
        frame: (Double) -> AnyView, progress: (Double) -> Void
    ) async throws {
        let pixels = pixelSize(size, scale: scale)
        let input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: settings(width: pixels.width, height: pixels.height, fps: fps))
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: pixels.width,
                kCVPixelBufferHeightKey as String: pixels.height,
                kCVPixelBufferCGImageCompatibilityKey as String: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            ])
        guard writer.canAdd(input) else { throw ShareVideoError.cannotStart }
        writer.add(input)
        writer.shouldOptimizeForNetworkUse = true
        guard writer.startWriting() else { throw writer.error ?? ShareVideoError.cannotStart }
        writer.startSession(atSourceTime: .zero)
        progress(0)
        for index in 0..<frames {
            try Task.checkCancellation()
            let value = frames > 1 ? Double(index) / Double(frames - 1) : 1
            let image = try image(of: frame(value), size: size, scale: scale)
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(for: .milliseconds(2))
            }
            let buffer = try pixelBuffer(from: adaptor, drawing: image, pixels: pixels)
            let time = CMTime(value: CMTimeValue(index), timescale: CMTimeScale(fps))
            guard adaptor.append(buffer, withPresentationTime: time) else {
                throw writer.error ?? ShareVideoError.cannotAppend
            }
            progress(Double(index + 1) / Double(frames))
            if (index + 1).isMultiple(of: framesPerBatch) { await Task.yield() }
        }
        try Task.checkCancellation()
        input.markAsFinished()
        writer.endSession(
            atSourceTime: CMTime(value: CMTimeValue(frames), timescale: CMTimeScale(fps)))
        await withCheckedContinuation { continuation in
            writer.finishWriting { continuation.resume() }
        }
        guard writer.status == .completed else {
            throw writer.error ?? ShareVideoError.cannotFinish
        }
    }

    private static func image(of view: AnyView, size: CGSize, scale: CGFloat) throws -> CGImage {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.proposedSize = ProposedViewSize(size)
        renderer.scale = scale
        guard let image = renderer.cgImage else { throw ShareVideoError.cannotRender }
        return image
    }

    private static func pixelBuffer(
        from adaptor: AVAssetWriterInputPixelBufferAdaptor, drawing image: CGImage,
        pixels: (width: Int, height: Int)
    ) throws -> CVPixelBuffer {
        guard let pool = adaptor.pixelBufferPool else { throw ShareVideoError.cannotAppend }
        var created: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &created) == kCVReturnSuccess,
            let buffer = created
        else { throw ShareVideoError.cannotAppend }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard
            let context = CGContext(
                data: CVPixelBufferGetBaseAddress(buffer), width: pixels.width,
                height: pixels.height, bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                    | CGBitmapInfo.byteOrder32Little.rawValue)
        else { throw ShareVideoError.cannotRender }
        let rect = CGRect(x: 0, y: 0, width: pixels.width, height: pixels.height)
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.fill(rect)
        context.interpolationQuality = .high
        context.draw(image, in: rect)
        return buffer
    }
}
