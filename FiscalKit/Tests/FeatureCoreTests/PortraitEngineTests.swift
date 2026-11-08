#if DEBUG
    import CoreGraphics
    import FiscalDesignSystem
    import FiscalResource
    import Foundation
    import Metal
    import Testing

    @testable import FeatureCore

    @MainActor
    struct PortraitEngineTests {
        static let paritySide = 480
        static let parityMean = 0.015
        static let parityTail = 0.12
        static let parityPeople: [(String, String)] = [
            ("abade-barao-de-cocais-mg", "PSD"), ("fernando-breno-coromandel-mg", "PRD"),
            ("adriana-ventura", "NOVO"), ("ailton-da-caixa-sao-jose-do-goiabal-mg", "PL"),
            ("barros-munhoz", "PSDB"), ("bruna-rodrigues", "PC do B"), ("dani-cunha", "PL"),
            ("silvana-medeiros-santo-andre-sp", "AVANTE"), ("ana-elisa", "PT"),
            ("damiao-feliciano", "UNIÃO"), ("abnadar-portela-capinzal-do-norte-ma", "REPUBLICANOS"),
            ("abraao-lincon-agua-doce-do-norte-es", "PSB"), ("abrahao-moura-paripueira-al", "MDB"),
            ("accioly-sao-raimundo-das-mangabeiras-ma", "PP"),
            ("adair-fracaro-cardoso-capao-do-cipo-rs", "PDT"), ("adelcino-lopo", "PODE"),
            ("adonaldo-cassiano-santana-do-piaui-pi", "SOLIDARIEDADE"),
            ("ailton-de-dovinha-coronel-murta-mg", "MOBILIZA"),
            ("alcemir-moreira-santa-barbara-mg", "CIDADANIA"), ("alessandra-campelo", "PSC"),
            ("alice-portugal", "PCdoB"), ("aliel-machado", "PV"), ("alisson-wandscheer", "PROS"),
            ("ana-paula-siqueira", "REDE"), ("pessoa-sem-tracos", "PSD"),
        ]

        private func scene(_ slug: String = "eduardo-riedel", _ party: String = "PP") throws
            -> PortraitScene
        {
            try PortraitLabModel.scene(.bundled, slug, party).get()
        }

        @Test func trackInterpolatesLinearlyAndHoldsTheEdges() throws {
            let track = try PortraitTrack(frames: [10, 20], values: [[0, 100], [10, 200]])
            #expect(track.value(at: 15) == [5, 150])
            #expect(track.value(at: 0) == [0, 100])
            #expect(track.value(at: 99) == [10, 200])
            #expect(PortraitTrack(constant: [3]).value(at: 42) == [3])
            #expect(throws: PortraitSceneError.malformed("keyframes")) {
                try PortraitTrack(frames: [0, 1], values: [[0], [1, 2]])
            }
        }

        @Test(arguments: PortraitLabPerson.allCases)
        func bundledRigFitsTheSubset(person: PortraitLabPerson) throws {
            let scene = try scene(person.slug, person.party)
            #expect(scene.size == CGSize(width: 200, height: 200))
            #expect(scene.markers[PortraitMixer.idle] != nil)
            for expression in PortraitExpression.allCases {
                #expect(scene.markers[expression.marker] != nil, "\(expression)")
                #expect(scene.markers[expression.poseMarker] != nil, "\(expression)")
            }
            #expect(!scene.frame(scene.sample(at: 0)).items.isEmpty)
        }

        @Test func featureOutsideTheSubsetIsNamed() {
            let layer: [String: Any] = [
                "ty": 4, "ind": 1, "ip": 0, "op": 10, "ks": [:], "masksProperties": [],
            ]
            #expect(throws: PortraitSceneError.unsupported("layer key masksProperties")) {
                try PortraitScene(document: ["w": 200, "h": 200, "fr": 30, "layers": [layer]])
            }
            let hold: [String: Any] = [
                "ty": 3, "ind": 1, "ip": 0, "op": 10,
                "ks": ["o": ["a": 1, "k": [["t": 0, "s": [0], "h": 1], ["t": 5, "s": [100]]]]],
            ]
            #expect(throws: PortraitSceneError.unsupported("hold keyframe")) {
                try PortraitScene(document: ["w": 200, "h": 200, "fr": 30, "layers": [hold]])
            }
            let radial: [String: Any] = [
                "ty": 4, "ind": 1, "ip": 0, "op": 10, "ks": [:],
                "shapes": [["ty": "gf", "t": 2, "r": 1]],
            ]
            #expect(throws: PortraitSceneError.unsupported("radial gradient")) {
                try PortraitScene(document: ["w": 200, "h": 200, "fr": 30, "layers": [radial]])
            }
        }

        @Test func curvesKeepTheirPointCountWhileTheMouthMoves() throws {
            let scene = try scene()
            let rest = scene.frame(scene.sample(at: 0))
            let smile = scene.frame(scene.sample(at: 100))
            #expect(rest.points.count == smile.points.count)
            #expect(rest.points != smile.points)
        }

        @Test func lookMovesTheEyesAndTiltTurnsTheHead() throws {
            let scene = try scene()
            let sample = scene.sample(at: 0)
            let eyes = try #require(scene.nodes.firstIndex { $0.name == "eyes" })
            let head = try #require(scene.nodes.firstIndex { $0.name == "head" })
            var still = [CGAffineTransform?](repeating: nil, count: scene.nodes.count)
            var moved = still
            let offsets = PortraitOffsets(turn: 2, eyeX: 3, eyeY: 1, roll: 4)
            let eyesStill = scene.world(eyes, sample, .zero, &still)
            let eyesMoved = scene.world(eyes, sample, offsets, &moved)
            #expect(eyesMoved != eyesStill)
            let headStill = scene.world(head, sample, .zero, &still)
            let headMoved = scene.world(head, sample, offsets, &moved)
            #expect(abs(atan2(headMoved.b, headMoved.a) - atan2(headStill.b, headStill.a)) > 0.06)
        }

        @Test func strokeBecomesQuadsAndRoundDiscs() {
            let disc = PortraitStroke.stepsPerHalfTurn * 2 * 3
            let line = PortraitStroke.triangles(
                [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 0)], closed: false, width: 2)
            #expect(line.count == 6 + 2 * disc)
            let corner = PortraitStroke.triangles(
                [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 0), CGPoint(x: 10, y: 10)], closed: false,
                width: 2)
            #expect(corner.count == 12 + 3 * disc)
            #expect(
                PortraitStroke.triangles([CGPoint(x: 1, y: 1)], closed: false, width: 0).isEmpty)
        }

        @Test func tapReactsAndReturnsToIdleWithoutAJump() throws {
            let scene = try scene()
            var draws = [0.0, 0.5]
            let mixer = PortraitMixer(scene: scene) { draws.removeFirst() }
            mixer.apply(.tap, at: 10)
            #expect(mixer.currentMarker == "wave")
            let wave = try #require(scene.markers["wave"])
            #expect(mixer.frameNumber(at: 11) == wave.start + scene.frameRate)
            mixer.apply(.tap, at: 11)
            #expect(mixer.currentMarker == "smile")
            let middle = mixer.sample(at: 11 + PortraitMixer.switchBlend / 2)
            let smile = try #require(scene.markers["smile"])
            let pureSmile = scene.sample(
                at: smile.start + scene.frameRate * PortraitMixer.switchBlend / 2)
            #expect(middle != pureSmile)
            #expect(middle != scene.sample(at: 0))
            #expect(mixer.isActing(at: 11.1))
            _ = mixer.sample(at: 11 + smile.duration / scene.frameRate + 0.01)
            #expect(mixer.currentMarker == PortraitMixer.idle)
        }

        @Test func holdThinksUntilReleased() throws {
            let scene = try scene()
            let mixer = PortraitMixer(scene: scene)
            mixer.apply(.holdBegan, at: 0)
            #expect(mixer.currentMarker == PortraitMixer.think)
            let loop = try #require(scene.markers[PortraitMixer.thinkLoop])
            let later = mixer.frameNumber(at: 30)
            #expect(later >= loop.start && later <= loop.end)
            mixer.apply(.tap, at: 30)
            #expect(mixer.currentMarker == PortraitMixer.think)
            mixer.apply(.holdEnded, at: 31)
            #expect(mixer.currentMarker == PortraitMixer.idle)
            #expect(mixer.isActing(at: 31 + PortraitMixer.releaseBlend / 2))
            let halfway = PortraitMixer.releaseBlend / 2
            let idle = try #require(scene.markers[PortraitMixer.idle])
            #expect(
                mixer.sample(at: 31 + halfway)
                    != scene.sample(at: idle.start + halfway * scene.frameRate))
        }

        @Test func lookAndTiltStayInsideWhatTheRigAlreadyDoes() throws {
            let scene = try scene()
            let mixer = PortraitMixer(scene: scene)
            let limits = mixer.limits
            #expect(limits.turn > 0)
            #expect(limits.eyeX > 0)
            #expect(limits.roll > 0)
            mixer.apply(.look(CGPoint(x: 5, y: -5)), at: 0)
            let looking = mixer.offsets(at: 0)
            #expect(looking.turn == limits.turn)
            #expect(looking.eyeX == limits.eyeX)
            #expect(looking.eyeY == -limits.eyeY)
            mixer.apply(.lookEnded, at: 1)
            #expect(
                abs(mixer.offsets(at: 1 + PortraitMixer.lookReturn / 2).eyeX - limits.eyeX / 2)
                    < 1e-9)
            #expect(abs(mixer.offsets(at: 1 + PortraitMixer.lookReturn).eyeX) < 1e-9)
            mixer.apply(.tilt(90), at: 2)
            #expect(mixer.offsets(at: 2).roll == limits.roll)
            mixer.apply(.tilt(-90), at: 2)
            #expect(mixer.offsets(at: 2).roll == -limits.roll)
        }

        @Test(.enabled(if: MTLCreateSystemDefaultDevice() != nil))
        func metalMatchesTheLottieStill() throws {
            let renderer = try MetalPortraitRenderer.shared().get()
            try compareWithLottie { renderer.still($0, side: Self.paritySide) }
        }

        @Test func canvasMatchesTheLottieStill() throws {
            try compareWithLottie { PortraitPainter.still($0, side: CGFloat(Self.paritySide)) }
        }

        private func compareWithLottie(_ render: (PortraitFrame) -> CGImage?) throws {
            let store = PortraitStore()
            let poses = [nil] + PortraitExpression.allCases.map { Optional($0) }
            var worst = (mean: 0.0, tail: 0.0, case: "")
            for (slug, party) in Self.parityPeople {
                let scene = try scene(slug, party)
                let animation = try #require(store.animation(slug: slug, party: party))
                for pose in poses {
                    let frame = pose.flatMap { scene.markers[$0.poseMarker]?.start } ?? 0
                    let difference = try autoreleasepool {
                        let reference = try #require(
                            PortraitStill.render(
                                animation, side: CGFloat(Self.paritySide), frame: frame))
                        let drawn = try #require(render(scene.frame(scene.sample(at: frame))))
                        return try #require(PortraitDifference(reference, drawn))
                    }
                    if difference.mean > worst.mean || difference.tail > worst.tail {
                        worst = (
                            max(worst.mean, difference.mean), max(worst.tail, difference.tail),
                            "\(slug) \(pose?.rawValue ?? "rest")"
                        )
                    }
                    #expect(
                        difference.mean <= Self.parityMean,
                        "\(slug) \(pose?.rawValue ?? "rest") mean \(difference.mean)")
                    #expect(
                        difference.tail <= Self.parityTail,
                        "\(slug) \(pose?.rawValue ?? "rest") tail \(difference.tail)")
                }
            }
            print("Portrait parity worst mean \(worst.mean) tail \(worst.tail) at \(worst.case)")
        }
    }

    struct PortraitDifference {
        static let tailFraction = 0.995
        static let edgeStep = 0.08

        let mean: Double
        let tail: Double

        init?(_ reference: CGImage, _ drawn: CGImage) {
            guard reference.width == drawn.width, reference.height == drawn.height,
                let a = Self.pixels(reference), let b = Self.pixels(drawn)
            else { return nil }
            let count = reference.width * reference.height
            let ring = Self.edgeRing(a, reference.width, reference.height)
            var total = 0
            var histogram = [Int](repeating: 0, count: 256)
            var counted = 0
            a.withUnsafeBufferPointer { first in
                b.withUnsafeBufferPointer { second in
                    for index in 0..<count {
                        var largest = 0
                        for channel in 0..<4 {
                            let delta = abs(
                                Int(first[index * 4 + channel]) - Int(second[index * 4 + channel]))
                            total += delta
                            largest = max(largest, delta)
                        }
                        if !ring[index] {
                            histogram[largest] += 1
                            counted += 1
                        }
                    }
                }
            }
            mean = Double(total) / Double(count * 4) / 255
            let target = Int(Double(counted) * Self.tailFraction)
            var seen = 0
            var level = 0
            for (value, amount) in histogram.enumerated() {
                seen += amount
                level = value
                if seen > target { break }
            }
            tail = Double(level) / 255
        }

        private static func edgeRing(_ pixels: [UInt8], _ width: Int, _ height: Int) -> [Bool] {
            let step = Int(edgeStep * 255)
            var edge = [Bool](repeating: false, count: width * height)
            let forward = [(1, 0), (-1, 1), (0, 1), (1, 1)]
            pixels.withUnsafeBufferPointer { bytes in
                edge.withUnsafeMutableBufferPointer { marks in
                    for y in 0..<height {
                        for x in 0..<width {
                            let here = y * width + x
                            for (dx, dy) in forward {
                                let nx = x + dx
                                let ny = y + dy
                                guard nx >= 0, nx < width, ny < height else { continue }
                                let there = ny * width + nx
                                var differs = false
                                for channel in 0..<4 {
                                    let first = Int(bytes[here * 4 + channel])
                                    let second = Int(bytes[there * 4 + channel])
                                    if abs(first - second) > step {
                                        differs = true
                                        break
                                    }
                                }
                                if differs {
                                    marks[here] = true
                                    marks[there] = true
                                }
                            }
                        }
                    }
                }
            }
            var ring = edge
            for y in 0..<height {
                for x in 0..<width where edge[y * width + x] {
                    for ny in max(0, y - 1)...min(height - 1, y + 1) {
                        for nx in max(0, x - 1)...min(width - 1, x + 1) {
                            ring[ny * width + nx] = true
                        }
                    }
                }
            }
            return ring
        }

        private static func pixels(_ image: CGImage) -> [UInt8]? {
            let width = image.width
            let height = image.height
            var bytes = [UInt8](repeating: 0, count: width * height * 4)
            guard let space = CGColorSpace(name: CGColorSpace.sRGB),
                let context = CGContext(
                    data: &bytes, width: width, height: height, bitsPerComponent: 8,
                    bytesPerRow: width * 4, space: space,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return nil }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return bytes
        }
    }
#endif
