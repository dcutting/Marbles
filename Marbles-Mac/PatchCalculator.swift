import Foundation
import SceneKit

struct PatchOp {
    let op: () -> Void
    let name: String
}

class PatchCalculator {

    enum Priority {
        case low
        case high
    }

    private var config: PlanetConfig
    private let lowRingBuffer: RingBuffer<PatchOp>
//    private let highRingBuffer: RingBuffer<PatchOp>
    private let reader: DispatchQueue
    private let slow: DispatchQueue
    private let fast: DispatchQueue
    private let wip = PatchCache<Bool>()
    private let slowWip = PatchCache<Bool>()

    init(config: PlanetConfig) {
        self.config = config
        self.lowRingBuffer = RingBuffer(size: 20)
        self.reader = DispatchQueue(label: "reader", qos: .userInitiated, attributes: [])
        self.slow = DispatchQueue(label: "slow", qos: .default, attributes: .concurrent)
        self.fast = DispatchQueue(label: "fast", qos: .userInteractive, attributes: .concurrent)
        pollRingBuffer()
    }

    private func pollRingBuffer() {
        reader.asyncAfter(deadline: .now() + 0.1) {
//            print("checking")
//            while true {
//                guard let op = self.highRingBuffer.read() else { break }
//                self.highCalculator.async(execute: op.op)
//            }
            let wipCount = self.slowWip.count()
            let toDo = 20 - wipCount
            if toDo > 0 {
                for _ in 0..<toDo {
                    guard let op = self.lowRingBuffer.read() else { break }
//                    print("read read read read read")
                    self.slow.async(execute: op.op)
                }
            }
            print(self.slowWip.count())
//            print(self.highRingBuffer.count(), self.lowRingBuffer.count())
            self.pollRingBuffer()
        }
    }

    func calculate(_ name: String, vertices: [Patch.Vertex], subdivisions: UInt32, qos: Priority, completion: @escaping (Patch) -> Void) {
        let opName = "\(name)-\(subdivisions)"
        wip.write(opName, patch: true)
        let op = PatchOp(op: {
            self.slowWip.write(opName, patch: true)
            let patch = self.subdivideTriangle(vertices: vertices, subdivisionLevels: subdivisions)
            completion(patch)
//            print("done")
            let count = self.wip.remove(opName)
            self.slowWip.remove(opName)
//            print("low: \(count) in progress")
        }, name: opName)

        var lowBumped: PatchOp?
//        var highBumped: PatchOp?

        switch qos {
        case .low:
            lowBumped = lowRingBuffer.append(op)
        case .high:
            fast.async {
                let patch = self.subdivideTriangle(vertices: vertices, subdivisionLevels: subdivisions)
                completion(patch)
                //            print("done")
                let count = self.wip.remove(opName)
            }
        }

        if let bumped = lowBumped {
            let count = self.wip.remove(bumped.name)
            _ = self.slowWip.remove(bumped.name)
//            print("low: \(count) in progress: bumped")
//            print("bumped")
        }
//        if let bumped = highBumped {
//            let count = self.wip.remove(bumped.name)
////            print("high: \(count) in progress")
////            print("bumped")
//        }
    }

    func isCalculating(_ name: String, subdivisions: UInt32) -> Bool {
        return wip.read("\(name)-\(subdivisions)") ?? false
    }

    func subdivideTriangle(vertices: [Patch.Vertex], subdivisionLevels: UInt32) -> Patch {

        let a = spherical(vertices[0])
        let b = spherical(vertices[1])
        let c = spherical(vertices[2])

        let segments = pow(2, subdivisionLevels)

        let dab = b - a
        let lab = length(dab)
        let slab = lab / FP(segments)
        let vab = normalize(dab) * slab

        let dbc = c - b
        let lbc = length(dbc)
        let slbc = lbc / FP(segments)
        let vbc = normalize(dbc) * slbc

        var next: UInt32 = 0
        var indices = [Patch.Index]()
        var points = [FP3]()
        points.append(a)
        for j in 1...segments {
            let p = a + (vab * FP(j))
            let ps = spherical(p)
            points.append(ps)
            for i in 1...j {
                let q = p + (vbc * FP(i))
                let qs = spherical(q)
                points.append(qs)
                if i < j {
                    indices.append(contentsOf: [next, next+j, next+j+1])
                    indices.append(contentsOf: [next, next+j+1, next+1])
                    next += 1
                }
            }
            indices.append(contentsOf: [next, next+j, next+j+1])
            next += 1
        }

        let colours = findColours(for: points)

        return Patch(vertices: points, colours: colours, indices: indices)
    }

    private func spherical(_ a: Patch.Vertex) -> Patch.Vertex {
        let an = normalize(a)
        let ans = an * config.radius
        var delta = config.noise.evaluate(Double(ans.x), Double(ans.y), Double(ans.z))
        if config.levels > 0 {
            let ratio = Double(config.amplitude) / Double(config.levels)
            delta = ratio * round(delta / ratio)
        }
        if delta < 0.0 {
            delta = (delta / config.mountainHeight) * config.oceanDepth
        }
        return an * (config.radius + delta)
    }

    func sphericalise(vertices: [Patch.Vertex]) -> [Patch.Vertex] {
        let a = vertices[0]
        let b = vertices[1]
        let c = vertices[2]
        let `as` = spherical(a)
        let bs = spherical(b)
        let cs = spherical(c)
        return [`as`, bs, cs]
    }

    func sphericallySubdivide(vertices: [Patch.Vertex]) -> ([Patch.Vertex], [[Patch.Index]]) {

        let a = vertices[0]
        let b = vertices[1]
        let c = vertices[2]

        let ab = midway(a, b)
        let bc = midway(b, c)
        let ca = midway(c, a)

        let `as` = spherical(a)
        let bs = spherical(b)
        let cs = spherical(c)
        let abs = spherical(ab)
        let bcs = spherical(bc)
        let cas = spherical(ca)

        let subdividedTriangleEdges: [[Patch.Index]] = [[0, 3, 5],
                                                        [3, 1, 4],
                                                        [3, 4, 5],
                                                        [5, 4, 2]]

        return ([`as`, bs, cs, abs, bcs, cas], subdividedTriangleEdges)
    }

    private func findColours(for positions: [Patch.Vertex]) -> [Patch.Colour] {
        var colours = [Patch.Colour]()
        for p in positions {
            let pn = normalize(p) * config.radius
            let delta = length(p) - length(pn)
            let distanceFromEquator: FP = abs(p.y)/config.radius
            let dryness: FP = 1 - config.iciness
            let snowLine = FP(config.mountainHeight * 1.5) * (1 - distanceFromEquator * config.iciness) * dryness
            let rawHeightColour = FP(delta) / config.mountainHeight
            let rawDepthColour = 1 + (FP(delta) / config.oceanDepth)
            let heightColour = Float(scaledUnitClamp(rawHeightColour, min: 0.05))
            let depthColour = Float(scaledUnitClamp(rawDepthColour, min: 0.3, max: 0.7))
            if FP(delta) > snowLine {
                // Ice
                colours.append([1.0, 1.0, 1.0])
//            } else if FP(delta) >= 0.0 && FP(delta) < config.mountainHeight * 0.05 && distanceFromEquator < 0.3 {
//                // Beach
//                colours.append([0.7, 0.7, 0.0])
            } else if FP(delta) <= 1.0 {
                // Error
                colours.append([0.0, 0.0, depthColour])
            } else {
                // Forest
                colours.append([0.0, heightColour, 0.0])
            }
        }
        return colours
    }
}
