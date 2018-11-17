import Foundation
import SceneKit

struct PatchOp {
    let op: () -> Void
    let name: String
}

struct PrioritisedOp {
    let priority: Double
    let op: PatchOp
}

class PatchCalculator {

    private var config: PlanetConfig
    private var priorityBuffer = [PrioritisedOp]()
    private let reader: DispatchQueue
    private let fast: DispatchQueue
    private let queued = PatchCache<Bool>()
    private let wip = PatchCache<Bool>()
    private let concurrentPatches = 12

    init(config: PlanetConfig) {
        self.config = config
        self.reader = DispatchQueue(label: "reader", qos: .userInitiated, attributes: [])
        self.fast = DispatchQueue(label: "fast", qos: .default, attributes: .concurrent)
        pollRingBuffer()
    }

    private func pollRingBuffer() {
        reader.asyncAfter(deadline: .now() + 0.08) {
            let queuedCount = self.queued.count()
            let wipCount = self.wip.count()
            let toDo = max(0, self.concurrentPatches - wipCount)
            self.priorityBuffer.sort { a, b in
                a.priority < b.priority
            }
            let bufferCount = self.priorityBuffer.count
            let willDo = min(toDo, bufferCount)
            let ops = self.priorityBuffer.prefix(willDo)
            self.priorityBuffer.removeFirst(willDo)
            ops.forEach { op in
                self.fast.async(execute: op.op.op)
            }
            if debug {
                print("\(queuedCount), \(wipCount): \(ops.map { op in op.op.name })")
            }
            self.pollRingBuffer()
        }
    }

    func calculate(_ name: String, triangle: Triangle, subdivisions: UInt32, priority: Double, completion: @escaping (Patch) -> Void) {

        guard !isCalculating(name, subdivisions: subdivisions) else { return }

        let opName = "\(name)-\(subdivisions)"
        queued.write(opName, patch: true)

        let op = PatchOp(op: {
            self.reader.sync {
                _ = self.queued.remove(opName)
                self.wip.write(opName, patch: true)
            }
            let patch = self.subdivide(triangle: triangle, subdivisionLevels: subdivisions)
            completion(patch)
            self.reader.sync {
                _ = self.wip.remove(opName)
            }
        }, name: opName)

        let prioritisedOp = PrioritisedOp(priority: priority, op: op)

        reader.async {
            self.priorityBuffer.append(prioritisedOp)
        }
    }

    func clearBuffer() {
        reader.async {
            self.queued.removeAll()
            self.priorityBuffer.removeAll()
        }
    }

    func isCalculating(_ name: String, subdivisions: UInt32) -> Bool {
        return reader.sync {
            let opName = "\(name)-\(subdivisions)"
            let isInProgress = wip.read(opName) ?? false
            let isQueued = queued.read(opName) ?? false
            return isInProgress || isQueued
        }
    }

    func subdivide(triangle: Triangle, subdivisionLevels: UInt32) -> Patch {

        let (a, _) = spherical(triangle.a)
        let (b, _) = spherical(triangle.b)
        let (c, _) = spherical(triangle.c)

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
            let (ps, _) = spherical(p)
            points.append(ps)
            for i in 1...j {
                let q = p + (vbc * FP(i))
                let (qs, _) = spherical(q)
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

    public func sphericalBase(_ a: Patch.Vertex, plus: FP = 0.0) -> Patch.Vertex {
        return normalize(a) * (config.radius + plus)
    }

    private func spherical(_ a: Patch.Vertex) -> (Patch.Vertex, FP) {
        let an = normalize(a)
        let ans = an * config.radius
        var delta = config.noise.evaluate(Double(ans.x), Double(ans.y), Double(ans.z))
        if config.levels > 0 {
            let ratio = Double(config.amplitude) / Double(config.levels)
            delta = ratio * round(delta / ratio)
        }
        if config.hasWater && delta < 0.0 {
            delta = (delta / config.mountainHeight) * config.oceanDepth
        }
        return (an * (config.radius + delta), delta)
    }

    func sphericalise(vertices: [Patch.Vertex]) -> [Patch.Vertex] {
        let a = vertices[0]
        let b = vertices[1]
        let c = vertices[2]
        let (`as`, _) = spherical(a)
        let (bs, _) = spherical(b)
        let (cs, _) = spherical(c)
        return [`as`, bs, cs]
    }

    func sphericallySubdivide(triangle: Triangle) -> ([Patch.Vertex], [[Patch.Index]], [FP]) {

        let a = triangle.a
        let b = triangle.b
        let c = triangle.c

        let ab = a.midway(to: b)
        let bc = b.midway(to: c)
        let ca = c.midway(to: a)

        let (`as`, asd) = spherical(a)
        let (bs, bsd) = spherical(b)
        let (cs, csd) = spherical(c)
        let (abs, absd) = spherical(ab)
        let (bcs, bcsd) = spherical(bc)
        let (cas, casd) = spherical(ca)

        let subdividedTriangleEdges: [[Patch.Index]] = [[0, 3, 5],
                                                        [3, 1, 4],
                                                        [3, 4, 5],
                                                        [5, 4, 2]]

        return ([`as`, bs, cs, abs, bcs, cas], subdividedTriangleEdges, [asd, bsd, csd, absd, bcsd, casd])
    }

    private func findColours(for positions: [Patch.Vertex]) -> [Patch.Colour] {
        var colours = [Patch.Colour]()
        for p in positions {
            let pn = normalize(p) * config.radius
            let delta = length(p) - length(pn)
            let distanceFromEquator: FP = abs(p.y)/config.radius
            let dryness: FP = 1 - config.iciness
            let snowLine = FP(config.mountainHeight * 1.5) * (1 - distanceFromEquator * config.iciness) * dryness
            let rawHeightColour: FP
            if config.hasWater {
                rawHeightColour = FP(delta) / config.mountainHeight
            } else {
                rawHeightColour = FP(delta + config.mountainHeight) / (config.mountainHeight * 2.0)
            }
            let oceanDepth = config.oceanDepth == 0.0 ? 0.01 : config.oceanDepth
            let rawDepthColour = 1 + (FP(delta) / oceanDepth)
            let snowNoiseValue = config.snowNoise.evaluate(p.x, p.y, p.z)
            if FP(delta + snowNoiseValue) > snowLine {
                // Ice
                colours.append([1.0, 1.0, 1.0])
            } else if config.hasWater && FP(delta) <= 0.0 {
                // Water
                let r = interpolated(rawDepthColour, v0: config.waterColourScale.red.a, v1: config.waterColourScale.red.b)
                let g = interpolated(rawDepthColour, v0: config.waterColourScale.green.a, v1: config.waterColourScale.green.b)
                let b = interpolated(rawDepthColour, v0: config.waterColourScale.blue.a, v1: config.waterColourScale.blue.b)
                colours.append([Float(r), Float(g), Float(b)])
            } else {
                // Ground
                let r = interpolated(rawHeightColour, v0: config.groundColourScale.red.a, v1: config.groundColourScale.red.b)
                let g = interpolated(rawHeightColour, v0: config.groundColourScale.green.a, v1: config.groundColourScale.green.b)
                let b = interpolated(rawHeightColour, v0: config.groundColourScale.blue.a, v1: config.groundColourScale.blue.b)
                colours.append([Float(r), Float(g), Float(b)])
            }
        }
        return colours
    }
}
