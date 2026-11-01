import AVFoundation
import CoreMedia
import FiscalDesignSystem
import Foundation
import SwiftUI
import Testing

@testable import FeatureShare

@MainActor
@Suite(.serialized, .timeLimit(.minutes(3)))
struct ShareVideoTests {
    private let size = CGSize(width: 360, height: 640)

    private func frame(_ progress: Double) -> AnyView {
        AnyView(
            ZStack {
                Color.plainBackground
                Rectangle()
                    .fill(.tint)
                    .frame(width: 300 * progress, height: 40)
                Text("\(Int(progress * 100))")
                    .font(.system(size: 96, weight: .bold))
                    .foregroundStyle(.primary)
            })
    }

    @Test func writesTheLoopWithTheRequestedFrames() async throws {
        var reported: [Double] = []
        var seen: [Double] = []
        let url = try await ShareVideoRenderer.render(
            size: size, scale: 3, seconds: 4, fps: 30, fileName: "Fiscal - Teste.mp4",
            frame: { progress in
                seen.append(progress)
                return frame(progress)
            },
            progress: { reported.append($0) })
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        #expect(url.lastPathComponent == "Fiscal - Teste.mp4")
        #expect(seen.count == 120)
        #expect(seen.first == 0)
        #expect(seen.last == 1)
        #expect(reported.last == 1)

        let bytes = try #require(
            try FileManager.default.attributesOfItem(atPath: url.path(percentEncoded: false))[.size]
                as? Int)
        #expect(bytes > 0)
        #expect(bytes < 50_000_000)

        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        #expect(abs(duration - 4) < 0.05)
        let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
        let natural = try await track.load(.naturalSize)
        #expect(natural == CGSize(width: 1080, height: 1920))
        let formats = try await track.load(.formatDescriptions)
        #expect(formats.map(\.mediaSubType) == [.h264])
        #expect(try samples(of: asset, track: track) == 120)
    }

    @Test func cancellingRemovesThePartialFile() async throws {
        let folder = FileManager.default.temporaryDirectory
            .appending(path: "FiscalVideoTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appending(path: "Fiscal.mp4")

        await #expect(throws: CancellationError.self) {
            _ = try await ShareVideoRenderer.render(
                to: file, size: CGSize(width: 90, height: 160), scale: 1, seconds: 4, fps: 30,
                frame: { progress in
                    if progress >= 0.5 { withUnsafeCurrentTask { $0?.cancel() } }
                    return frame(progress)
                },
                progress: { _ in })
        }
        #expect(!FileManager.default.fileExists(atPath: file.path(percentEncoded: false)))
    }

    @Test func drawsTheFrameUpright() async throws {
        let url = try await ShareVideoRenderer.render(
            size: CGSize(width: 90, height: 160), scale: 2, seconds: 1, fps: 10,
            frame: { _ in
                AnyView(
                    VStack(spacing: 0) {
                        Rectangle().fill(.white)
                        Rectangle().fill(.black)
                    })
            },
            progress: { _ in })
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let asset = AVURLAsset(url: url)
        let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(
            track: track,
            outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
        reader.add(output)
        #expect(reader.startReading())
        let sample = try #require(output.copyNextSampleBuffer())
        let buffer = try #require(sample.imageBuffer)
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        let base = try #require(CVPixelBufferGetBaseAddress(buffer))
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let column = CVPixelBufferGetWidth(buffer) / 2 * 4
        let top = base.load(fromByteOffset: bytesPerRow * height / 4 + column, as: UInt8.self)
        let bottom = base.load(
            fromByteOffset: bytesPerRow * height * 3 / 4 + column, as: UInt8.self)
        #expect(top > 200)
        #expect(bottom < 60)
    }

    @Test func roundsToEvenPixels() {
        let pixels = ShareVideoRenderer.pixelSize(CGSize(width: 360, height: 640), scale: 3)
        #expect(pixels.width == 1080)
        #expect(pixels.height == 1920)
        let odd = ShareVideoRenderer.pixelSize(CGSize(width: 101, height: 33), scale: 1)
        #expect(odd.width == 100)
        #expect(odd.height == 32)
    }

    private func samples(of asset: AVURLAsset, track: AVAssetTrack) throws -> Int {
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
        reader.add(output)
        #expect(reader.startReading())
        var count = 0
        while let sample = output.copyNextSampleBuffer() {
            count += sample.numSamples
        }
        return count
    }
}
