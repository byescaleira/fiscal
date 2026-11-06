#if DEBUG
    import Foundation

    enum PortraitSceneError: Error, Equatable {
        case unsupported(String)
        case malformed(String)
    }

    struct PortraitTrack: Sendable {
        let width: Int
        private let frames: [Double]
        private let values: [Double]

        init(constant: [Double]) {
            width = constant.count
            frames = [0]
            values = constant
        }

        init(frames: [Double], values: [[Double]]) throws {
            guard let first = values.first, frames.count == values.count, !frames.isEmpty,
                values.allSatisfy({ $0.count == first.count })
            else { throw PortraitSceneError.malformed("keyframes") }
            width = first.count
            self.frames = frames
            self.values = values.flatMap { $0 }
        }

        var isAnimated: Bool { frames.count > 1 }

        var keyValues: [[Double]] {
            stride(from: 0, to: values.count, by: width).map { Array(values[$0..<$0 + width]) }
        }

        func write(at frame: Double, into buffer: inout [Double], at offset: Int) {
            guard frames.count > 1, frame > frames[0] else {
                copy(key: 0, into: &buffer, at: offset)
                return
            }
            guard frame < frames[frames.count - 1] else {
                copy(key: frames.count - 1, into: &buffer, at: offset)
                return
            }
            var low = 0
            var high = frames.count - 1
            while high - low > 1 {
                let middle = (low + high) / 2
                if frames[middle] <= frame { low = middle } else { high = middle }
            }
            let amount = (frame - frames[low]) / (frames[high] - frames[low])
            let start = low * width
            let end = high * width
            for index in 0..<width {
                let first = values[start + index]
                buffer[offset + index] = first + (values[end + index] - first) * amount
            }
        }

        func value(at frame: Double) -> [Double] {
            var buffer = [Double](repeating: 0, count: width)
            write(at: frame, into: &buffer, at: 0)
            return buffer
        }

        private func copy(key: Int, into buffer: inout [Double], at offset: Int) {
            for index in 0..<width { buffer[offset + index] = values[key * width + index] }
        }
    }
#endif
