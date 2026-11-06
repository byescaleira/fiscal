#if DEBUG
    import CoreGraphics
    import Foundation

    enum PortraitStroke {
        static let stepsPerHalfTurn = 8
        private static let shortest = 1e-6

        static func triangles(_ points: ArraySlice<CGPoint>, closed: Bool, width: Double)
            -> [CGPoint]
        {
            var output: [CGPoint] = []
            append(points, closed: closed, width: width, to: &output)
            return output
        }

        static func append(
            _ points: ArraySlice<CGPoint>, closed: Bool, width: Double, to output: inout [CGPoint]
        ) {
            guard let first = points.first, width > 0 else { return }
            let radius = width / 2
            var segments = Array(zip(points, points.dropFirst()))
            if closed, points.count > 2, let last = points.last { segments.append((last, first)) }
            for (start, end) in segments {
                let dx = end.x - start.x
                let dy = end.y - start.y
                let length = hypot(dx, dy)
                guard length > shortest else { continue }
                let nx = -dy / length * radius
                let ny = dx / length * radius
                let a = CGPoint(x: start.x + nx, y: start.y + ny)
                let b = CGPoint(x: start.x - nx, y: start.y - ny)
                let c = CGPoint(x: end.x + nx, y: end.y + ny)
                let d = CGPoint(x: end.x - nx, y: end.y - ny)
                output += [a, b, c, c, b, d]
            }
            for point in points { disc(point, radius, &output) }
        }

        private static func disc(_ center: CGPoint, _ radius: Double, _ output: inout [CGPoint]) {
            let steps = stepsPerHalfTurn * 2
            var last = CGPoint(x: center.x + radius, y: center.y)
            for step in 1...steps {
                let angle = 2 * Double.pi * Double(step) / Double(steps)
                let next = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
                output += [center, last, next]
                last = next
            }
        }
    }
#endif
