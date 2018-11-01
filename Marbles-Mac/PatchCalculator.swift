import Foundation
import SceneKit

class PatchCalculator {

    struct Config {

        enum Priority {
            case low
            case high
        }

        let priority: Priority

        let name: String

        var radius: FP = 10000
        var diameter: FP {
            return radius * 2
        }
        var amplitude: FP = 0.0 // TODO: tie this to levels somehow
        var mountainHeight: FP {
            return amplitude / 2.0
        }
        var levels: UInt32 = 0
        var iciness: FP = 0.4
        var noise: Noise

        init(name: String, priority: Priority, noise: Noise) {
            self.name = name
            self.priority = priority
            self.noise = noise
        }
    }

    private let config: Config
    private let calculator: DispatchQueue
    private let wip = PatchCache<Bool>()

    init(config: Config) {
        self.config = config
        let qos: DispatchQoS
        if case .low = config.priority {
            qos = .default
        } else {
            qos = .userInitiated
        }
        self.calculator = DispatchQueue(label: "calculator", qos: qos, attributes: .concurrent)
    }

    func calculate(_ name: String, vertices: [Patch.Vertex], subdivisions: UInt32, completion: @escaping (Patch) -> Void) {
        wip.write("\(name)-\(subdivisions)", patch: true)
        calculator.async {
            let patch = self.subdivideTriangle(vertices: vertices, subdivisionLevels: subdivisions)
            completion(patch)
            let count = self.wip.remove("\(name)-\(subdivisions)")
            print("\(self.config.name): \(count) in progress")
        }
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
            let heightColour = Float(scaledUnitClamp(rawHeightColour, min: 0.05))
            let depthColour = Float(scaledUnitClamp(rawHeightColour, min: 0.05, max: 0.2))
            if FP(delta) > snowLine {
                // Ice
                colours.append([1.0, 1.0, 1.0])
            } else if FP(delta) >= 0.0 && FP(delta) < config.mountainHeight * 0.05 && distanceFromEquator < 0.3 {
                // Beach
                colours.append([0.7, 0.7, 0.0])
            } else if FP(delta) < 0.0 {
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
