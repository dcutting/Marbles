import SceneKit

class PatchCalculator {

    private var config: PlanetConfig

    init(config: PlanetConfig) {
        self.config = config
    }

    func subdivide(triangle: Triangle, subdivisionLevels: UInt32) -> Patch {

        let (a, _) = spherical(triangle.a)
        let (b, _) = spherical(triangle.b)
        let (c, _) = spherical(triangle.c)

        let segments = UInt32(pow(2.0, FP(subdivisionLevels)))

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
        var points = [Patch.Vertex]()
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
            let rawHeightColour: Float
            if config.hasWater {
                rawHeightColour = Float(delta) / Float(config.mountainHeight)
            } else {
                rawHeightColour = (Float(delta) + Float(config.mountainHeight)) / Float(config.mountainHeight * 2.0)
            }
            let oceanDepth = config.oceanDepth == 0.0 ? 0.01 : config.oceanDepth
            let rawDepthColour = 1 + (Float(delta) / Float(oceanDepth))
            let snowNoiseValue = config.snowNoise.evaluate(p.x, p.y, p.z)
            if FP(delta + snowNoiseValue) > snowLine {
                // Ice
                colours.append([1.0, 1.0, 1.0])
            } else if config.hasWater && FP(delta) <= 0.0 {
                // Water
                let colour = config.waterColourScale.interpolated(by: rawDepthColour)
                colours.append(colour)
            } else {
                // Ground
                let colour = config.groundColourScale.interpolated(by: rawHeightColour)
                colours.append(colour)
            }
        }
        return colours
    }
}
