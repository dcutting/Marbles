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
    private let concurrentPatches = 20

    init(config: PlanetConfig) {
        self.config = config
        self.reader = DispatchQueue(label: "reader", qos: .userInteractive, attributes: [])
        self.fast = DispatchQueue(label: "fast", qos: .userInitiated, attributes: .concurrent)
        pollRingBuffer()
    }

    private func pollRingBuffer() {
        reader.asyncAfter(deadline: .now() + 0.1) {
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
            print("\(queuedCount), \(wipCount): \(ops.map { op in op.op.name })")
            self.pollRingBuffer()
        }
    }

    func calculate(_ name: String, vertices: [Patch.Vertex], subdivisions: UInt32, priority: Double, completion: @escaping (Patch) -> Void) {

        guard !isCalculating(name, subdivisions: subdivisions) else { return }

        let opName = "\(name)-\(subdivisions)"
        queued.write(opName, patch: true)

        let op = PatchOp(op: {
            self.wip.write(opName, patch: true)
            let patch = self.subdivideTriangle(vertices: vertices, subdivisionLevels: subdivisions)
            completion(patch)
            _ = self.wip.remove(opName)
            _ = self.queued.remove(opName)
        }, name: opName)

        let prioritisedOp = PrioritisedOp(priority: priority, op: op)

        reader.async {
            self.priorityBuffer.append(prioritisedOp)
        }
    }

    func clearBuffer() {
        reader.async {
            self.priorityBuffer.forEach { op in
                _ = self.queued.remove(op.op.name)
            }
            self.priorityBuffer.removeAll()
            print("-----")
        }
    }

    func isCalculating(_ name: String, subdivisions: UInt32) -> Bool {
        return queued.read("\(name)-\(subdivisions)") ?? false
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
        if config.hasWater && delta < 0.0 {
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
            let rawHeightColour: FP
            if config.hasWater {
                rawHeightColour = FP(delta) / config.mountainHeight
            } else {
                rawHeightColour = FP(delta + config.mountainHeight) / (config.mountainHeight * 2.0)
            }
            let rawDepthColour = 1 + (FP(delta) / config.oceanDepth)
            let depthColour = Float(scaledUnitClamp(rawDepthColour, min: 0.3, max: 0.7))
            if FP(delta) > snowLine {
                // Ice
                colours.append([1.0, 1.0, 1.0])
            } else if config.hasWater && FP(delta) <= 0.0 {
                // Water
                colours.append([0.0, 0.0, depthColour])
            } else {
                // Ground
                let r = scaledUnitClamp(rawHeightColour, min: config.groundColourScale.red.min, max: config.groundColourScale.red.max)
                let g = scaledUnitClamp(rawHeightColour, min: config.groundColourScale.green.min, max: config.groundColourScale.green.max)
                let b = scaledUnitClamp(rawHeightColour, min: config.groundColourScale.blue.min, max: config.groundColourScale.blue.max)
                colours.append([Float(r), Float(g), Float(b)])
            }
        }
        return colours
    }
}
