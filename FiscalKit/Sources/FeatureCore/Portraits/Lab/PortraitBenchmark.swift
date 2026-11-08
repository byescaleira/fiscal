#if DEBUG
    import Darwin
    import FiscalDomain
    import Foundation
    import Observation
    import QuartzCore

    enum PortraitEngine: String, CaseIterable, Identifiable, Sendable {
        case lottie = "Lottie"
        case canvas = "Canvas"
        case metal = "Metal"

        var id: Self { self }
    }

    struct PortraitMeasure: Identifiable, Sendable, Equatable {
        let engine: PortraitEngine
        let cpuPercent: Double
        let memoryMegabytes: Double
        let droppedPercent: Double
        let gpuAverage: Double?
        let gpuP95: Double?
        let thermal: ProcessInfo.ThermalState

        var id: PortraitEngine { engine }

        static func median(_ rounds: [PortraitMeasure]) -> PortraitMeasure? {
            guard let first = rounds.first else { return nil }
            func middle(_ values: [Double]) -> Double {
                let sorted = values.sorted()
                return sorted[sorted.count / 2]
            }
            let gpu = rounds.compactMap(\.gpuAverage)
            let gpuTail = rounds.compactMap(\.gpuP95)
            return PortraitMeasure(
                engine: first.engine, cpuPercent: middle(rounds.map(\.cpuPercent)),
                memoryMegabytes: middle(rounds.map(\.memoryMegabytes)),
                droppedPercent: middle(rounds.map(\.droppedPercent)),
                gpuAverage: gpu.isEmpty ? nil : middle(gpu),
                gpuP95: gpuTail.isEmpty ? nil : middle(gpuTail),
                thermal: rounds.map(\.thermal).max { $0.rawValue < $1.rawValue } ?? first.thermal)
        }

        static func percentile(_ values: [Double], _ fraction: Double) -> Double? {
            guard !values.isEmpty else { return nil }
            let sorted = values.sorted()
            let index = min(sorted.count - 1, Int((Double(sorted.count) * fraction).rounded(.down)))
            return sorted[index]
        }
    }

    @MainActor
    @Observable
    final class PortraitBenchmark {
        static let rounds = 3
        static let roundLength = Duration.seconds(20)
        static let actionEvery = Duration.seconds(3)
        static let pause = Duration.seconds(5)
        static let portraits = 3
        static let tail = 0.95
        private static let percent = 100.0
        private static let megabyte = 1_048_576.0
        private static let permille = 1_000.0
        private static let microseconds = 1_000.0

        private(set) var stage: PortraitEngine?
        private(set) var round = 0
        private(set) var pulse = 0
        private(set) var results: [PortraitMeasure] = []
        private(set) var isRunning = false

        func run(renderer: MetalPortraitRenderer?) async {
            guard !isRunning else { return }
            isRunning = true
            results = []
            defer {
                isRunning = false
                stage = nil
            }
            for engine in PortraitEngine.allCases {
                if engine == .metal && renderer == nil { continue }
                var measures: [PortraitMeasure] = []
                for index in 1...Self.rounds {
                    round = index
                    stage = nil
                    try? await Task.sleep(for: Self.pause)
                    guard !Task.isCancelled else { return }
                    let baseline = Self.footprint()
                    stage = engine
                    renderer?.resetMeasurements()
                    let counter = PortraitFrameCounter()
                    counter.start()
                    let cpuStart = Self.cpuSeconds()
                    let wallStart = CACurrentMediaTime()
                    var elapsed = Duration.zero
                    while elapsed < Self.roundLength {
                        try? await Task.sleep(for: Self.actionEvery)
                        guard !Task.isCancelled else {
                            counter.stop()
                            return
                        }
                        pulse += 1
                        elapsed += Self.actionEvery
                    }
                    let wall = CACurrentMediaTime() - wallStart
                    let cpu = Self.cpuSeconds() - cpuStart
                    counter.stop()
                    let gpu = engine == .metal ? renderer?.gpuMilliseconds ?? [] : []
                    let measure = PortraitMeasure(
                        engine: engine, cpuPercent: cpu / wall * Self.percent,
                        memoryMegabytes: max(0, Self.footprint() - baseline),
                        droppedPercent: counter.droppedPercent,
                        gpuAverage: gpu.isEmpty
                            ? nil : gpu.reduce(0, +) / Double(gpu.count) * Double(Self.portraits),
                        gpuP95: PortraitMeasure.percentile(gpu, Self.tail).map {
                            $0 * Double(Self.portraits)
                        },
                        thermal: ProcessInfo.processInfo.thermalState)
                    measures.append(measure)
                }
                if let median = PortraitMeasure.median(measures) {
                    results.append(median)
                    log(median)
                }
            }
        }

        private func log(_ measure: PortraitMeasure) {
            EventLog.shared.notice(
                "Portrait lab \(measure.engine) cpu permille \(count: Int(measure.cpuPercent * Self.permille / Self.percent)) memory KB \(count: Int(measure.memoryMegabytes * Self.permille)) dropped permille \(count: Int(measure.droppedPercent * Self.permille / Self.percent)) gpu microseconds \(count: Int((measure.gpuAverage ?? 0) * Self.microseconds))"
            )
        }

        static func cpuSeconds() -> Double {
            var usage = rusage()
            guard getrusage(RUSAGE_SELF, &usage) == 0 else { return 0 }
            func seconds(_ time: timeval) -> Double {
                Double(time.tv_sec) + Double(time.tv_usec) / 1_000_000
            }
            return seconds(usage.ru_utime) + seconds(usage.ru_stime)
        }

        static func footprint() -> Double {
            var info = task_vm_info_data_t()
            var count = mach_msg_type_number_t(
                MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
            let result = withUnsafeMutablePointer(to: &info) { pointer in
                pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                    task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
                }
            }
            guard result == KERN_SUCCESS else { return 0 }
            return Double(info.phys_footprint) / megabyte
        }
    }

    @MainActor
    final class PortraitFrameCounter: NSObject {
        private static let late = 1.5
        private var ticks = 0
        private var dropped = 0
        private var last: CFTimeInterval?

        #if !os(macOS)
            private var link: CADisplayLink?
        #endif

        var droppedPercent: Double {
            ticks > 0 ? Double(dropped) / Double(ticks) * 100 : 0
        }

        func start() {
            #if !os(macOS)
                let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
                link.add(to: .main, forMode: .common)
                self.link = link
            #endif
        }

        func stop() {
            #if !os(macOS)
                link?.invalidate()
                link = nil
            #endif
        }

        #if !os(macOS)
            @objc private func tick(_ link: CADisplayLink) {
                defer { last = link.timestamp }
                guard let last else { return }
                ticks += 1
                if link.timestamp - last > link.duration * Self.late { dropped += 1 }
            }
        #endif
    }
#endif
