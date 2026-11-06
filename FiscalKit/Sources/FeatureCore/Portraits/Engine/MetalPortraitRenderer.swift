#if DEBUG
    import CoreGraphics
    import Foundation
    import Metal
    import QuartzCore
    import simd

    enum MetalPortraitError: Error, Equatable {
        case unavailable
        case pipeline(String)
    }

    @MainActor
    final class MetalPortraitRenderer {
        static let sampleCount = 4
        static let colorFormat = MTLPixelFormat.bgra8Unorm
        static let stencilFormat = MTLPixelFormat.depth32Float_stencil8
        static let inFlight = 3
        static let transparent = MTLClearColor()
        private static let millisecondsPerSecond = 1000.0
        private static let gpuHistory = 2_000

        private struct Uniforms {
            var scale: SIMD2<Float>
            var offset: SIMD2<Float>
        }

        private struct Paint {
            var from: SIMD4<Float>
            var to: SIMD4<Float>
            var start: SIMD2<Float>
            var end: SIMD2<Float>
            var opacity: Float
        }

        private enum Cover {
            case solid
            case gradient
        }

        private struct Draw {
            let stencil: Range<Int>
            let cover: Range<Int>
            let isStroke: Bool
            let kind: Cover
            let paint: Paint
        }

        let device: any MTLDevice
        let queue: any MTLCommandQueue
        let preparation: Duration
        private let stencilPipeline: any MTLRenderPipelineState
        private let solidPipeline: any MTLRenderPipelineState
        private let gradientPipeline: any MTLRenderPipelineState
        private let fillStencil: any MTLDepthStencilState
        private let strokeStencil: any MTLDepthStencilState
        private let coverStencil: any MTLDepthStencilState
        private(set) var gpuMilliseconds: [Double] = []
        private var stillTargets: [Int: StillTarget] = [:]

        private struct StillTarget {
            let sampled: any MTLTexture
            let resolved: any MTLTexture
            let stencil: any MTLTexture
            let readback: any MTLBuffer
        }

        private static var cached: Result<MetalPortraitRenderer, MetalPortraitError>?

        static func shared() -> Result<MetalPortraitRenderer, MetalPortraitError> {
            if let cached { return cached }
            let result: Result<MetalPortraitRenderer, MetalPortraitError>
            do {
                result = .success(try MetalPortraitRenderer())
            } catch let error as MetalPortraitError {
                result = .failure(error)
            } catch {
                result = .failure(.pipeline(error.localizedDescription))
            }
            cached = result
            return result
        }

        init() throws {
            let clock = ContinuousClock()
            let started = clock.now
            guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue()
            else { throw MetalPortraitError.unavailable }
            self.device = device
            self.queue = queue
            do {
                let library = try device.makeDefaultLibrary(bundle: .module)
                stencilPipeline = try Self.pipeline(device, library, fragment: nil)
                solidPipeline = try Self.pipeline(device, library, fragment: "portraitSolid")
                gradientPipeline = try Self.pipeline(device, library, fragment: "portraitGradient")
            } catch {
                throw MetalPortraitError.pipeline(String(describing: error))
            }
            guard let fill = Self.stencilState(device, front: .incrementWrap, back: .decrementWrap),
                let stroke = Self.stencilState(device, front: .replace, back: .replace),
                let cover = Self.coverState(device)
            else { throw MetalPortraitError.pipeline("depth stencil state") }
            fillStencil = fill
            strokeStencil = stroke
            coverStencil = cover
            preparation = clock.now - started
        }

        func encode(
            _ frame: PortraitFrame, into encoder: any MTLRenderCommandEncoder,
            buffers: MetalPortraitBuffers
        ) {
            let (vertices, draws) = Self.geometry(frame)
            guard let buffer = buffers.next(device: device, vertices: vertices), !draws.isEmpty
            else { return }
            var uniforms = Uniforms(
                scale: SIMD2(Float(2 / frame.size.width), Float(-2 / frame.size.height)),
                offset: SIMD2(-1, 1))
            encoder.setCullMode(.none)
            encoder.setVertexBuffer(buffer, offset: 0, index: 0)
            encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
            for draw in draws {
                encoder.setRenderPipelineState(stencilPipeline)
                encoder.setDepthStencilState(draw.isStroke ? strokeStencil : fillStencil)
                encoder.setStencilReferenceValue(1)
                encoder.drawPrimitives(
                    type: .triangle, vertexStart: draw.stencil.lowerBound,
                    vertexCount: draw.stencil.count)
                encoder.setRenderPipelineState(
                    draw.kind == .gradient ? gradientPipeline : solidPipeline)
                encoder.setDepthStencilState(coverStencil)
                encoder.setStencilReferenceValue(0)
                var paint = draw.paint
                encoder.setFragmentBytes(&paint, length: MemoryLayout<Paint>.stride, index: 0)
                encoder.drawPrimitives(
                    type: .triangle, vertexStart: draw.cover.lowerBound,
                    vertexCount: draw.cover.count)
            }
        }

        func track(_ commandBuffer: any MTLCommandBuffer, buffers: MetalPortraitBuffers) {
            let gate = buffers.gate
            let scale = Self.millisecondsPerSecond
            commandBuffer.addCompletedHandler { [weak self] finished in
                let milliseconds = (finished.gpuEndTime - finished.gpuStartTime) * scale
                gate.signal()
                Task { @MainActor in self?.record(milliseconds) }
            }
        }

        func resetMeasurements() {
            gpuMilliseconds.removeAll(keepingCapacity: true)
        }

        func still(_ frame: PortraitFrame, side: Int) -> CGImage? {
            guard side > 0, let target = stillTarget(side), let commands = queue.makeCommandBuffer()
            else { return nil }
            let (sampled, resolved, stencil, readback) = (
                target.sampled, target.resolved, target.stencil, target.readback
            )
            let pass = MTLRenderPassDescriptor()
            pass.colorAttachments[0].texture = sampled
            pass.colorAttachments[0].resolveTexture = resolved
            pass.colorAttachments[0].loadAction = .clear
            pass.colorAttachments[0].clearColor = Self.transparent
            pass.colorAttachments[0].storeAction = .multisampleResolve
            pass.depthAttachment.texture = stencil
            pass.depthAttachment.loadAction = .clear
            pass.depthAttachment.storeAction = .dontCare
            pass.stencilAttachment.texture = stencil
            pass.stencilAttachment.loadAction = .clear
            pass.stencilAttachment.clearStencil = 0
            pass.stencilAttachment.storeAction = .dontCare
            guard let encoder = commands.makeRenderCommandEncoder(descriptor: pass) else {
                return nil
            }
            let buffers = MetalPortraitBuffers(count: 1)
            encode(frame, into: encoder, buffers: buffers)
            encoder.endEncoding()
            guard let blit = commands.makeBlitCommandEncoder() else { return nil }
            blit.copy(
                from: resolved, sourceSlice: 0, sourceLevel: 0,
                sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                sourceSize: MTLSize(width: side, height: side, depth: 1), to: readback,
                destinationOffset: 0, destinationBytesPerRow: side * 4,
                destinationBytesPerImage: side * side * 4)
            blit.endEncoding()
            commands.commit()
            commands.waitUntilCompleted()
            buffers.gate.signal()
            let data = Data(bytes: readback.contents(), count: side * side * 4)
            guard let provider = CGDataProvider(data: data as CFData),
                let space = CGColorSpace(name: CGColorSpace.sRGB)
            else { return nil }
            return CGImage(
                width: side, height: side, bitsPerComponent: 8, bitsPerPixel: 32,
                bytesPerRow: side * 4, space: space,
                bitmapInfo: CGBitmapInfo(
                    rawValue: CGBitmapInfo.byteOrder32Little.rawValue
                        | CGImageAlphaInfo.premultipliedFirst.rawValue),
                provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        }

        private func stillTarget(_ side: Int) -> StillTarget? {
            if let known = stillTargets[side] { return known }
            guard
                let sampled = texture(side, sampleCount: Self.sampleCount, format: Self.colorFormat),
                let resolved = texture(side, sampleCount: 1, format: Self.colorFormat),
                let stencil = texture(side, sampleCount: Self.sampleCount, format: Self.stencilFormat),
                let readback = device.makeBuffer(length: side * side * 4, options: .storageModeShared)
            else { return nil }
            let target = StillTarget(
                sampled: sampled, resolved: resolved, stencil: stencil, readback: readback)
            stillTargets[side] = target
            return target
        }

        private func record(_ milliseconds: Double) {
            if gpuMilliseconds.count >= Self.gpuHistory { gpuMilliseconds.removeFirst() }
            gpuMilliseconds.append(milliseconds)
        }

        private func texture(_ side: Int, sampleCount: Int, format: MTLPixelFormat)
            -> (any MTLTexture)?
        {
            let descriptor = MTLTextureDescriptor()
            descriptor.textureType = sampleCount > 1 ? .type2DMultisample : .type2D
            descriptor.pixelFormat = format
            descriptor.width = side
            descriptor.height = side
            descriptor.sampleCount = sampleCount
            descriptor.storageMode = .private
            descriptor.usage = .renderTarget
            return device.makeTexture(descriptor: descriptor)
        }
    }

    extension MetalPortraitRenderer {
        private static func geometry(_ frame: PortraitFrame) -> ([SIMD2<Float>], [Draw]) {
            var vertices: [SIMD2<Float>] = []
            var draws: [Draw] = []
            vertices.reserveCapacity(frame.points.count * 4)
            var stroke: [CGPoint] = []
            for item in frame.items {
                let start = vertices.count
                var low = SIMD2<Float>(repeating: .greatestFiniteMagnitude)
                var high = SIMD2<Float>(repeating: -.greatestFiniteMagnitude)
                func add(_ point: CGPoint) {
                    let vertex = SIMD2(Float(point.x), Float(point.y))
                    low = simd_min(low, vertex)
                    high = simd_max(high, vertex)
                    vertices.append(vertex)
                }
                let isStroke: Bool
                if case .stroke(_, let width) = item.paint {
                    isStroke = true
                    for contour in item.contours {
                        stroke.removeAll(keepingCapacity: true)
                        PortraitStroke.append(
                            frame.points[contour.range], closed: contour.closed, width: width,
                            to: &stroke)
                        stroke.forEach(add)
                    }
                } else {
                    isStroke = false
                    for contour in item.contours where contour.range.count >= 3 {
                        let anchor = frame.points[contour.range.lowerBound]
                        for index in (contour.range.lowerBound + 1)..<(contour.range.upperBound - 1) {
                            add(anchor)
                            add(frame.points[index])
                            add(frame.points[index + 1])
                        }
                    }
                }
                guard vertices.count > start else { continue }
                let coverStart = vertices.count
                vertices += [
                    low, SIMD2(high.x, low.y), SIMD2(low.x, high.y),
                    SIMD2(low.x, high.y), SIMD2(high.x, low.y), high,
                ]
                draws.append(
                    Draw(
                        stencil: start..<coverStart, cover: coverStart..<vertices.count,
                        isStroke: isStroke, kind: kind(item.paint),
                        paint: paint(item.paint, item.opacity)))
            }
            return (vertices, draws)
        }

        private static func kind(_ paint: PortraitDrawItem.Paint) -> Cover {
            if case .gradient = paint { return .gradient }
            return .solid
        }

        private static func paint(_ paint: PortraitDrawItem.Paint, _ opacity: Double) -> Paint {
            func color(_ rgba: PortraitRGBA) -> SIMD4<Float> {
                SIMD4(Float(rgba.red), Float(rgba.green), Float(rgba.blue), Float(rgba.alpha))
            }
            switch paint {
            case .fill(let rgba), .stroke(let rgba, _):
                return Paint(
                    from: color(rgba), to: color(rgba), start: .zero, end: .zero,
                    opacity: Float(opacity))
            case .gradient(let start, let end, let from, let to):
                return Paint(
                    from: color(from), to: color(to), start: SIMD2(Float(start.x), Float(start.y)),
                    end: SIMD2(Float(end.x), Float(end.y)), opacity: Float(opacity))
            }
        }

        private static func pipeline(
            _ device: any MTLDevice, _ library: any MTLLibrary, fragment: String?
        ) throws -> any MTLRenderPipelineState {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: "portraitVertex")
            descriptor.fragmentFunction = fragment.flatMap { library.makeFunction(name: $0) }
            descriptor.rasterSampleCount = sampleCount
            descriptor.depthAttachmentPixelFormat = stencilFormat
            descriptor.stencilAttachmentPixelFormat = stencilFormat
            let color = descriptor.colorAttachments[0]
            color?.pixelFormat = colorFormat
            if fragment == nil {
                color?.writeMask = []
            } else {
                color?.isBlendingEnabled = true
                color?.sourceRGBBlendFactor = .one
                color?.sourceAlphaBlendFactor = .one
                color?.destinationRGBBlendFactor = .oneMinusSourceAlpha
                color?.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            }
            return try device.makeRenderPipelineState(descriptor: descriptor)
        }

        private static func stencilState(
            _ device: any MTLDevice, front: MTLStencilOperation, back: MTLStencilOperation
        ) -> (any MTLDepthStencilState)? {
            let descriptor = MTLDepthStencilDescriptor()
            descriptor.frontFaceStencil = stencil(.always, pass: front)
            descriptor.backFaceStencil = stencil(.always, pass: back)
            return device.makeDepthStencilState(descriptor: descriptor)
        }

        private static func coverState(_ device: any MTLDevice) -> (any MTLDepthStencilState)? {
            let descriptor = MTLDepthStencilDescriptor()
            descriptor.frontFaceStencil = stencil(.notEqual, pass: .zero)
            descriptor.backFaceStencil = stencil(.notEqual, pass: .zero)
            return device.makeDepthStencilState(descriptor: descriptor)
        }

        private static func stencil(_ compare: MTLCompareFunction, pass: MTLStencilOperation)
            -> MTLStencilDescriptor
        {
            let descriptor = MTLStencilDescriptor()
            descriptor.stencilCompareFunction = compare
            descriptor.stencilFailureOperation = .keep
            descriptor.depthFailureOperation = .keep
            descriptor.depthStencilPassOperation = pass
            return descriptor
        }
    }

    @MainActor
    final class MetalPortraitBuffers {
        let gate: DispatchSemaphore
        private var buffers: [(any MTLBuffer)?]
        private var index = 0

        init(count: Int = MetalPortraitRenderer.inFlight) {
            buffers = Array(repeating: nil, count: count)
            gate = DispatchSemaphore(value: count)
        }

        func next(device: any MTLDevice, vertices: [SIMD2<Float>]) -> (any MTLBuffer)? {
            gate.wait()
            let length = vertices.count * MemoryLayout<SIMD2<Float>>.stride
            index = (index + 1) % buffers.count
            if (buffers[index]?.length ?? 0) < max(length, 1) {
                buffers[index] = device.makeBuffer(
                    length: max(length, 1) * 2, options: .storageModeShared)
            }
            guard let buffer = buffers[index] else { return nil }
            vertices.withUnsafeBytes { bytes in
                guard let base = bytes.baseAddress else { return }
                buffer.contents().copyMemory(from: base, byteCount: length)
            }
            return buffer
        }
    }
#endif
